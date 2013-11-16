module RUPNP

  # Event class to handle events from devices
  # @todo Renewal an cancellation of subscription are not coded
  # @author Sylvain Daubert
  class Event < EM::Channel

    # Get service ID
    # @return [Integer]
    attr_reader :sid

    # @param [#to_i] sid
    # @param [Integer] timeout for event (in seconds)
    def initialize(sid, timeout)
      @sid, @timeout = sid, timeout

      @timeout_timer = EM.add_timer(@timeout) { self << :timeout }
    end

    # Renew subscription to event
    def renew_subscription
      raise NotImplementedError
    end

    # Cancel subscription to event
    def cancel_subscription
      raise NotImplementedError
    end

  end

end
