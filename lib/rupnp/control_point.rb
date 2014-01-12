module RUPNP

  # This class is the base one for control points (clients in UPnP
  # terminology).
  #
  # To create a control point :
  #   EM.run do
  #     cp = RUPNP::ControlPoint.new(:root)
  #     cp.start do |new_devices, disappeared_devices|
  #       new_devices.subscribe do |device|
  #         puts "New device: #{device.udn}"
  #       end
  #     end
  #   end
  # @author Sylvain Daubert
  class ControlPoint
    include LogMixin
    include Tools

    # Default response wait time for searching devices. This is set
    # to the maximum value from UPnP 1.1 specification.
    DEFAULT_RESPONSE_WAIT_TIME = 5

    # Get event listening port
    # @return [Integer]
    attr_reader :event_port
    # Return channel to add event URL (URL to listen for a specific
    # event)
    # @return [EM::Channel]
    attr_reader :add_event_url
    # Return remote devices controlled by this control point
    # @return [Array<CP::RemoteDevice>]
    attr_reader :devices


    # @param [Symbol,String] search_target target to search for.
    #  May be +:all+, +:root+ or a device identifier
    # @param [Hash] search_options
    # @option search_options [Integer] :response_wait_time time to wait
    #  for responses from devices
    # @option search_options [Integer] :try_number number or search
    #  requests to send (specification says that 2 is a minimum)
    def initialize(search_target, search_options={})
      @search_target = search_target
      @search_options = search_options
      @search_options[:response_wait_time] ||= DEFAULT_RESPONSE_WAIT_TIME

      @devices = []
      @new_device_channel = EM::Channel.new
      @bye_device_channel = EM::Channel.new
    end

    # Start control point.
    # This methos starts a search for devices. Then, listening is
    # performed for device notifications.
    # @yieldparam new_device_channel [EM::Channel]
    #  channel on which new devices are announced
    # @yieldparam bye_device_channel [EM::Channel]
    #  channel on which +byebye+ device notifications are announced
    # @return [void]
    def start
      search_devices_and_listen @search_target, @search_options
      yield @new_device_channel, @bye_device_channel if block_given?
    end

    # Start a search for devices. No listen for update is made.
    #
    # Found devices are accessible through {#devices}.
    # @return [void]
    def search_only
      options = @search_options.dup
      options[:search_only] = true
      search_devices_and_listen @search_target, options
    end

    # Start event server for listening for device events
    # @param [Integer] port port to listen for
    # @return [void]
    def start_event_server(port=EVENT_SUB_DEFAULT_PORT)
      @event_port ||= port
      @add_event_url ||= EM::Channel.new
      @event_server ||= EM.start_server('0.0.0.0', port, CP::EventServer,
                                        @add_event_url)
    end

    # Stop event server
    # @see #start_event_server
    # @return [void]
    def stop_event_server
      @event_port = nil
      EM.stop_server @event_server
      @event_server = nil
    end

    # Add a device to the control point
    # @param [Device] device device to add
    # @return [void]
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


    # Find a device from control point's device list by its UDN
    # @param [String] udn
    # @return [Device,nil]
    def find_device_by_udn(udn)
      @devices.find { |d| d.udn == udn }
    end


    private

    def search_devices_and_listen(target, options)
      log :info, 'search for devices'
      searcher = SSDP.search(target, options)

      EM.add_timer(@search_options[:response_wait_time] + 1) do
        log :info, 'search timeout'
        searcher.close_connection

        unless options[:search_only]
          log :info, 'now listening for device advertisement'
          listener = SSDP.listen

          listener.notifications.subscribe do |notification|
            case notification['nts']
            when 'ssdp:alive'
              create_device notification
            when 'ssdp:byebye'
              udn = usn2udn(notification['usn'])
              log :info, "byebye notification sent by device #{udn}"
              rejected = @devices.reject! { |d| d.udn == udn }
              log :info, "#{rejected.udn} device removed" if rejected
            else
              log :warn, "Unknown notification type: #{notification['nts']}"
            end
          end
        end
      end

      searcher.discovery_responses.subscribe do |notification|
        log :debug, 'receive a notification'
        create_device notification
      end
    end

    def create_device(notification)
      device = CP::RemoteDevice.new(self, notification)

      device.errback do |device, message|
        log :warn, message
      end

      device.callback do |device|
        add_device device
      end

      device.fetch
    end

    def has_already_device?(dev)
      @devices.any? { |d| d.udn == dev.udn || d.usn == dev.usn }
    end

  end

end
