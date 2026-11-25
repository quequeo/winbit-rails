module Api
  module Admin
    class OutgoingEmailsController < BaseController
      before_action :set_email, only: [:show, :deliver, :discard, :schedule, :unschedule, :regenerate, :welcome, :welcome_guide]

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

      def schedule
        OutgoingEmails::Schedule.call(
          outgoing_email: @email, scheduled_by: current_user, at: params.permit(:id, :scheduled_for)[:scheduled_for]
        )

        ActivityLogger.log(
          user: current_user,
          action: 'schedule_outgoing_email',
          target: @email,
          metadata: { label: "#{@email.kind} - #{@email.to_email}" }
        )

        render json: { data: OutgoingEmailSerializer.new(@email).as_json }
      rescue StandardError => e
        render_error(e.message, status: :unprocessable_entity)
      end

      def unschedule
        return render_error('El correo no está programado', status: :unprocessable_entity) unless @email.status == 'SCHEDULED'

        @email.update!(status: 'DRAFT', scheduled_by: nil)

        ActivityLogger.log(
          user: current_user,
          action: 'unschedule_outgoing_email',
          target: @email,
          metadata: { label: "#{@email.kind} - #{@email.to_email}" }
        )

        head :no_content
      end

      def regenerate
        OutgoingEmails::Regenerate.call(outgoing_email: @email)

        ActivityLogger.log(
          user: current_user,
          action: 'regenerate_outgoing_email',
          target: @email,
          metadata: { label: "#{@email.kind} - #{@email.to_email}" }
        )

        render json: { data: OutgoingEmailSerializer.new(@email, include_body: true).as_json }
      rescue OutgoingEmails::Regenerate::NotRegenerable => e
        render_error(e.message, status: :unprocessable_entity)
      end

      # Mail de alta: completa el saludo (Bienvenido/Bienvenida) y, si el
      # inversor entra sin Google, genera la contraseña inicial: se la asigna
      # al inversor (reemplaza la anterior) y la pone en el mail.
      def welcome
        return render_error('Este correo ya fue enviado o descartado', status: :unprocessable_entity) unless @email.pending?
        return render_error('Solo se completa en el mail de alta', status: :unprocessable_entity) unless WelcomeEmail.welcome?(@email)

        greeting = params.permit(:id, :greeting)[:greeting].to_s.downcase
        return render_error('Elegí Bienvenido o Bienvenida', status: :unprocessable_entity) unless WelcomeEmail.valid_greeting?(greeting)

        investor = @email.investor
        password = WelcomeEmail.uses_password?(@email) ? WelcomeEmail.generate_password : nil
        rendered = OutgoingEmails::Draft.new(
          kind: @email.kind, investor: investor, request: @email.investor_request,
          options: { greeting: greeting, password: password }
        ).rendered
        ActiveRecord::Base.transaction do
          investor.update!(password: password) if password
          @email.update!(rendered.merge(error: nil))
        end

        ActivityLogger.log(
          user: current_user,
          action: 'complete_welcome_email',
          target: @email,
          metadata: { label: "#{@email.kind} - #{@email.to_email}" }
        )

        render json: { data: OutgoingEmailSerializer.new(@email, include_body: true).as_json }
      end

      # Vista previa de la Guía de bienvenida que se adjunta al mail de alta.
      def welcome_guide
        return render_error('Solo el mail de alta lleva la guía', status: :unprocessable_entity) unless WelcomeEmail.welcome?(@email)

        pdf = WelcomeGuidePdfs::Generate.call(investor: @email.investor, greeting: WelcomeEmail.greeting_of(@email))
        send_data pdf, filename: WelcomeGuidePdfs::Generate::FILENAME, type: 'application/pdf', disposition: 'attachment'
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
