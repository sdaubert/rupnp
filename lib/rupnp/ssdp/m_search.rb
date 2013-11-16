
module RUPNP

  # SEARCH HTTPU request
  class SSDP::M_Search < SSDP::GenericRequest

    # @private
    REQUEST = 'M-SEARCH'

    # @param [Symbol,String] search_target
    # @param [Integer] response_wait_time
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
