# frozen-string-literal: true
module Citrine
  module Utils
    module DeepSort
      refine Array do
        def deep_sort(**opts)
          deep_sort_by(opts) { |obj| obj }
        end

        def deep_sort!(**opts)
          deep_sort_by!(opts) { |obj| obj }
        end

        def deep_sort_by(**opts, &block)
          map do |value|
            value.is_a?(Array) or value.is_a?(Hash) ?
              value.deep_sort_by(opts, &block) : value
          end.tap { |a| a.sort_by!(&block) unless opts[:preserve_array_order] }
        end

        def deep_sort_by!(**opts, &block)
          map! do |value|
            value.is_a?(Array) or value.is_a?(Hash) ?
              value.deep_sort_by!(opts, &block) : value
          end.tap { |a| a.sort_by!(&block) unless opts[:preserve_array_order] }
        end
      end

      refine Hash do
        def deep_sort(**opts)
          deep_sort_by(opts) { |obj| obj }
        end

        def deep_sort!(**opts)
          deep_sort_by!(opts) { |obj| obj }
        end

        def deep_sort_by(**opts, &block)
          Hash[
            map do |key, value|
              [ key.is_a?(Array) || key.is_a?(Hash) ?
                  key.deep_sort_by(opts, &block) : key,
                value.is_a?(Array) || value.is_a?(Hash) ?
                  value.deep_sort_by(opts, &block) : value
              ]
            end.sort_by(&block)
          ]
        end

        def deep_sort_by!(**opts, &block)
          replace(Hash[
            map do |key, value|
              [ key.is_a?(Array) || key.is_a?(Hash) ?
                  key.deep_sort_by!(opts, &block) : key,
                value.is_a?(Array) || value.is_a?(Hash) ?
                  value.deep_sort_by!(opts, &block) : value
              ]
            end.sort_by(&block)
          ])
        end
      end
    end
  end
end
