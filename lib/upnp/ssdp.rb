require_relative 'ssdp/generic_request'
require_relative 'ssdp/http_response'
require_relative 'ssdp/m_search'
require_relative 'ssdp/multicast_connection'
require_relative 'ssdp/searcher'

# @author Sylvain Daubert
module Upnp

  module SSDP

    KNOWN_TARGETS = {
      :all  => 'ssdp:all',
      :root => 'upnp:rootdevice'
    }


    def self.search(target=:all, options={})
      options[:search_target] =  KNOWN_TARGETS[target] || target
      puts "searching..."
      EM.open_datagram_socket '0.0.0.0', 0, SSDP::Searcher, options
    end

  end

end
