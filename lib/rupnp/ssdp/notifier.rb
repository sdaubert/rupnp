
module RUPNP

  # Searcher class for searching devices
  # @author Sylvain Daubert
  class SSDP::Notifier < SSDP::MulticastConnection
    include SSDP::HTTP

    # Number of SEARCH datagrams to send
    DEFAULT_NOTIFY_TRY = 2

    # @param [Hash] options
    # @option options [Integer] :try_number
    # @option options [Integer] :ttl
    # @option options [String] :ip
    def initialize(type, subtype, options={})
      @type = (type == :root) ? 'upnp:rootdevice' : type
      @subtype = subtype
      @notify_count = options.delete[:try_number] || DEFAULT_M_SEARCH_TRY
      @options = options

      super options.delete[:ttl]
    end

    # @private
    def post_init
      notify = notify_request
      @notify_count.times do
        send_datagram notify, MULTICAST_IP, DISCOVERY_PORT
        log :debug, "send datagram:\n#{notify}"
      end
      close_connection_after_writing
    end

    # @private
    def receive_data(data)
    end


    private

    def notify_request
      usn = if @type[0..3] == 'uuid'
              @type
            else
              "uuid:#{@options[:uuid]}::#@type"
            end
      case subtype
      when :alive
      <<EOD
NOTIFY * HTTP/1.1\r
HOST: #{MULTICAST_IP}:#{DISCOVERY_PORT}\r
CACHE-CONTROL: max-age = #{@options[:max_age]}\r
LOCATION: http://#{options[:ip]}/root_description.xml\r
NT: #@type\r
NTS: ssdp:#@subtype\r
SERVER: #{USER_AGENT}\r
USN: #{usn}\r
BOOTID.UPNP.ORG: #{@options[:boot_id]}\r
CONFIGID.UPNP.ORG: #{@options[:config_id]}\r
SEARCHPORT.UPNP.ORG: #{@options[:u_search_port]}\r
\r
EOD
      when :byebye
      <<EOD
NOTIFY * HTTP/1.1\r
HOST: #{MULTICAST_IP}:#{DISCOVERY_PORT}\r
NT: #@type\r
NTS: ssdp:#@subtype\r
USN: #{usn}\r
BOOTID.UPNP.ORG: #{@options[:boot_id]}\r
CONFIGID.UPNP.ORG: #{@options[:config_id]}\r
\r
EOD
      when :update
      <<EOD
NOTIFY * HTTP/1.1\r
HOST: #{MULTICAST_IP}:#{DISCOVERY_PORT}\r
LOCATION: http://#{options[:ip]}/root_description.xml\r
NT: #@type\r
NTS: ssdp:#@subtype\r
USN: #{usn}\r
BOOTID.UPNP.ORG: #{(@options[:boot_id] - 1) % 2**31}\r
CONFIGID.UPNP.ORG: #{@options[:config_id]}\r
NEXTBOOTID.UPNP.ORG: #{@options[:boot_id]}\r
SEARCHPORT.UPNP.ORG: #{@options[:u_search_port]}\r
\r
EOD
      end
    end

  end
end
