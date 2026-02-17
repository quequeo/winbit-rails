module RecordLookup
  extend ActiveSupport::Concern

  private

  def find_record!(model:, id:, includes: nil, message:, status: :not_found)
    scope = includes.present? ? model.includes(*Array(includes)) : model.all
    record = scope.find_by(id: id)
    return record if record

    render_error(message, status: status)
    nil
  end
end
