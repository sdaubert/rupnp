
module RUPNP

  class SSDP::Searcher < SSDP::MulticastConnection
    include SSDP::HTTPResponse

    DEFAULT_RESPONSE_WAIT_TIME = 5
    DEFAULT_M_SEARCH_TRY = 2

    attr_reader :discovery_responses


    def initialize(options={})
      options[:response_wait_time] ||= DEFAULT_RESPONSE_WAIT_TIME
      @m_search = SSDP::M_Search.new(options[:search_target],
                                     options[:response_wait_time]).to_s
      @m_search_count = options[:try_number] || DEFAULT_M_SEARCH_TRY
      @discovery_responses = EM::Channel.new

      super options[:ttl]
    end

    def post_init
      @m_search_count.times do
        send_datagram @m_search, MULTICAST_IP, DISCOVERY_PORT
        puts "send datagram:\n#{@m_search}"
      end
    end

    def receive_data(data)
      port, ip = peer_info
      puts "Response from #{ip}:#{port}"

      response = StringIO.new(data)
      if !is_http_status_ok?(response)
        puts "bad HTTP response:\n #{data}"
        return
      end

      @discovery_responses << get_http_headers(response)
    end

  end
end
