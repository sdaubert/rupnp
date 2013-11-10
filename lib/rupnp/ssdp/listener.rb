module RUPNP

  class SSDP::Listener < SSDP::MulticastConnection
    include HTTP

    attr_reader :notifications

    def initialize(options={})
      @notifications = EM::Channel.new

      super options[:ttl]
    end

    def receive_data(data)
      port, ip = peer_info
      log :info, 'Receive notification from #{ip}:#{port}'
      log :debug, data

      io = StringIO.new(data)
      h = get_http_verb(io)

      if h.nil? or !(h[:verb].upcase == 'NOTIFY' and h[:path] == '*' and
                       h[:http_version] == '1.1')
        log :warn, "Unknown HTTP command: #{h[:cmd]}"
        return
      end

      @notifictions << get_http_headers(io)
    end

  end

end
