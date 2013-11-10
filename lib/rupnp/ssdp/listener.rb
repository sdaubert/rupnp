module RUPNP

  class SSDP::Listener < SSDP::MulticastConnection

    attr_reader :notifications

    def initialize(options={})
      @notifications = EM::Channel.new

      super options[:ttl]
    end

    def receive_data(data)
    end

  end

end
