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

  # Someone submitted /signup with an address that already has a login. That
  # endpoint answers identically either way, so this is how the real owner — the
  # only person entitled to know — finds out.
  #
  # Deliberately does NOT mint a magic-link token: a stranger triggers this
  # email, and generating a live login link on their say-so would let them
  # rotate the owner's token at will. The sign-in page issues its own.
  def existing_account_notice
    @user = params[:user]
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5174')
    @login_link = "#{frontend_url}/login"

    mail(to: @user.email, subject: 'You already have a Messy account')
  end

  def invitation_email
    @user = params[:user]
    @inviter = params[:inviter]
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5174')
    @accept_link = "#{frontend_url}/validate/#{@user.magic_link_token}"

    mail(to: @user.email, subject: "You've been invited to the #{@user.account.name} workspace on Messy")
  end

  # Someone who already has a Messy login has been invited to another workspace.
  # They are NOT a member yet — the membership stays pending until they accept,
  # so this email is the ask, not a notification.
  #
  # Deliberately does NOT mint a magic-link token: they may well be signed in
  # right now, and rotating it would invalidate that session. The link deep-links
  # to the invitation, which the app also surfaces on its own after normal auth —
  # so a lost or expired email never strands the invitation.
  def workspace_invitation_email
    @user = params[:user]
    @inviter = params[:inviter]
    @account = params[:account]
    # Just the app: pending invitations are surfaced there on their own, so
    # there's no token or deep link to go stale.
    @workspace_link = ENV.fetch('FRONTEND_URL', 'http://localhost:5174')

    mail(to: @user.email, subject: "#{@inviter.name} invited you to #{@account.name} on Messy")
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
