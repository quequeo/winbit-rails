module Api
  module Admin
    class OutgoingEmailsController < BaseController
      before_action :set_email, only: [:show, :deliver, :discard]

      def index
        scope = OutgoingEmail.includes(:investor, :investor_request).recent_first
        scope = params[:status] == 'all' ? scope : scope.pending
        paginated = paginate(scope, default_per_page: 200, max_per_page: 200)

        render json: {
          data: {
            emails: paginated[:records].map { |e| OutgoingEmailSerializer.new(e).as_json },
            pendingCount: OutgoingEmail.pending.count,
            pagination: paginated[:pagination],
          },
        }
      end

      def show
        render json: { data: OutgoingEmailSerializer.new(@email, include_body: true).as_json }
      end

      def deliver
        OutgoingEmails::SendEmail.call(outgoing_email: @email, sent_by: current_user)

        ActivityLogger.log(
          user: current_user,
          action: 'send_outgoing_email',
          target: @email,
          metadata: { label: "#{@email.kind} - #{@email.to_email}" }
        )

        head :no_content
      rescue StandardError => e
        render_error(e.message, status: :unprocessable_entity)
      end

      def discard
        return render_error('Este correo ya fue enviado o descartado', status: :unprocessable_entity) unless @email.pending?

        @email.update!(status: 'DISCARDED')

        ActivityLogger.log(
          user: current_user,
          action: 'discard_outgoing_email',
          target: @email,
          metadata: { label: "#{@email.kind} - #{@email.to_email}" }
        )

        head :no_content
      end

      private

      def set_email
        @email = find_record!(model: OutgoingEmail, id: params[:id], message: 'Correo no encontrado')
      end
    end
  end
end
