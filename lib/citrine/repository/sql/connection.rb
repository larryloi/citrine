# frozen-string-literal: true
require "uri"

Sequel.default_timezone = :utc

module Citrine
	module Repository
		class Sql < Base
			protected

			def create_connection
				@database = Sequel.connect(database_url).tap do |db|
					db.loggers << self.class.logger if options[:enable_sql_log]
				end
			end

			def default_connection_options
				@default_connection_options ||=
					{ preconnect: true,
						single_threaded: true,
						fractional_seconds: true,
						encoding:'utf8mb4'
					}
			end

			def connection_options
				@connection_options ||=
					default_connection_options.merge(options[:connection_options] || {})
			end

			def database_url
				URI(options[:database_url]).tap do |uri|
					uri.query =
						URI.encode_www_form(
							(URI.decode_www_form(uri.query || "")).to_h.merge!(connection_options)
						)
				end.to_s
			end

			def connection_errors
				[Sequel::DatabaseError]
			end

			def destroy_connection
				@database.disconnect if connected?
			end

			def check_connection
				connection = @database.synchronize { |c| c }
				@database.valid_connection?(connection)
			end
		end
	end
end
