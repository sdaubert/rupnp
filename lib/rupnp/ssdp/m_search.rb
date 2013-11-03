
module RUPNP

  class SSDP::M_Search < SSDP::GenericRequest

    REQUEST = 'M-SEARCH'

    def initialize(search_target, response_wait_time)
      headers = {
        'HOST' => MULTICAST_IP,
        'MAN'  => '"ssdp:discover"',
        'MX'   => response_wait_time.to_s,
        'ST'   => search_target,
        'USER-AGENT' =>  RUPNP::USER_AGENT
      }
      super '*', headers
      end

  end

end
