module RUPNP

  # Listener class for listening for devices' notifications
  # @author Sylvain Daubert
  class SSDP::MSearchResponder < SSDP::MulticastConnection
    include HTTP

    # @param [Hash] options
    # @option options [Integer] :ttl
    def initialize(device, options={})
      @device = device
      @options = options
      super options[:ttl]
    end

    # @private
    def receive_data(data)
      port, ip = peer_info
      log :info, 'Receive M-SEARCH request from #{ip}:#{port}'
      log :debug, data

      io = StringIO.new(data)
      h = get_http_verb(io)

      if h.nil? or !(h[:verb].upcase == 'M-SEARCH' and h[:path] == '*' and
                       h[:http_version] == '1.1')
        log :warn, "Unknown HTTP command: #{h[:cmd]}"
        return
      end

      if h[:man] != '"ssdp:discover"'
        log :warn, "Unknown MAN field: #{h|:man}"
        return
      end

      callback = nil
      case h[:st]
      when 'ssdp:all'
        callback = Proc.new do
          send_response 'upnp:rootdevice'
          send_response "uuid:#{@device.uuid}"
          send_response "urn:#{@device.urn}"
          @devices.services.each do |s|
            send_response "urn:#{s.urn}"
          end
        end
      when 'upnp:rootdevice'
        send_response 'upnp:rootdevice'
      when /^uuid:([0-9a-fA-F-]+)/
         if $1 and $1 == @device.uuid
           callback = Proc.new { send_response "uuid:#{@device.uuid}" }
         end
      when /^urn:schemas-upnp-org:(\w+):(\w+):(\w+)/
        case $1
        when 'device'
          if urn_are_equivalent?(h[:st], @device.urn)
            callback = Proc.new { send_response "urn:#{@device.urn}" }
          end
        when 'service'
          if @device.services.one? { |s| urn_are_equivalent? h[:st], s.urn }
            callback = Proc.new { send_response h[:st] }
          end
        end
      end

      if callback
        if h[:mx]
          # Wait for a random time less than MX
          wait_time = h[:mx].to_i
          # MX MUST not be greater than 5
          wait_time = 5 if wait_time > 5
          EM.add_timer(wait_time, &callback)
        else
          log :warn, "Multicast M-SEARCH request with no MX field. Discarded."
        end
      end
    end


    private

    def send_response(st)
      response <<EOR
HTTP/1.1 200 OK\r
CACHE-CONTROL: max-age = #{@options[:max_age]}\r
DATE: #{Time.now.httpdate}\r
EXT:\r
LOCATION:  http://#{options[:ip]}/root_description.xml\r
SERVER: #{USER_AGENT}\r
ST: #{st}
USN: #{usn}\r
BOOTID.UPNP.ORG: #{@options[:boot_id]}\r
CONFIGID.UPNP.ORG: #{@options[:config_id]}\r
SEARCHPORT.UPNP.ORG: #{@options[:u_search_port]}\r
\r
EOR

      send_data response
    end

  end

end
