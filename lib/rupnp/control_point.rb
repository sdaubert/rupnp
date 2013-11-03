module RUPNP

  class ControlPoint

    def initialize(search_target, search_options={})
      @search_target = search_target
      @search_options = search_options
      @devices = []
      @new_device_channel = EM::Channel.new
      @bye_device_channel = EM::Channel.new
    end

    def start
      search_devices_and_listen @search_target, @search_options
      yield @new_device_channel, @bye_device_channel
    end

    def create_device(notification)
      device = Device.new(notification)

      device.errback do |device, message|
        puts message
      end

      device.callback do |device|
        add_device device
      end

      device.fetch
    end

    def search_devices_and_listen(target, options)
      searcher = SSDP.search(target, options)

      puts "read notifications"
      searcher.discovery_responses.subscribe do |notification|
        create_device notification
      end
    end
  end


  def add_device(device)
    @devices << device
  end

end
