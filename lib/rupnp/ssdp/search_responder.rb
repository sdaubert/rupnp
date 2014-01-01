module RUPNP

  # M-SEARCH responder for M-SEARCH multicast requests from control points.
  # @author Sylvain Daubert
  module SSDP::SearchResponder
    include SSDP::HTTP

    def receive_data(data)
      port, ip = peer_info
      log :debug,  "#{self.class}: Receive data from #{ip}:#{port}"
      log :debug, data

      io = StringIO.new(data)
      h = get_http_verb(io)

      if h[:verb].upcase == 'NOTIFY'
        return
      end

      if h.nil? or !(h[:verb].upcase == 'M-SEARCH' and h[:path] == '*' and
                       h[:http_version] == '1.1')
        log :warn, "#{self.class}: Unknown HTTP command: #{h[:cmd]}"
        return
      end

      h = get_http_headers(io)
      if h['man'] != '"ssdp:discover"'
        log :warn, "#{self.class}: Unknown MAN field: #{h['man']}"
        return
      end

      log :info, "#{self.class}: Receive M-SEARCH request from #{ip}:#{port}"

      callback = nil
      case h['st']
      when 'ssdp:all'
        callback = Proc.new do
          send_response 'upnp:rootdevice'
          send_response "uuid:#{@device.uuid}"
          send_response "urn:#{@device.urn}"
          @device.services.each do |s|
            send_response "urn:#{s.urn}"
          end
        end
      when 'upnp:rootdevice'
        callback = Proc.new { send_response 'upnp:rootdevice' }
      when /^uuid:([0-9a-fA-F-]+)/
         if $1 and $1 == @device.uuid
           callback = Proc.new { send_response "uuid:#{@device.uuid}" }
         end
      when /^urn:schemas-upnp-org:(\w+):(\w+):(\w+)/
        case $1
        when 'device'
          if urn_are_equivalent?(h['st'], @device.urn)
            callback = Proc.new { send_response "urn:#{@device.urn}" }
          end
        when 'service'
          if @device.services.one? { |s| urn_are_equivalent? h['st'], s.urn }
            callback = Proc.new { send_response h['st'] }
          end
        end
      end

      if callback
        if self.is_a? SSDP::MulticastConnection
          if h['mx']
            mx = h['mx'].to_i
            # MX MUST not be greater than 5
            mx = 5 if mx > 5
            # Wait for a random time less than MX
            wait_time = rand(mx)
            EM.add_timer wait_time, &callback
          else
            log :warn, "#{self.class}: Multicast M-SEARCH request with no MX" +
              " field. Discarded."
          end
        else
          # Unicast request. Don't bother for MX field.
          callback.call
        end
      else
        log :debug, 'No response sent'
      end
    end


    def send_response(st)
      usn = "uuid:#{@device.uuid}"
      usn += case st
             when 'upnp:rootdevice', /^urn/
               "::#{st}"
             else
               ''
             end
      response =<<EOR
HTTP/1.1 200 OK\r
CACHE-CONTROL: max-age = #{@options[:max_age]}\r
DATE: #{Time.now.httpdate}\r
EXT:\r
LOCATION:  http://#{@options[:ip]}/root_description.xml\r
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
