require 'socket'
require 'ipaddr'

module RUPNP

  class SSDP::MulticastConnection < EM::Connection
    include LogMixin

    def initialize(ttl=nil)
      @ttl = ttl || DEFAULT_TTL
      setup_multicast_socket
    end

    def peer_info
      Socket.unpack_sockaddr_in(get_peername)
    end


    private

    def setup_multicast_socket
      set_membership IPAddr.new(MULTICAST_IP).hton + IPAddr.new('0.0.0.0').hton
      set_ttl
      set_reuse_addr
    end

    def set_membership(value)
      set_sock_opt Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, value
    end

    def set_ttl
      value = [@ttl].pack('i')
      set_sock_opt Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, value
      set_sock_opt Socket::IPPROTO_IP, Socket::IP_TTL, value
    end

    def set_reuse_addr
      set_sock_opt Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true
    end

  end

end
