module Mcp
  # Dashboard-facing management of the MCP server: the account master switch, the
  # list of connections (grants) with per-user and per-connection controls, and
  # the usage log. Admin-only, JWT-authenticated (same as other account settings).
  class ManagementController < ApplicationController
    before_action :authenticate_user!
    before_action :require_account_admin!

    LOGS_PER_PAGE = 25

    # GET /mcp/settings
    def show
      render json: { enabled: account.mcp_enabled?, server_url: "#{request.base_url}/mcp" }
    end

    # PATCH /mcp/settings
    def update
      setting = account.mcp_setting || account.build_mcp_setting
      setting.update!(enabled: boolean(params[:enabled]))
      render json: { enabled: setting.enabled, server_url: "#{request.base_url}/mcp" }
    end

    # GET /mcp/connections
    def connections
      grants = account.mcp_grants.includes(:user, :environment, :mcp_client).order(created_at: :desc)
      render json: {
        connections: Mcp::ConnectionResource.new(grants).to_h,
        users: account.users.order(:name).map do |u|
          { id: u.id, name: u.name, email: u.email, mcp_enabled: u.mcp_enabled }
        end
      }
    end

    # DELETE /mcp/connections/:id
    def revoke_connection
      grant = account.mcp_grants.find(params[:id])
      grant.revoke!
      render json: { ok: true }
    end

    # PATCH /mcp/users/:user_id
    def set_user_enabled
      user = account.users.find(params[:user_id])
      user.update!(mcp_enabled: boolean(params[:enabled]))
      render json: { id: user.id, mcp_enabled: user.mcp_enabled }
    end

    # GET /mcp/logs
    def logs
      page = [params[:page].to_i, 1].max
      scope = account.mcp_request_logs.includes(:user).order(created_at: :desc)
      total = scope.count
      rows = scope.offset((page - 1) * LOGS_PER_PAGE).limit(LOGS_PER_PAGE)
      render json: {
        logs: Mcp::LogResource.new(rows).to_h,
        meta: { page: page, total: total, total_pages: (total.to_f / LOGS_PER_PAGE).ceil }
      }
    end

    private

    def account
      current_user.account
    end

    def boolean(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

  end
end
