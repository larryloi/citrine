# frozen-string-literal: true

# Patched Reel::RequestMixin to add convenient methods
#   :query - to get query string
#   :params - to extract parameters from the query string

module Reel
  module RequestMixin
    def query
      query_string.to_s
    end

    def params
      @params ||= Hash[URI::decode_www_form(query)] 
    end
  end
end
