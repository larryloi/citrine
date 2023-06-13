# frozen-string-literal: true
module Citrine
  class Operation
    class Result
      DEFAULT_SUCCESS_CODE = "OK"
      DEFAULT_SUCCESS_MESSAGE = "Request is now completed."

      class << self
        def define_attribute(name, &blk)
          define_method(name) do 
            if instance_variable_defined?("@#{name}")
              instance_variable_get("@#{name}")
            else
              instance_variable_set("@#{name}", send("set_attribute_#{name}", context))
            end
          end
          define_singleton_method(name) do |value = nil, &blk|
            define_method("set_attribute_#{name}") do |ctx|
              blk.nil? ? value : instance_exec(ctx, &blk)
            end
            protected "set_attribute_#{name}"
          end
          send(name, &blk) unless blk.nil?
        end
      end

      define_attribute(:code) { |ctx| self.class.name.demodulize }
      define_attribute(:message) { |ctx| "" }
      define_attribute(:data) { |ctx| {} }
      define_attribute(:error) { |ctx| ctx[:error] }

      attr_reader :ignored_errors
      attr_reader :context

      def initialize(context = Context.new)
        @context = context
        @ignored_errors = set_ignored_errors
        init_attributes(context)
      end

      def data?; !data.nil? and !data.empty?; end
      def error?; !!error; end
      def ok?; code == DEFAULT_SUCCESS_CODE; end

      def to_hash
        defined_attributes.inject({}) do |h, attr|
          h[attr.to_sym] = Utils.deep_clone(send(attr)) unless attr == "data"
          h
        end.merge!(Utils.deep_clone(data))
      end

      def ignore_error?(err = error)
        ignored_errors.include?(err.class)
      end

      protected

      def init_attributes(context)
        defined_attributes.each { |attr| send(attr) }
      end

      def defined_attributes
        protected_methods(true).inject([]) do |attrs, meth|
          attrs << $1 if meth =~ /^set_attribute_(.+)$/
          attrs
        end
      end

      def set_ignored_errors; []; end
    end
  end
end
