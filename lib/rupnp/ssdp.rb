require_relative 'ssdp/generic_request'
require_relative 'ssdp/http'
require_relative 'ssdp/m_search'
require_relative 'ssdp/multicast_connection'
require_relative 'ssdp/searcher'
require_relative 'ssdp/listener'

# @author Sylvain Daubert
module RUPNP

  module SSDP

    KNOWN_TARGETS = {
      :all  => 'ssdp:all',
      :root => 'upnp:rootdevice'
    }


    def self.search(target=:all, options={})
      options[:search_target] =  KNOWN_TARGETS[target] || target
      EM.open_datagram_socket '0.0.0.0', 0, SSDP::Searcher, options
    end

    def self.listen(options={})
      EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                              SSDP::Listener, options)
    end

  end

end
