module RUPNP

  # Event subscriber to an event's service
  # @author Sylvain Daubert
  class CP::EventSubscriber < EM::Connection
    include LogMixin

    # Response from device
    # @return [EM::Channel]
    attr_reader :response


    # @param [String] msg message to send for subscribing
    def initialize(msg)
      @msg = msg
      @response = EM::Channel.new
    end

    # @return [void]
    def post_init
      log :debug, "send event subscribe request:\n#@msg"
      send_data @msg
    end

    # Receive response from device and send it through {#response}
    # @param [String] data
    # @return [void]
    def receive_data(data)
      log :debug, "receive data from subscribe event action:\n#{data}"
      resp = {}
      io = StringIO.new(data)

      status = io.readline

      if status =~ /HTTP\/1\.1 (\d+) (.+)/
        resp[:status] = $2
        resp[:status_code] = $1

        io.each_line do |line|
          if line =~ /(\w+):\s*(.*)/
            resp[$1.downcase.to_sym] = $2.chomp
          end
        end

        @response << resp
      end
    end

  end

end
