# frozen-string-literal: true
module Citrine
  module Configurator
    module Autoloader
      module Task
        class Bulk < Base
          def config_data
            data.inject({}) do |config, (name, scheme)|
              config[transform_name(name)] =
                Utils.deep_clone(scheme[:config][:data]).
                      merge!(__scheme__: scheme[:name],
                             __config_id__: scheme[:config][:id])
              config
            end
          end

          protected

          def transform_name(name)
            trans_method = options[:transform_name] || options[:transform_key]
            (trans_method.nil? || !name.respond_to?(trans_method)) ? name : name.send(trans_method)
          end

          def load_scheme!
            autoloader.refresh_schemes(scheme_params)
          end

          def process_result(result)
            Utils.deep_clone(result.data[:update]).each do |scheme|
              deserialize_scheme_config(scheme[:config])
              @data[scheme[:name]] = scheme
            end
            result.data[:remove].each { |name| @data.delete(name) }
            scheme_params[:base] =
              @data.map do |name, scheme|
                  { name: name, config_id: scheme[:config][:id] }
              end
            @scheme_tag = "total: #{scheme_params[:base].size}; " +
                          "updated: #{result.data[:update].size}; " +
                          "removed: #{result.data[:remove].size}"
            @scheme = "#{@scheme_name} (#{scheme_tag})"
          end
        end
      end
    end
  end
end
