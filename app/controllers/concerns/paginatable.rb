module Paginatable
  extend ActiveSupport::Concern

  private

  def paginate(scope, default_per_page:, max_per_page:)
    page = params[:page].to_i
    page = 1 if page <= 0

    raw_per_page = params[:per_page].to_i
    per_page = raw_per_page.positive? ? raw_per_page.clamp(1, max_per_page) : default_per_page

    total = scope.count
    records = scope.offset((page - 1) * per_page).limit(per_page)

    {
      records: records,
      pagination: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }
  end
end
