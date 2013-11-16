require 'net/http'


module RUPNP
  module SSDP

    # Generic HTTPU request
    class GenericRequest < Net::HTTPGenericRequest

      # @private
      HTTP_VERSION = '1.1'

      # @param [String] path
      # @param [nil,Hash] header
      def initialize(path, header=nil)
        super self.class::REQUEST, false, false, path, header
        delete 'Accept'
        @io = StringIO.new
      end

      # @return [String]
      def to_s
        @io.string.clear
        exec @io, HTTP_VERSION, @path
        @io.string
      end

    end

  end
end
