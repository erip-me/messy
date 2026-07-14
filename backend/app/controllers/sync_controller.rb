class SyncController < ApplicationController
  include ApiAuthentication
  wrap_parameters false

  # POST /sync
  def create
    layouts_data = params[:layouts] || []
    templates_data = params[:templates] || []
    purge = params[:purge] == true || params[:purge] == "true"

    results = { layouts: { created: 0, updated: 0 }, folders: { created: 0, updated: 0 }, templates: { created: 0, updated: 0 }, errors: [] }
    layout_name_to_id = {}
    folder_path_to_id = {}

    ActiveRecord::Base.transaction do
      # Phase 1: Upsert layouts
      layouts_data.each do |layout_data|
        layout = Layout.find_or_initialize_by(environment: @environment, name: layout_data["name"])
        is_new = layout.new_record?
        layout.account = @account
        layout.body = layout_data["body"] if layout_data["body"].present?
        layout.transformers = layout_data["transformers"] || {} if layout_data.key?("transformers")

        if layout.save
          is_new ? results[:layouts][:created] += 1 : results[:layouts][:updated] += 1
          layout_name_to_id[layout.name] = layout.id
        else
          results[:errors] << { type: "layout", name: layout_data["name"], errors: layout.errors.full_messages }
        end
      end

      # Also map existing layouts so templates can reference them
      @environment.layouts.each { |l| layout_name_to_id[l.name] ||= l.id }

      # Phase 2: Upsert folders from template folder paths
      templates_data.each do |template_data|
        next if template_data["folder"].blank?

        segments = template_data["folder"].split("/")
        parent_id = nil
        current_path = ""

        segments.each do |segment|
          current_path = current_path.empty? ? segment : "#{current_path}/#{segment}"
          # Already created this ancestor in an earlier template this sync — carry
          # its id forward as the parent so deeper segments nest correctly. (Skipping
          # without this left parent_id nil, flattening 2nd+ siblings to the root.)
          if (cached_id = folder_path_to_id[current_path])
            parent_id = cached_id
            next
          end

          folder = Folder.find_or_initialize_by(
            environment: @environment,
            account: @account,
            name: segment,
            parent_folder_id: parent_id
          )
          is_new = folder.new_record?

          if folder.save
            is_new ? results[:folders][:created] += 1 : results[:folders][:updated] += 1
            folder_path_to_id[current_path] = folder.id
          else
            results[:errors] << { type: "folder", path: current_path, errors: folder.errors.full_messages }
          end

          parent_id = folder.id
        end
      end

      # Phase 3: Upsert templates
      synced_triggers = []

      templates_data.each do |template_data|
        # Validate layout reference
        if template_data["layout"].present? && !layout_name_to_id.key?(template_data["layout"])
          results[:errors] << { type: "template", trigger: template_data["trigger"], channel: template_data["channel"], errors: ["Layout '#{template_data["layout"]}' not found"] }
          next
        end

        template = Template.find_or_initialize_by(
          environment: @environment,
          trigger: template_data["trigger"],
          channel: template_data["channel"] || "email"
        )
        is_new = template.new_record?
        template.account = @account
        template.name = template_data["name"] if template_data["name"].present?
        template.subject = template_data["subject"]
        template.body = template_data["body"] if template_data["body"].present?
        template.body_format = template_data["body_format"] || "markdown"
        template.preview = template_data["preview"]
        template.layout_id = layout_name_to_id[template_data["layout"]] if template_data["layout"].present?
        template.folder_id = folder_path_to_id[template_data["folder"]] if template_data["folder"].present?

        if template.save
          is_new ? results[:templates][:created] += 1 : results[:templates][:updated] += 1
          synced_triggers << [template.trigger, template.channel]
        else
          results[:errors] << { type: "template", trigger: template_data["trigger"], channel: template_data["channel"], errors: template.errors.full_messages }
        end
      end

      # Phase 4: Purge orphaned templates
      if purge && synced_triggers.any?
        orphaned = @environment.templates.where.not(
          ["(trigger, channel) IN (#{synced_triggers.map { '(?, ?)' }.join(', ')})", *synced_triggers.flatten]
        )
        results[:purged] = orphaned.count
        Message.where(template_id: orphaned.select(:id)).update_all(template_id: nil)
        orphaned.destroy_all
      end

      # Phase 5: Purge orphaned layouts
      if purge
        synced_layout_names = layouts_data.map { |l| l["name"] }.compact
        if synced_layout_names.any?
          orphaned_layouts = @environment.layouts.where.not(name: synced_layout_names)
          results[:purged_layouts] = orphaned_layouts.count
          orphaned_layouts.each do |layout|
            layout.templates.update_all(layout_id: nil)
            layout.destroy
          end
        end
      end

      # Phase 6: Purge empty folders (leaf-first recursive)
      if purge
        purged_folders = 0
        loop do
          synced_folder_ids = folder_path_to_id.values
          empty_folders = Folder.where(account: @account, environment: @environment)
            .where.not(id: synced_folder_ids)
            .where.not(
              id: Template.where.not(folder_id: nil).select(:folder_id)
            )
            .where.not(
              id: Folder.where.not(parent_folder_id: nil).select(:parent_folder_id)
            )
          break if empty_folders.empty?
          purged_folders += empty_folders.count
          empty_folders.destroy_all
        end
        results[:purged_folders] = purged_folders
      end

      # Rollback if any errors
      if results[:errors].any?
        raise ActiveRecord::Rollback
      end
    end

    if results[:errors].any?
      render json: results, status: :unprocessable_entity
    else
      render json: results, status: :ok
    end
  rescue ActionDispatch::Http::Parameters::ParseError => e
    render json: { error: "Invalid JSON: #{e.message}" }, status: :bad_request
  end
end
