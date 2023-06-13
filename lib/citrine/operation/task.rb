# frozen-string-literal: true
module Citrine
  class Operation
    class Task
      attr_reader :type
      attr_reader :name
      attr_reader :options

      def initialize(type, name, opts)
        @type = type
        @name = name
        @options = opts
      end

      def step?; @type == :step; end
      def pass?; @type == :pass; end
      def fail?; @type == :fail; end
    end
  end
end