module RUPNP

  class Event < EM::Channel

    attr_reader :sid

    def initialize(sid, timeout)
      @sid, @timeout = sid, timeout

      @timeout_timer = EM.add_timer(@timeout) { self << :timeout }
    end

    def renew_subscription
      raise NotImplementedError
    end

    def cancel_subscription
      raise NotImplementedError
    end

  end

end
