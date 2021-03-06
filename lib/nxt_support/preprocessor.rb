require "nxt_support/preprocessors/strip_preprocessor"
require "nxt_support/preprocessors/downcase_preprocessor"

module NxtSupport
  class Preprocessor
    extend NxtRegistry

    PREPROCESSORS = registry :type, callable: false do
      level :preprocessors
    end

    attr_accessor :attributes, :preprocessors, :options
    attr_reader :type

    def initialize(attributes, options)
      @type = options.fetch(:column_type) { :string }
      @options = options

      attributes_to_preprocess(attributes, options)
      extract_preprocessors
      register_default_preprocessors
    end

    def process(record)
      attributes.each do |attr|
        value_to_process = record[attr]
        processed_value = process_value(value_to_process)
        record[attr] = processed_value
      end
    end

    private

    def attributes_to_preprocess(attributes, options = {})
      if options[:only]
        attributes.select! { |attr| attr.in?(options[:only]) }
      elsif options[:except]
        attributes.reject! { |attr| attr.in?(options[:except]) }
      end

      @attributes = attributes
    end

    def extract_preprocessors
      @preprocessors = options[:preprocessors]
      raise ArgumentError, 'No preprocessors provided' unless preprocessors.present?
    end

    def process_value(value)
      preprocessors.each do |key|
        value = resolve(key, value)
      end

      value
    end

    def resolve(key, value)
      if key.respond_to?(:lambda?)
        key.call(value)
      else
        PREPROCESSORS.resolve(type).resolve(key).new(value).call
      end
    end

    def register_default_preprocessors
      PREPROCESSORS.type(:string).preprocessors!(:strip, NxtSupport::Preprocessors::StripPreprocessor)
      PREPROCESSORS.type(:string).preprocessors!(:downcase, NxtSupport::Preprocessors::DowncasePreprocessor)
    end

    class << self
      def register(name, preprocessor, type = :string)
        PREPROCESSORS.type(type).preprocessors!(name, preprocessor)
      end
    end
  end
end
