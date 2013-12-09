require 'socket'

module RUPNP

  # M-SEARCH responder for M-SEARCH unicast requests from control points.
  # @author Sylvain Daubert
  class SSDP::USearchResponder < EM::Connection
    include HTTP
    include SSDP::SearchResponder

    # @param [Hash] options
    # @option options [Integer] :ttl
    def initialize(device, options={})
      @device = device
      @options = options
      set_ttl options[:ttl] || DEFAULT_TTL
    end


    private

    def set_ttl(ttl)
      value = [ttl].pack('i')
      set_sock_opt Socket::IPPROTO_IP, Socket::IP_TTL, value
    end

  end

end
