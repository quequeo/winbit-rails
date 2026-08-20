# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  class Month
    PATTERN = /\A(\d{4})-(0[1-9]|1[0-2])\z/

    SPANISH_TO_NUMBER = {
      'enero' => 1,
      'febrero' => 2,
      'marzo' => 3,
      'abril' => 4,
      'mayo' => 5,
      'junio' => 6,
      'julio' => 7,
      'agosto' => 8,
      'septiembre' => 9,
      'setiembre' => 9,
      'octubre' => 10,
      'noviembre' => 11,
      'diciembre' => 12
    }.freeze

    NUMBER_TO_SPANISH = {
      1 => 'enero',
      2 => 'febrero',
      3 => 'marzo',
      4 => 'abril',
      5 => 'mayo',
      6 => 'junio',
      7 => 'julio',
      8 => 'agosto',
      9 => 'septiembre',
      10 => 'octubre',
      11 => 'noviembre',
      12 => 'diciembre'
    }.freeze

    def self.valid?(value)
      value.to_s.match?(PATTERN)
    end

    def self.parse(value)
      return unless valid?(value)

      value.to_s
    end

    def self.number(value)
      parsed = parse(value)
      return unless parsed

      parsed.split('-').last.to_i
    end

    def self.year(value)
      parsed = parse(value)
      return unless parsed

      parsed.split('-').first.to_i
    end

    def self.spanish_name(value)
      month_number = number(value)
      NUMBER_TO_SPANISH[month_number]
    end

    def self.number_from_spanish(name)
      SPANISH_TO_NUMBER[normalize_spanish(name)]
    end

    def self.normalize_spanish(name)
      ActiveSupport::Inflector.transliterate(utf8(name)).downcase.squish
    end

    def self.utf8(value)
      str = value.to_s.dup
      str.force_encoding(Encoding::UTF_8)
      return str if str.valid_encoding?

      str.encode(Encoding::UTF_8, Encoding::ASCII_8BIT, invalid: :replace, undef: :replace)
    end
  end
end
