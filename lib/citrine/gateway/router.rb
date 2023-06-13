# frozen-string-literal: true
require "sinatra/base"
require "sinatra/json"
require "sinatra/custom_logger"

module Citrine
  module Gateway
    class Router < Sinatra::Base
      using CoreRefinements

      class Error < Citrine::Error
        def initialize(reason)
          super("#{reason.message} (#{reason.class.name.demodulize})")
        end
      end

      class InvalidRequest < Error; end
      class InvalidResult < Error; end

      include Utils::Common
      include Utils::Namespace

      helpers Sinatra::JSON
      helpers Sinatra::CustomLogger

      configure do
        enable :logging
        use Rack::CommonLogger, Actor.logger
        set :logger, Actor.logger
        set :show_exceptions, false
      end

      error do
        logger.error env["sinatra.error"].full_message
        halt_with(500, Citrine::InternalServerError.new)
      end
      error(Citrine::InternalServerError) { halt_with(500) }
      error(InvalidRequest) { halt_with(400) }

      class << self
        def bootstrap(**config)
          set :router_config, config
          set_default_values
          create_routes
        end

        protected

        def set_default_values
          router_config[:root_path] ||= "/"
          router_config[:conversion] ||= {}
          router_config[:routes] ||= {}
        end

        def create_routes
          router_config[:routes].each_pair do |route, config|
            config[:base_path] ||= route.to_s
            config[:parameters] ||= {}
            config[:result] = default_result_schema.deep_merge(config[:result] || {})
            create_route(route, config)
          end
        end

        def default_result_schema
          {
            code: { type: "string" },
            message: { type: "string" },
            data: { required: false }
          }
        end

        def create_route(route, config)
          config[:apis].each_pair do |api, spec|
            spec[:authorizer] = config[:authorizer]
            spec[:delegate] ||= api
            spec[:to] ||= config[:to]
            spec[:method] ||= config[:method]
            spec[:parameters] = config[:parameters].deep_merge(spec[:parameters] || {})
            spec[:path] =
              File.join(router_config[:root_path],
                        config[:base_path],
                        spec[:path] || api.to_s)
            spec[:result] = config[:result].deep_merge(spec[:result] || {})
            spec[:conditions] = {}
            unless config[:vhost].nil?
              spec[:conditions][:host_name] = /^#{config[:vhost]}$/
            end
            create_api(spec)
          end
        end

        def create_api(spec)
          spec = api_spec(spec)
          send(spec[:method].to_sym, spec[:path], **spec[:conditions]) { route_request(spec) }
        end

        def api_spec(spec)
          spec.tap do |s|
            %i(conversion).each do |section|
              if router_config.has_key?(section)
                s[section] = router_config[section].merge(s[:section] || {})
              end
            end
          end
        end
      end

      [:debug, :info, :warn, :error].each do |level|
        define_method(level) do |string|
          logger.send(level, string)
        end
      end

      protected

      def router_config; settings.router_config; end

      def authorize_request(authorizer)
        actor(authorizer).authorize_request(request: env["raw_request"])
      end

      def route_request(spec)
        env["citrine.api.spec"] = spec
        result = authorize_request(spec[:authorizer]) if spec[:authorizer]
        if result.nil? or result.ok?
          extract_request_params
          params.merge!(result.data) unless result.nil?
          parameters = convert_params(params)
          result = dispatch_request(parameters)
        else
          logger.error "Unauthorized request: #{result.message} (#{result.code})"
        end
        response = convert_result(result.to_hash)
        json response
      end

      def extract_request_params
        if request.media_type == "application/json" and
          request.content_length.to_i > 0
          request.body.rewind
          params.merge!(JSON.parse(request.body.read))
        end
      end

      def convert_params(spec = env["citrine.api.spec"], params)
        result = Schema.parse(spec[:parameters], params,
                              spec[:conversion].merge(raise_on_error: false))
        raise InvalidRequest.new(result[:error]) if result[:error]
        result[:data]
      end

      def dispatch_request(spec = env["citrine.api.spec"], params)
        actor(spec[:to].to_sym).send(spec[:delegate], params)
      end

      def convert_result(spec = env["citrine.api.spec"], result)
        result = Schema.parse(spec[:result], result,
                              spec[:conversion].merge(raise_on_error: false))
        raise InvalidResult.new(result[:error]) if result[:error]
        result[:data]
      end

      def halt_with(status_code, error = env["sinatra.error"])
        halt status_code,
             { "Content-Type" => "application/json" },
             convert_result({ code: error.class.name.demodulize,
                              message: error.message }).to_json
      end
    end
  end
end
