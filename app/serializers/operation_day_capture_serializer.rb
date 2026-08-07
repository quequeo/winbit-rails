class OperationDayCaptureSerializer
  def initialize(capture)
    @capture = capture
  end

  def as_json(*)
    {
      id: capture.id,
      captureDate: capture.capture_date.strftime('%Y-%m-%d'),
      asset: capture.asset,
      resultLabel: capture.result_label,
      originalFilename: capture.original_filename,
      contentType: capture.content_type,
      byteSize: capture.byte_size,
      imageUrl: "/api/admin/v1/operation_day_captures/#{capture.id}/image",
      createdAt: capture.created_at,
    }
  end

  private

  attr_reader :capture
end
