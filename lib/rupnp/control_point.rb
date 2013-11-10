module RUPNP

  class ControlPoint
    include LogMixin

    DEFAULT_RESPONSE_WAIT_TIME = 5


    def initialize(search_target, search_options={})
      @search_target = search_target
      @search_options = search_options
      @search_options[:response_wait_time] ||= DEFAULT_RESPONSE_WAIT_TIME

      @devices = []
      @new_device_channel = EM::Channel.new
      @bye_device_channel = EM::Channel.new
    end

    def start
      search_devices_and_listen @search_target, @search_options
      yield @new_device_channel, @bye_device_channel
    end

    def add_device(device)
      if has_already_device?(device)
       log :info, "Device already in database: #{device}"
      else
        log :info, "adding device #{device.udn}"
        @devices << device
        @new_device_channel << device
      end
    end

    def create_device(notification)
      device = Device.new(notification)

      device.errback do |device, message|
        log :warn, message
      end

      device.callback do |device|
        add_device device
      end

      device.fetch
    end

    def search_devices_and_listen(target, options)
      log :info, 'search for devices'
      searcher = SSDP.search(target, options)

      EM.add_timer(@search_options[:response_wait_time] + 1) do
        log :info, 'search timeout'
        searcher.close_connection

        log :info, 'now listening for device advertisement'
        listener = SSDP.listen
      end

      searcher.discovery_responses.subscribe do |notification|
        log :debug, 'receive a notification'
        create_device notification
      end
    end


    private

    def has_already_device?(dev)
      @devices.any? { |d| d.udn == dev.udn || d.usn == dev.usn }
    end

  end

end
