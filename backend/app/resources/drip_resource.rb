# Drip campaign with its ordered steps and enrollment stats. On index, pass
# params[:exec_counts] / params[:enrollment_counts] (the batched grouped-count
# hashes) so the list doesn't run per-drip aggregate queries.
class DripResource
  include Alba::Resource

  attributes :id, :name, :status, :segment_id, :environment_id, :allow_reentry,
             :exit_on_segment_leave, :enroll_existing_on_start, :sending_identity_id,
             :created_at, :updated_at

  attribute :segment do |drip|
    drip.segment && { id: drip.segment.id, name: drip.segment.name }
  end

  attribute :steps do |drip|
    steps = drip.ordered_steps
    exec_counts = params[:exec_counts] ||
                  DripStepExecution.where(drip_step_id: steps.map(&:id)).group(:drip_step_id, :status).count
    steps.map { |s| step_hash(s, exec_counts) }
  end

  attribute :stats do |drip|
    counts =
      if params[:enrollment_counts]
        # Slice this drip's rows out of the batched {[drip_id, status] => n} hash.
        params[:enrollment_counts].each_with_object(Hash.new(0)) do |((drip_id, status), n), h|
          h[status] += n if drip_id == drip.id
        end
      else
        drip.drip_enrollments.group(:status).count
      end
    {
      active: counts["active"] || 0,
      completed: counts["completed"] || 0,
      exited: counts["exited"] || 0,
      total: counts.values.sum
    }
  end

  def step_hash(step, exec_counts)
    {
      id: step.id,
      position: step.position,
      template_id: step.template_id,
      channel: step.channel,
      delay_days: step.delay_days,
      conditions: step.conditions,
      on_fail: step.on_fail,
      template: step.template && { id: step.template.id, name: step.template.name, channel: step.template.channel },
      sent_count: exec_counts[[step.id, "sent"]] || 0,
      skipped_count: exec_counts[[step.id, "skipped"]] || 0,
      suppressed_count: exec_counts[[step.id, "suppressed"]] || 0
    }
  end
end
