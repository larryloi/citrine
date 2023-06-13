# frozen-string-literal: true
require "time"
require "date"

module Citrine
  class Schema
    module Attribute
      class SingleValue
        class TypeMismatched < Error
          def initialize(name, reason)
            super("Type MISMATCHED for attribute #{name}: #{reason}")
          end
        end

        class MissingRequiredAttribute < Error
          def initialize(name)
            super("Missing required attribute #{name}")
          end
        end

        class InvalidAttributeValue < Error
          def initialize(name, reason)
            super("Invalid value for attribute #{name}: #{reason}")
          end
        end
        class TypeCastingError < Error
          def initialize(name, reason)
            super("Failed to cast attribute #{name}: #{reason}")
          end
        end

        DEFAULT_DATE_FORMAT = "%Y-%m-%d"
        DEFAULT_DATETIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%L"
        DEFAULT_TIME_FORMAT = DEFAULT_DATETIME_FORMAT
        DEFAULT_DECIMAL_PRECISION = 2
        DEFAULT_INTEGER_BASE = 10

        attr_reader :name
        attr_reader :display_name
        attr_reader :bind_to
        attr_reader :map
        attr_reader :type
        attr_reader :default
        attr_reader :options
        attr_accessor :value

        def initialize(name,
                       bind_to: nil,
                       map: nil,
                       type: nil,
                       required: default_imperative,
                       default: nil,
                       any_of: [],
                       match: nil,
                       assure: nil,
                       **opts, &blk)
          @name = name.to_sym
          @display_name = name.to_s.upcase
          @bind_to = bind_to&.to_sym
          @map = map
          @inline = false
          @type = type&.to_sym&.downcase
          @required = !!required
          @default = default
          @any_of = any_of
          @match = match
          @assurance = assure
          @handler = block_given? ? blk : ->(v) { v }
          @options = default_options.merge(opts)
          @schema = nil
          verify
          reset
        end

        def default_imperative; true; end

        def reset
          @value = default
        end

        def default_options
          @default_options ||= {
            date_format: DEFAULT_DATE_FORMAT,
            datetime_format: DEFAULT_DATETIME_FORMAT,
            time_format: DEFAULT_TIME_FORMAT,
            decimal_precision: DEFAULT_DECIMAL_PRECISION,
            integer_base: DEFAULT_INTEGER_BASE
          }
        end

        def value=(v); set(v); end
        def set(v); set!(v).tap { |r| validate(r) }; end
        def set!(v); @value = process(v); end

        def inline?; @inline; end
        def typed?; !@type.nil?; end
        def required?; @required; end
        def optional?; !required?; end
        alias_method :nullable?, :optional?
        def has_default?; !default.nil?; end

        def valid?(v = value)
          !missing?(v) and type_matched? and any_of?(v) and matched?(v) and assured?(v)
        end

        def missing?(v = value); required? and v.nil?; end
        def type_matched?(v = value)
          !typed? or (v.nil? and nullable?) or _type_matched?(v)
        end
        def any_of?(v = value); @any_of.empty? or _any_of?(v); end
        def matched?(v = value); @match.nil? or _matched?(v); end
        def assured?(v = value); @assurance.nil? or _assured?(v); end

        def validate(v = value)
          validate_required(v)
          validate_type(v)
          validate_any_of(v)
          validate_match(v)
          validate_assurance(v)
        end

        def validate_type(v = value)
          type_matched?(v) or raise TypeMismatched.new(display_name, "MUST be an instance of #{type}")
        end

        def validate_required(v = value)
          !missing?(v) or raise MissingRequiredAttribute.new(display_name)
        end

        def validate_any_of(v = value)
          any_of?(v) or raise InvalidAttributeValue.new(display_name, "#{v.inspect} is NOT one of #{@any_of.join(", ")}")
        end

        def validate_match(v = value)
          matched?(v) or raise InvalidAttributeValue.new(display_name, "#{v.inspect} does NOT match #{@match.inspect}")
        end

        def validate_assurance(v = value)
          assured?(v) or raise InvalidAttributeValue.new(display_name, "#{v.inspect} does NOT meet the assurance.")
        end

        def has_schema?; !@schema.nil?; end

        def schema_inline(spec: nil, **opts, &blk)
          @inline = true
          define_singleton_method(:to_h) { value }
          schema(spec: spec, **opts, &blk)
        end

        def schema(spec: nil, **opts, &blk)
          @schema = Schema.new(spec: spec, **options.merge(opts), &blk)
        end

        def to_h
          {
            (bind_to || name) =>
            map.nil? ? value : map[value.respond_to?(:to_sym) ? value.to_sym : value]
          }
        end
        alias_method :to_hash, :to_h

        protected

        def verify
          unless @type.nil?
            verify_type
            verify_default unless @default.nil?
          end
          verify_any_of unless @any_of.empty?
          verify_match unless @match.nil?
          verify_assurance unless @assurance.nil?
        end

        def verify_type
          unless respond_to?(cast_method(type), true)
            raise ArgumentError, "UNKNOWN type for attribute #{display_name}: #{type}"
          end
        end

        def verify_default
          validate(default)
        end

        def verify_any_of
          unless @any_of.respond_to?(:include?)
            raise ArgumentError, "List of values for attribute #{display_name} MUST respond to #include?"
          end
        end

        def verify_match
          unless @match.respond_to?(:match)
            raise ArgumentError, "Matching pattern of attribute #{display_name} MUST respond to #match"
          end
        end

        def verify_assurance
          unless @assurance.respond_to?(:call)
            raise ArgumentError, "Assurance of attribute #{display_name} must respond to #call"
          end
        end

        def _type_matched?(v); send("#{type}?", v); end
        def _any_of?(v); @any_of.include?(v); end
        def _matched?(v); !!@match.match(v.to_s); end
        def _assured?(v); !!@assurance.call(v); end

        def process(value)
          v = set_default_value(extract_value(value))
          @handler.call(has_schema? ? cast_by_schema(v) : cast_by_value(v))
        end

        def extract_value(value)
          if inline?
            extract_value_by_schema(value)
          else
            extract_value_by_key(value)
          end
        end

        def extract_value_by_schema(value)
          d = @schema.attributes.inject({}) do |r, (k, _)|
                v = extract_value_by_key(value, key: k)
                r[k] = v unless v.nil?
                r
              end
          d.empty? ? nil : d
        end

        def extract_value_by_key(value, key: name)
          if value.has_key?(key.to_sym)
            value[key.to_sym]
          elsif value.has_key?(key.to_s)
            value[key.to_s]
          end
        end

        def set_default_value(value)
          (has_default? and value.nil?) ? default : value
        end

        def cast_by_schema(value)
          value.nil? ? value : @schema.parse(value)
        end

        def cast_by_value(value)
          return value if value.nil? or !typed?
          cast_by_value!(value)
        rescue StandardError => e
          raise TypeCastingError.new(display_name, "#{e.class.name} - #{e.message}")
        end

        def cast_by_value!(value)
          if send("#{type}?", value)
            value
          else
            send(cast_method(type), value)
          end
        end

        def cast_method(type); "cast_#{type}"; end

        def cast_string(value)
          case value
          when Time
            value.strftime(options[:time_format])
          when DateTime
            value.strftime(options[:datetime_format])
          when Date
            value.strftime(options[:date_format])
          else
            String(value)
          end
        end

        def cast_integer(value); Integer(value, options[:integer_base]); end
        def cast_float(value); Float(value); end
        def cast_decimal(value); Float(value).round(options[:decimal_precision]); end
        def cast_symbol(value); value.to_sym; end
        def cast_time(value); Time.strptime(value, options[:time_format]); end
        def cast_date(value); Date.strptime(value, options[:date_format]); end
        def cast_datetime(value); DateTime.strptime(value, options[:datetime_format]); end
        def cast_bool(value)
          return false if value == 'false'
          return true if value == 'true'
          !!value
        end

        def string?(value); value.is_a?(String); end
        def integer?(value); value.is_a?(Integer); end
        def float?(value); value.is_a?(Float); end
        alias_method :decimal?, :float?
        def symbol?(value); value.is_a?(Symbol); end
        def time?(value); value.is_a?(Time); end
        def date?(value); value.is_a?(Date); end
        def datetime?(value); value.is_a?(DateTime); end
        def bool?(value); value.is_a?(TrueClass) or value.is_a?(FalseClass); end
      end
    end
  end
end
