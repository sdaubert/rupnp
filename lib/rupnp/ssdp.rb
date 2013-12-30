require_relative 'ssdp/generic_request'
require_relative 'ssdp/http'
require_relative 'ssdp/m_search'
require_relative 'ssdp/multicast_connection'
require_relative 'ssdp/searcher'
require_relative 'ssdp/listener'
require_relative 'ssdp/notifier'
require_relative 'ssdp/search_responder.rb'
require_relative 'ssdp/msearch_responder.rb'
require_relative 'ssdp/usearch_responder.rb'


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
    # @param [Hash] options see {SSDP::Notifier#initialize}
    def self.notify(type, stype, options={})
      EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                              SSDP::Notifier, type, stype, options)
    end
  end

end
