module RUPNP

  # Listener class for listening for devices' notifications
  # @author Sylvain Daubert
  class SSDP::Listener < SSDP::MulticastConnection
    include SSDP::HTTP

    # Channel to receive notifications
    # @return [EM::Channel]
    attr_reader :notifications

    # @param [Hash] options
    # @option options [Integer] :ttl
    def initialize(options={})
      @notifications = EM::Channel.new

      super options[:ttl]
    end

    # @private
    def receive_data(data)
      port, ip = peer_info
      log :info, "Receive notification from #{ip}:#{port}"
      log :debug, data

      io = StringIO.new(data)
      h = get_http_verb(io)

      if h.nil?
        log :warn, "No HTTP command"
        return
      elsif h[:verb] == 'M-SEARCH'
        return
      elsif !(h[:verb].upcase == 'NOTIFY' and h[:path] == '*' and
              h[:http_version] == '1.1')
        log :warn, "Unknown HTTP command: #{h[:cmd]}"
        return
      end

      @notifications << get_http_headers(io)
    end

  end

end
