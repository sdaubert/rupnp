require_relative 'ssdp/generic_request'
require_relative 'ssdp/http'
require_relative 'ssdp/m_search'
require_relative 'ssdp/multicast_connection'
require_relative 'ssdp/searcher'
require_relative 'ssdp/listener'

module RUPNP

  # SSDP module. This a discovery part of UPnP.
  # @author Sylvain Daubert
  module SSDP

    # Some shorcut for common targets
    KNOWN_TARGETS = {
      :all  => 'ssdp:all',
      :root => 'upnp:rootdevice'
    }


    # Search devices
    # @param [Symbol,String] target
    # @param [Hash] options see {SSDP::Searcher#initialize}
    def self.search(target=:all, options={})
      options[:search_target] =  KNOWN_TARGETS[target] || target
      EM.open_datagram_socket '0.0.0.0', 0, SSDP::Searcher, options
    end

    # Listen for devices' announces
    # @param [Hash] options see {SSDP::Listener#initialize}
    def self.listen(options={})
      EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                              SSDP::Listener, options)
    end

    # Notify announces
    def self.notify(type, stype, options={})
      EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                              SSDP::Notifier, type, subtype, options)
    end
  end

end
