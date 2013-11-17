require 'em-http-server'

module RUPNP

  # Event server to receive events from services.
  # @author Sylvain Daubert
  class CP::EventServer < EM::HttpServer::Server
    include LogMixin

    # Channel to add url for listening to
    # @return [EM::Channel]
    attr_reader :add_url


    # @param [EM::Channel] add_url_channel channel for adding url
    def initialize(add_url_channel)
      super

      @urls = []
      @add_url = add_url_channel

      @add_url.subscribe do |url|
        log :info, "add URL #{url} for eventing"
        @urls << url
      end
    end

    # Process a HTTP request received from a service/device
    def process_http_request
      log :debug, 'EventServer: receive request'
      url, event = @urls.find { |a| a[0] == @http_request_uri }

      if event.is_a? EM::Channel
        if @http_request_method == 'NOTIFY'
          if @http[:nt] == 'upnp:event' and @http[:nts] == 'upnp:propchange'
            event << {
              :sid => @http[:sid],
              :seq => @http[:seq],
              :content => @http_content }
          else
            log :warn, 'EventServer: ' +
              "malformed NOTIFY event message:\n#@http_headers\n#@http_content"
          end
        else
          log :warn, "EventServer: unknown HTTP verb: #@http_request_method"
        end
      end
    end

  end

end
