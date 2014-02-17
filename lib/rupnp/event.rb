module RUPNP

  # Event class to handle events from devices
  # @todo Renewal and cancellation of subscription are not coded
  # @author Sylvain Daubert
  class Event < EM::Channel

    # Get service ID
    # @return [Integer]
    attr_reader :sid
    attr_reader :callback_url

    # @param [String] event_suburl Event subscription URL
    # @param [String] callback_url Callback URL to receive events
    # @param [#to_i] sid
    # @param [Integer] timeout for event (in seconds)
    def initialize(event_suburl, callback_url, sid, timeout)
      super()
      @event_suburl = event_suburl
      @callback_url = callback_url
      @sid, @timeout = sid, timeout

      @timeout_timer = EM.add_timer(@timeout) { self << :timeout }
    end

    # Renew subscription to event
    # @todo
    def renew_subscription
      raise NotImplementedError
    end

    # Cancel subscription to event
    # @todo
    def cancel_subscription
      raise NotImplementedError
    end

  end

end
