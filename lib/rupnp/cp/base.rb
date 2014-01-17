require 'em-http-request'


module RUPNP

  # CP module to group all control point's classes
  # @author Sylvain Daubert
  module CP

    # Base class for devices and services
    # @author Sylvain Daubert
    class Base
      include EM::Deferrable
      include Tools
      include LogMixin

      # Common HTTP headers for description requests
      HTTP_COMMON_CONFIG = {
        :head => {
          :user_agent => USER_AGENT,
          :host => "#{HOST_IP}:#{DISCOVERY_PORT}",
        },
      }

      def initialize
        @parser = Nori.new(:convert_tags_to => ->(tag){ tag.snakecase.to_sym })
      end

      # Get description from +location+
      # @param [String] location
      # @param [EM::Defferable] getter deferrable to advice about failure
      #  or success. On fail, +getter+ receive a message. On success, it
      #  receive a description (XML Nori hash)
      # @return [void]
      def get_description(location, getter)
        log :info, "getting description for #{location}"
        http = EM::HttpRequest.new(location).get(HTTP_COMMON_CONFIG)

        http.errback do |error|
          getter.set_deferred_status :failed, 'Cannot get description'
        end

        callback = Proc.new do
          description = @parser.parse(http.response)
          log :debug, 'Description received'
          getter.succeed description
        end

        http.headers do |h|
          unless h['SERVER'] =~ /UPnP\/1\.\d/
            log :error, "Not a supported UPnP response : #{h['SERVER']}"
            http.cancel_callback callback
            http.fail
          end
        end

        http.callback &callback
      end

      # @return String
      def inspect
        "#<#{self.class}:#{object_id} type=#{type.inspect}>"
      end

    end

  end
end
