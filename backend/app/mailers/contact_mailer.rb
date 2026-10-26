class ContactMailer < ApplicationMailer
  # Notification to the sales inbox for a website contact or enterprise enquiry.
  # Reply-to is the sender, so replying from the inbox answers them directly.
  def enquiry
    @contact = params[:contact]
    kind =
      if @contact[:waitlist] then "Managed waitlist"
      elsif @contact[:enterprise] then "Enterprise enquiry"
      else "Contact"
      end
    who = @contact[:company].presence || @contact[:name].presence || @contact[:email]

    mail(
      to: 'hello@messy.sh',
      reply_to: @contact[:email],
      subject: "#{kind}: #{who}"
    )
  end

  # Internal heads-up when someone signs up for a new account.
  def new_signup
    @user = params[:user]

    mail(
      to: 'info@messy.sh',
      reply_to: @user.email,
      subject: "New signup: #{@user.account.name}"
    )
  end
end
