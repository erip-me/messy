class EmailFinderController < ApplicationController
  include ActionController::Live

  before_action :authenticate_user!

  def generate
    if params[:first_name].blank? || params[:last_name].blank? || params[:domain].blank?
      return render json: { error: 'First name, last name, and domain are required' }, status: :unprocessable_entity
    end

    finder = EmailFinder.new(
      first_name:  params[:first_name],
      last_name:   params[:last_name],
      domain:      params[:domain],
      middle_name: params[:middle_name]
    )

    render json: { emails: finder.generate_emails }
  end

  def verify
    email = params[:email]
    return render json: { error: 'Email required' }, status: :unprocessable_entity if email.blank?

    result = EmailVerifier.new(email).verify
    render json: {
      email: email,
      valid: result.checks[:smtp] == :accepted,
      reason: result.checks[:smtp].to_s,
      score: result.score
    }
  end

  def verify_stream
    response.headers['Content-Type']      = 'application/x-ndjson'
    response.headers['Cache-Control']     = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no'

    emails = Array(params[:emails])
    if emails.empty?
      response.stream.write({ error: 'Emails required' }.to_json + "\n")
      return
    end

    stop = ActiveModel::Type::Boolean.new.cast(params[:stop_on_first_valid])

    EmailFinder.stream_verify(emails, stop_on_first_valid: stop) do |result|
      response.stream.write(result.to_json + "\n")
    end
  rescue ActionController::Live::ClientDisconnected
    # Client closed connection — stop processing
  ensure
    response.stream.close
  end
end
