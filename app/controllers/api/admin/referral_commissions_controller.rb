module Api
  module Admin
    class ReferralCommissionsController < BaseController
      def index
        page     = [params[:page].to_i, 1].max
        per_page = 20

        scope = PortfolioHistory
          .joins(:investor)
          .where(event: 'REFERRAL_COMMISSION', status: 'COMPLETED')
          .where(investors: { status: 'ACTIVE' })
          .order(date: :desc)

        total = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page)

        render json: {
          data: records.map { |r| serialize(r) },
          pagination: {
            page: page,
            per_page: per_page,
            total: total,
            total_pages: (total.to_f / per_page).ceil
          }
        }
      end

      private

      def serialize(record)
        inv = record.investor
        {
          id:               record.id,
          investor_id:      inv.id,
          investor_name:    inv.name,
          investor_email:   inv.email,
          amount:           record.amount.to_f,
          date:             record.date.iso8601,
          previous_balance: record.previous_balance.to_f,
          new_balance:      record.new_balance.to_f
        }
      end
    end
  end
end
