module RUPNP

  # Event class to handle events from devices
  # @todo Cancellation of subscription are not coded
  #
  # ==Messages
  # {Event} class receives messages. As {Event} is a subclass of
  # EM::Channel, user may subscribe to it to receive these messages:
  #   event.subscribe do |msg|
  #     # use msg
  #   end
  # Possible messages are:
  # * +:timeout+, receive +:before_timeout+ seconds before real time out,
  # * +:renew+ to say to user that automatic renewing occured,
  # * +:cancelled+ to say to user that subscription was cancelled.
  #   Cancellation may occur on demand (see {#cancel_subscription}), or
  #   on error when renewing failed.
  # @author Sylvain Daubert
  class Event < EM::Channel
    include LogMixin

    # Get service ID
    # @return [Integer]
    attr_reader :sid
    # Get callback URL
    # @return [String]
    attr_reader :callback_url
    # Get timeout in seconds
    # @return [Integer]
    attr_reader :timeout

    # @param [String] event_suburl Event subscription URL
    # @param [String] callback_url Callback URL to receive events
    # @param [#to_s] sid
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
      @event_sub_url = event_suburl
      @callback_url = callback_url
      @sid, @timeout = sid, timeout
      @options = {
        :auto_renew => true,
        :before_timeout => 60,
      }.merge(options)

      set_timer
    end

    # Renew subscription to event
    def renew_subscription
      uri = URI(@event_sub_url)
      con = EM::HttpRequest.new(@event_sub_url)
      log :debug, 'Open connection for renewing subscription'
      http = con.setup_request(:subscribe, :head => {
                                 'HOST' => "#{uri.host}:#{uri.port}",
                                 'USER-AGENT' => RUPNP::USER_AGENT,
                                 'SID' => @sid,
                                 'TIMEOUT' => "Second-#@timeout"})
      http.errback do |client|
        log :warn, "Cannot renew subscription to event: #{client.error}"
        con.close
      end

      http.callback do
        log :debug, 'Close connection'
        con.close
        if http.response_header.status != 200
          log :warn, "Cannot renew subscribtion to event #@event_sub_url:" +
            " #{http.response_header.http_reason}"
        else
          @timeout = http.response_header['TIMEOUT'].match(/(\d+)/)[1].to_i ||
            1800
          set_timer
          log :info, "Subscription to #@event_sub_url renewed"
          self << :renewed
        end
      end
    end

    # Cancel subscription to event
    # @todo
    def cancel_subscription
      raise NotImplementedError
    end


    private

    def set_timer
      EM.cancel_timer(@timeout_timer) if @timeout_timer

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
