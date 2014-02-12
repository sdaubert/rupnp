require 'em-http-server'

module RUPNP

  # Event server to receive events from services.
  # @author Sylvain Daubert
  class CP::EventServer < EM::HttpServer::Server
    include LogMixin

    # @private
    @@add_url = EM::Channel.new
    # @private
    @@urls = []

    @@add_url.subscribe do |url|
      @@urls << url
    end

    class << self
      # Channel to add url for listening to
      # @param [Object] url
      # @return [void]
      def add_event_url(url)
        @@add_url << url
      end
    end


    # Channel to return received updated variables from events
    # @return [EM::Channel]
    attr_reader :events


    # Process a HTTP request received from a service/device
    def process_http_request
      log :debug, 'EventServer: receive request'

      response = EM::DelegatedHttpResponse.new(self)

#      p  @http_request_method
#      p  @http_request_uri
#      p  @http_query_string
#      p  @http_protocol
#      p  @http_content
#      p  @http[:cookie]
#      p  @http[:content_type]
#      p  @http.inspect

      if @http_request_method != 'NOTIFY'
        log :info, "EventServer: method #@http_request_method not allowed"
        response.status = 405
        response.headers['Allow'] = 'NOTIFY'
        response.send_response
        return
      end

      url, event = @@urls.find { |a| a[0] == @http_request_uri }

      if url.nil?
        log :info, "EventServer: Requested URI #@http_request_uri unknown"
        response.status = 404
        response.send_response
        return
      end

      if !event.is_a? EM::Channel
        log :error, "EventServer: internal error!"
        response.status = 500
        response.send_response
        return
      end

      if !@http.has_key?(:nt) or !@http.has_key?(:nts)
        log :warn, 'EventServer: malformed NOTIFY event message'
        log :debug, "#@http_headers\n#@http_content"
        response.status = 400
        response.send_response
        return
      end

      if @http[:nt] != 'upnp:event' or @http[:nts] != 'upnp:propchange' or
          !@http.has_key?(:sid) or @http[:sid] == ''
        log :warn, 'EventServer: precondition failed'
        log :debug, "#@http_headers\n#@http_content"
        response.status = 412
        response.send_response
        return
      end

      if event.sid != @http[:sid]
        log :warn, 'EventServer: precondition failed (unknown SID)'
        log :debug, "#@http_headers\n#@http_content"
        response.status = 412
        response.send_response
        return
      end

      event << {
        :sid => @http[:sid],
        :seq => @http[:seq],
        :content => @http_content }

      response.send_response
    end

  end

end
