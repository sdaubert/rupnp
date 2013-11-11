module RUPNP

  class EventSubscriber < EM::Connection
    include LogMixin

    attr_reader :response


    def initialize(msg)
      @msg = msg
      @response = EM::Channel.new
    end

    def post_init
      log :debug, "send event subscribe request:\n#@msg"
      send_data @msg
    end

    def receive_data(data)
      log :debug, "receive data from subscribe event action:\n#{data}"
      resp = {}
      io = StringIO.new(data)

      status = io.readline
      status =~ /HTTP\/1\.1 (\d+) (.+)/
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
