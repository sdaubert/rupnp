require 'net/http'


module Upnp
  module SSDP

    class GenericRequest < Net::HTTPGenericRequest

      HTTP_VERSION = '1.1'

      def initialize(path, header=nil)
        super self.class::REQUEST, false, false, path, header
        delete 'Accept'
        @io = StringIO.new
      end

      def to_s
        @io.string.clear
        exec @io, HTTP_VERSION, @path
        @io.string
      end

    end

  end
end
