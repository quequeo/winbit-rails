# frozen_string_literal: true

module EmailCampaigns
  # Validates and normalizes a campaign email attachment (PDF / XLSX, ≤10MB).
  class Attachment
    MAX_BYTES = 10.megabytes
    ALLOWED_EXTENSIONS = %w[.pdf .xlsx].freeze
    MIME_BY_EXT = {
      '.pdf' => 'application/pdf',
      '.xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    }.freeze

    Payload = Struct.new(:filename, :content, :content_type, keyword_init: true)

    def self.from_upload(upload)
      new(upload).to_payload
    end

    def initialize(upload)
      @upload = upload
    end

    def to_payload
      raise ArgumentError, 'Adjunto inválido' if @upload.blank?

      filename = original_filename
      ext = File.extname(filename).downcase
      unless ALLOWED_EXTENSIONS.include?(ext)
        raise ArgumentError, 'Adjunto inválido: solo se permiten PDF o XLSX'
      end

      content = read_content
      if content.bytesize.zero?
        raise ArgumentError, 'Adjunto vacío'
      end
      if content.bytesize > MAX_BYTES
        raise ArgumentError, "Adjunto demasiado grande (máx. #{MAX_BYTES / 1.megabyte}MB)"
      end

      Payload.new(
        filename: filename,
        content: content,
        content_type: MIME_BY_EXT.fetch(ext)
      )
    end

    private

    def original_filename
      name =
        if @upload.respond_to?(:original_filename)
          @upload.original_filename
        elsif @upload.is_a?(Hash)
          @upload[:filename] || @upload['filename']
        end
      name = name.to_s.strip
      raise ArgumentError, 'Adjunto sin nombre de archivo' if name.blank?

      File.basename(name)
    end

    def read_content
      if @upload.respond_to?(:read)
        pos = @upload.pos if @upload.respond_to?(:pos)
        data = @upload.read
        @upload.rewind if @upload.respond_to?(:rewind)
        @upload.pos = pos if pos && @upload.respond_to?(:pos=)
        data.to_s.b
      elsif @upload.is_a?(Hash)
        (@upload[:content] || @upload['content']).to_s.b
      else
        raise ArgumentError, 'Adjunto inválido'
      end
    end
  end
end
