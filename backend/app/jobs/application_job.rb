class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  def arguments_for_logging
    return super unless arguments.is_a?(Array)

    filter = Rails.application.config.filter_parameters
    parameter_filter = ActiveSupport::ParameterFilter.new(filter)

    arguments.map do |arg|
      if arg.is_a?(Hash)
        parameter_filter.filter(arg)
      else
        arg
      end
    end
  end
end
