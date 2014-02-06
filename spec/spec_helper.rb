require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

$:.unshift '../lib'
require 'rupnp'
require 'em-spec/rspec'
require 'webmock/rspec'

RUPNP.log_level = :failure

WebMock.disable_net_connect!(allow_localhost: true)

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


def generate_device_description(uuid, options={})
  opt = {
    :version_major => 1,
    :version_minor => 1,
    :device_type => :base,
  }.merge(options)

  desc=<<EOD
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0" configId="23">
  <specVersion>
    <major>#{opt[:version_major]}</major>
    <minor>#{opt[:version_minor]}</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:#{opt[:device_type].capitalize}:1-0</deviceType>
    <friendlyName>Friendly name</friendlyName>
    <manufacturer>RUPNP</manufacturer>
    <modelName>Model name</modelName>
    <UDN>uuid:#{uuid}</UDN>
EOD
  if opt[:device_type] != :base
    desc << <<EOD
    <serviceList>
      <service>
        <serviceType>usrn:schemas-upnp-org:service:ContentDirectory:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:ContentDirectory</serviceId>
        <SCPDURL>/cd/description.xml</SCPDURL>
        <ControlURL>/cd/control</ControlURL>
        <EventURL></EventURL>
      </service>
    </serviceList>
EOD
  end
  desc << "  </device>\n</root>\n"
end


def generate_scpd(options={})
  opt = {
    :version_major => 1,
    :version_minor => 1,
    :nb_state_var => 1,
    :define_action => false,
    :send_event => false
  }.merge(options)

  scpd=<<EOD
<?xml version="1.0"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0" configId="23">
  <specVersion>
    <major>#{opt[:version_major]}</major>
    <minor>#{opt[:version_minor]}</minor>
  </specVersion>
EOD

  if opt[:define_action]
    scpd << <<EOAL
  <actionList>
    <action>
      <name>testAction</name>
      <argumentList>
        <argument>
          <name>var1</name>
          <direction>in</direction>
          <relatedStateVariable>X_variableName1</relatedStateVariable>
        </argument>
        <argument>
          <name>var2</name>
          <direction>out</direction>
          <retval/>
          <relatedStateVariable>X_variableName2</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
  </actionList>
EOAL
  end

  scpd << '  <serviceStateTable>'
  opt[:nb_state_var].times do |i|
    scpd << <<EOSV
    <stateVariable sendEvents="#{opt[:send_event] ? 'yes' : 'no'}">
      <name>X_variableName#{i+1}</name>
      <dataType>ui4</dataType>
      <defaultValue>#{i}</defaultValue>
      <allowedValueRange>
        <minimum>0</minimum>
        <maximum>#{64*(i+1) - 1}</maximum>
      </allowedValueRange>
    </stateVariable>
EOSV
  end
  scpd << "  </serviceStateTable>\n</scpd>\n"
end


def action_response(hash)
  r = <<EOD
<?xml version="1.0"?>
<s:Envelope
 xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
 s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:testActionResponse xmlns:u="urn:schemas-upnp-org:service:service:1">
EOD

  hash.each { |k, v| r << "      <#{k}>#{v}</#{k}>\n"}

  r << <<EOD
    </u:testActionResponse>
  </s:Body>
</s:Envelope>
EOD
end


def event_body
  <<EOD
<?xml version="1.0"?>
<e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
<e:property>
<variableName>12</variableName>
</e:property>
</e:propertyset>
EOD
end


def send_notify_request(req, options={})
  delete = options.delete(:delete)
  headers = {
    'HOST' => "127.0.0.1:1234",
    'USER-AGENT' => RUPNP::USER_AGENT,
    'CONTENT-TYPE' => 'text/xml; charset="utf-8"',
    'NT' => 'upnp:event',
    'NTS' => 'upnp:propchange',
    'SID' => "uuid:#{UUID.generate}",
    'SEQ' => 0 }.merge(options)
  headers.delete delete if delete

  req.setup_request(:notify, :head => headers, :body => event_body)
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

