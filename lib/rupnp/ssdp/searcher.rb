
module RUPNP

  # Searcher class for searching devices
  # @author Sylvain Daubert
  class SSDP::Searcher < SSDP::MulticastConnection
    include SSDP::HTTP

    # Number of SEARCH datagrams to send
    DEFAULT_M_SEARCH_TRY = 2

    # Channel to receive discovery responses
    # @return [EM::Channel]
    attr_reader :discovery_responses


    # @param [Hash] options
    # @option options [Integer] :response_wait_time
    # @option options [Integer] :try_number
    # @option options [Integer] :ttl
    def initialize(options={})
      @m_search = SSDP::M_Search.new(options[:search_target],
                                     options[:response_wait_time]).to_s
      @m_search_count = options[:try_number] || DEFAULT_M_SEARCH_TRY
      @discovery_responses = EM::Channel.new

      super options[:ttl]
    end

    # @private
    def post_init
      @m_search_count.times do
        send_datagram @m_search, MULTICAST_IP, DISCOVERY_PORT
        log :debug, "send datagram:\n#{@m_search}"
      end
    end

    # @private
    def receive_data(data)
      port, ip = peer_info
      log :debug, "Response from #{ip}:#{port}"

      response = StringIO.new(data)
      if !is_http_status_ok?(response)
        log :error, "bad HTTP response:\n #{data}"
        return
      end

      @discovery_responses << get_http_headers(response)
    end

  end
end
