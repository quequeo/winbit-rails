module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  end

  private

  def handle_record_invalid(error)
    render_error(error.record.errors.full_messages.join(', '), status: :bad_request)
  end

  def handle_parameter_missing(error)
    render_error(error.message, status: :bad_request)
  end
end
