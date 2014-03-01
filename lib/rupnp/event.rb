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
    # @param [Hash] options
    # @option options [Boolean] :auto_renew If true, automatically renew
    #   subscription before timeout. If false, a message +:timeout+ is
    #   sent throught +self+. (default: +true+)
    # @option options [Integer] :before_timeout number of seconds before
    #   timeout to renew subscription or send +:timeout+ message.
    #   (default: 60)
    def initialize(event_suburl, callback_url, sid, timeout, options={})
      super()
      @event_suburl = event_suburl
      @callback_url = callback_url
      @sid, @timeout = sid, timeout
      @options = {
        :auto_renew => true,
        :before_timeout => 60,
      }.merge(options)

      set_timer
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


    private

    def set_timer
      if @options[:auto_renew]
        blk = Proc.new { renew_subscription }
      else
        blk =  Proc.new { self << :timeout }
      end

      time = @timeout - @options[:before_timeout].to_i
      @timeout_timer = EM.add_timer(time, &blk)
    end

  end

end
