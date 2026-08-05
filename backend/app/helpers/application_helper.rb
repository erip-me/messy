module ApplicationHelper
  protected
    # Get the real IP address, taking into account any proxies.
    def client_ip
      if request.headers['X-Forwarded-For'].present?
        # X-Forwarded-For contains a comma-separated list of IPs, take the first one which is the client IP
        request.headers['X-Forwarded-For'].split(',').first.strip
      else
        # Fallback to remote_ip if no X-Forwarded-For header is present
        request.remote_ip
      end
    end

    def load_message
      @message = (@environment&.messages || @account.messages).find(params[:id])
    end

    def load_template
      @template = (@environment&.templates || @account.templates).find(params[:id])
    end

    def load_template_by_trigger
      scope = @environment.templates.where(trigger: params[:trigger])
      scope = scope.where(channel: params[:channel]) if params[:channel].present?
      # One trigger can have a template per channel. Order is load-bearing here
      # because only the first row is used:
      #   - email first, so adding an SMS template for an existing trigger cannot
      #     silently reroute callers who never passed a channel (no-op once
      #     params[:channel] has already narrowed the scope);
      #   - then newest, the documented "latest template wins" behaviour;
      #   - then id, because fixtures and bulk imports create rows within the same
      #     clock tick and a created_at tie left the choice to Postgres.
      scope = scope.order(Arel.sql("channel = 'email' DESC"), created_at: :desc, id: :desc)

      unless @template = scope.first
        return render json: { error: "Template not found" }, status: :unprocessable_entity
      end
    end
end
