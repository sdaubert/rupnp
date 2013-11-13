require 'socket'

module RUPNP

  # Multicast IP for UPnP
  MULTICAST_IP = '239.255.255.250'.freeze

  # Default port for UPnP
  DISCOVERY_PORT = 1900

  # Default TTL for UPnP
  DEFAULT_TTL = 2

  # UPnP version
  UPNP_VERSION = '1.1'.freeze

  # User agent for UPnP messages
  USER_AGENT = `uname -s`.chomp + "/#{`uname -r `.chomp.gsub(/-.*/, '')} " +
    "UPnP/#{UPNP_VERSION} rupnp/#{VERSION}".freeze

  # Host IP
  HOST_IP = Socket.ip_address_list.
    find_all { |ai| ai.ipv4? && !ai.ipv4_loopback? }.last.ip_address.freeze

  # Default port for listening for events
  EVENT_SUB_DEFAULT_PORT = 8080

  # Default timeout for event subscription (in seconds)
  EVENT_SUB_DEFAULT_TIMEOUT = 30 * 60

end
