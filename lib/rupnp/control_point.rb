module RUPNP

  class ControlPoint
    include LogMixin

    DEFAULT_RESPONSE_WAIT_TIME = 5

    attr_reader :event_port
    attr_reader :add_event_url
    attr_reader :event


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

    def start_event_server(port=EVENT_SUB_DEFAULT_PORT)
      @event_port = port
      @add_event_url = EM::Channel.new
      @event_server ||= EM.start_server('0.0.0.0', port, EventServer,
                                        @add_event_url)
    end

    def stop_event_server
      EM.stop_server @event_server
    end

    def add_device(device)
      if has_already_device?(device)
       log :info, "Device already in database: #{device.udn}"
        existing_device = self.find_device_by_udn(device.udn)
        if existing_device.expiration < device.expiration
          log :info, 'update expiration time for device #{device.udn}'
          @devices.delete existing_device
          @devices << device
        end
      else
        log :info, "adding device #{device.udn}"
        @devices << device
        @new_device_channel << device
      end
    end

    def create_device(notification)
      device = Device.new(self, notification)

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

        listener.notifications.subscribe do |notification|
          case notification[:nts]
          when 'ssdp:alive'
            create_device notification
          when 'ssdp:byebye'
            log :info, "byebye notification sent by device #{notification[:udn]}"
            @devices.reject! { |d| d.usn == notification[:usn] }
          else
            log :warn, "Unknown notification type: #{notification[:nts]}"
          end
        end
      end

      searcher.discovery_responses.subscribe do |notification|
        log :debug, 'receive a notification'
        create_device notification
      end
    end

    def find_device_by_udn(udn)
      @devices.find { |d| d.udn == udn }
    end


    private

    def has_already_device?(dev)
      @devices.any? { |d| d.udn == dev.udn || d.usn == dev.usn }
    end

  end

end
