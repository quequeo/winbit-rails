class OutgoingEmailSerializer
  def initialize(email, include_body: false)
    @email = email
    @include_body = include_body
  end

  def as_json(*)
    json = {
      id: email.id,
      kind: email.kind,
      status: email.status,
      to: email.to_email,
      subject: email.subject,
      error: email.error,
      requestId: email.request_id,
      hasReceipt: email.with_receipt?,
      receiptFilename: email.with_receipt? ? RequestReceiptPdfs::Generate.filename_for(email.investor_request) : nil,
      createdAt: email.created_at,
      sentAt: email.sent_at,
      scheduledFor: email.scheduled_for,
      investor: { id: email.investor_id, name: email.investor.name },
    }
    if WelcomeEmail.welcome?(email)
      json[:welcome] = {
        greeting: WelcomeEmail.greeting_of(email),
        usesPassword: WelcomeEmail.uses_password?(email),
        missing: WelcomeEmail.missing(email),
        guideFilename: WelcomeGuidePdfs::Generate::FILENAME,
      }
    end
    if @include_body
      json[:bodyHtml] = MailPersonalization.apply(
        email.body_html,
        requested_at: email.investor_request&.requested_at,
        at: email.scheduled_for || Time.current
      )
    end
    json
  end

  private

  attr_reader :email
end
