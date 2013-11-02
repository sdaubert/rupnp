
module Upnp

  class SSDP::M_Search < SSDP::GenericRequest

    REQUEST = 'M-SEARCH'

    def initialize(search_target, response_wait_time)
      os = `uname -s`.chomp
      os = `uname -s`.chomp + '/' + `uname -r`.chomp.gsub(/-.*/, '')
      headers = {
        'HOST' => MULTICAST_IP,
        'MAN'  => '"ssdp:discover"',
        'MX'   => response_wait_time.to_s,
        'ST'   => search_target,
        'USER-AGENT' =>  "#{os} UPnp/1.1 rupnp/#{VERSION}"
      }
      super '*', headers
      end

  end

end
