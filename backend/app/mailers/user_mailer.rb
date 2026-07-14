class UserMailer < ApplicationMailer
  def magic_link
    @user = params[:user]
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5174')
    @magic_link = "#{frontend_url}/validate/#{@user.magic_link_token}"

    mail(to: @user.email, subject: 'Your login link for Messy')
  end

  def verification_email
    @user = params[:user]
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5174')
    @verify_link = "#{frontend_url}/validate/#{@user.magic_link_token}"

    mail(to: @user.email, subject: 'Verify your Messy account')
  end

  def invitation_email
    @user = params[:user]
    @inviter = params[:inviter]
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5174')
    @accept_link = "#{frontend_url}/validate/#{@user.magic_link_token}"

    mail(to: @user.email, subject: "You've been invited to #{@user.account.name} on Messy")
  end

  def conversation_assigned
    @user = params[:user]
    @conversation = params[:conversation]
    @assigned_by = params[:assigned_by]
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5174')
    @inbox_link = "#{frontend_url}/inbox/#{@conversation.id}"

    mail(to: @user.email, subject: "New chat assigned to you: #{@conversation.visitor_name || @conversation.visitor_email || 'Visitor'}")
  end

  def list_cleanup_complete
    @user = params[:user]
    @segment = params[:segment]
    @stats = params[:stats]
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5174')
    @segment_link = "#{frontend_url}/segments/#{@segment.id}/edit"

    mail(to: @user.email, subject: "List cleanup complete: #{@segment.name}")
  end
end
