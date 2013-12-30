$:.unshift '../lib'
require 'rupnp'


class FakeCP < EM::Connection
  attr_reader :handshake_response, :packets

  def onopen(&blk); @onopen = blk; end
  def onclose(&blk); @onclose = blk; end
  def onerror(&blk); @onerror = blk; end
  def onmessage(&blk); @onmessage = blk; end

  def initialize
    @state = :new
    @packets = []
  end

  def receive_data(data)
    # puts "RECEIVE DATA #{data}"
    if @state == :new
      @handshake_response = data
      @onopen.call if defined? @onopen
      @state = :open
    else
      @onmessage.call(data) if defined? @onmessage
      @packets << data
    end
  end

  def unbind
    @onclose.call if defined? @onclose
  end

end

