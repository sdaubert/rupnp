require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

$:.unshift '../lib'
require 'rupnp'
require 'em-spec/rspec'


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


NOTIFY_REGEX = {
  :alive => [/^NOTIFY \* HTTP\/1.1\r\n/,
             /HOST: 239\.255\.255\.250:1900\r\n/,
             /CACHE-CONTROL:\s+max-age\s+=\s+\d+\r\n/,
             /LOCATION: http:\/\/(.*)\r\n/,
             /NT: [0-9A-Za-z:-]+\r\n/,
             /NTS: ssdp:(alive|byebye)\r\n/,
             /SERVER: (.*)\r\n/,
             /USN: uuid:(.*)\r\n/,
             /BOOTID.UPNP.ORG: \d+\r\n/,
             /CONFIGID.UPNP.ORG: \d+\r\n/,
            ].freeze,
  :byebye => [/^NOTIFY \* HTTP\/1.1\r\n/,
             /HOST: 239\.255\.255\.250:1900\r\n/,
             /NT: [0-9A-Za-z:-]+\r\n/,
             /NTS: ssdp:(alive|byebye)\r\n/,
             /USN: uuid:(.*)\r\n/,
             /BOOTID.UPNP.ORG: \d+\r\n/,
             /CONFIGID.UPNP.ORG: \d+\r\n/,
            ].freeze,
}

RSpec::Matchers.define :be_a_notify_packet do |type|
  match do |packet|
    success = NOTIFY_REGEX[type].all? { |r| packet.match(r) }
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
