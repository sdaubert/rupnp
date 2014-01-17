require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

$:.unshift '../lib'
require 'rupnp'
require 'em-spec/rspec'
require 'webmock/rspec'

RUPNP.log_level = :failure


class FakeMulticast < RUPNP::SSDP::MulticastConnection
  attr_reader :handshake_response, :packets

  def onclose(&blk); @onclose = blk; end
  def onmessage(&blk); @onmessage = blk; end

  def initialize
    @packets = []
  end

  def receive_data(data)
      @onmessage.call(data) if defined? @onmessage
      @packets << data
  end

  def unbind
    @onclose.call if defined? @onclose
  end

end


def generate_search_responder(uuid, port)
  responder = EM.open_datagram_socket(RUPNP::MULTICAST_IP,
                                      RUPNP::DISCOVERY_PORT,
                                      FakeMulticast)
  responder.onmessage do |data|
    data =~ /ST: (.*)\r\n/
    target = $1
    response =<<EOR
HTTP/1.1 200 OK\r
CACHE-CONTROL: max-age = 1800\r
DATE: #{Time.now}\r
EXT:\r
LOCATION: http://127.0.0.1:#{port}\r
SERVER: OS/1.0 UPnP/1.1 Test/1.0\r
ST: #{target}\r
USN: uuid:#{uuid}::upnp:rootdevice\r
BOOTID.UPNP.ORG: 1\r
CONFIGID.UPNP.ORG: 1\r
\r
EOR
    responder.send_data response
  end
end


def generate_xml_device_description(uuid, options={})
  opt = {
    :version_major => 1,
    :version_minor => 1,
  }.merge(options)

  <<EOD
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0" configId="1">
  <specVersion>
    <major>1</major>
    <minor>1</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:Base:1-0</deviceType>
    <friendlyName>Friendly name</friendlyName>
    <manufacturer>RUPNP</manufacturer>
    <modelName>Model name</modelName>
    <UDN>uuid:#{uuid}</UDN>
  </device>
</root>
EOD
end


NOTIFY_REGEX = {
  :common => [
              /^NOTIFY \* HTTP\/1.1\r\n/,
              /HOST: 239\.255\.255\.250:1900\r\n/,
              /NT: [0-9A-Za-z:-]+\r\n/,
              /USN: uuid:(.*)\r\n/,
              /BOOTID.UPNP.ORG: \d+\r\n/,
              /CONFIGID.UPNP.ORG: \d+\r\n/,
             ].freeze,
  :alive => [
             /CACHE-CONTROL:\s+max-age\s+=\s+\d+\r\n/,
             /LOCATION: http:\/\/(.*)\r\n/,
             /NTS: ssdp:alive\r\n/,
             /SERVER: (.*)\r\n/,
            ].freeze,
  :byebye => [
              /NTS: ssdp:byebye\r\n/,
             ].freeze,
  :update => [
              /LOCATION: http:\/\/(.*)\r\n/,
              /NTS: ssdp:update\r\n/,
              /NEXTBOOTID.UPNP.ORG: \d+\r\n/,
             ].freeze
}

RSpec::Matchers.define :be_a_notify_packet do |type|
  match do |packet|
    success = NOTIFY_REGEX[:common].all? { |r| packet.match(r) }
    success &&= NOTIFY_REGEX[type].all? { |r| packet.match(r) }
    success && packet[-4..-1] == "\r\n\r\n"
  end
end


SEARCH_REGEX = [/^M-SEARCH \* HTTP\/1\.1\r\n/,
                /HOST: 239\.255\.255\.250:1900\r\n/,
                /MAN:\s+"ssdp:discover"\r\n/,
                /MX:\s+\d+\r\n/,
                /ST:\s+(ssdp:all|upnp:rootdevice|uuid:.+|urn:[\w:-]+)\r\n/,
               ].freeze

RSpec::Matchers.define :be_a_msearch_packet do
  match do |packet|
    success = SEARCH_REGEX.all? { |r| packet.match(r) }
    success && packet[-4..-1] == "\r\n\r\n"
  end
end

