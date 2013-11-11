require 'socket'

module RUPNP

  MULTICAST_IP = '239.255.255.250'.freeze
  DISCOVERY_PORT = 1900
  DEFAULT_TTL = 2

  UPNP_VERSION = '1.1'.freeze

  USER_AGENT = `uname -s`.chomp + "/#{`uname -r `.chomp.gsub(/-.*/, '')} " +
    "UPnP/#{UPNP_VERSION} rupnp/#{VERSION}".freeze

  HOST_IP = Socket.ip_address_list.
    find_all { |ai| ai.ipv4? && !ai.ipv4_loopback? }.last.ip_address.freeze

  EVENT_SUB_DEFAULT_PORT = 8080
  EVENT_SUB_DEFAULT_TIMEOUT = 30 * 60

end
