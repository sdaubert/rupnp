module RUPNP

  # Error when initializing device. Raised when a required configuration item
  # is missing.
  class DeviceInitializationError < Error
  end


  # UPnP device class. This is a main point to create a UPnP device.
  #
  # @note This implementation does not support embedded devices. A device is
  #   only a root.
  # @author Sylvain Daubert
  class Device

    # UUID for this device
    attr_reader :uuid
    # Configuration number for this device
    attr_reader :config_id
    # List of services
    attr_reader :services


    # Configuration options for {#initialize}.
    #
    # +CONFIG[:required]+ items are mandatory.
    #
    # Each item has an attribute accessor.
    # * Mandatory items:
    #   * +:device_type+: device type as defined by UPnP Forum;
    #   * +:type_version+: device type version;
    #   * +:friendly_name+: short description for end user;
    #   * +:manufacturer+: manufacturer name;
    #   * +:model_name+: model name;
    #   * +:ip+: device's IP address;
    #   * +:notify_interval+: time interval between 2 notifications;
    # * Optional items:
    #   * +:manufacturel_url+: URL to manufacturer's web site;
    #   * +:model_description+: long description for end user;
    #   * +:model_number+: model number;
    #   * +:model_url+: web site for model;
    #   * +:serial_number+: serial number;
    #   * +:upc+: Universal Product Code (UPC) that identifies the
    #     consumer package;
    #   * +:presentation_url+: URL to presentation for device;
    #   * +:uuid+: UUID for device. As UUID MUST be the same each time
    #     device restarts, UUID should be saved in a configuration file.
    #     If UUID is not given, it is automatically generated.
    #   * +:boot_id+: Device boot id. Must be incremented on each device's boot.
    #     If BOOTID is not given, it is set to 1.
    #   * +:u_search_port+: port for listening to unicast M-SEARCH requests.
    CONFIG = {
      :required => [:device_type, :type_version, :friendly_name, :manufacturer,
                    :model_name, :ip, :notify_interval],
      :optional => [:manufacturer_url, :model_description, :model_number,
                    :model_url, :serial_number, :upc, :presentation_url, :uuid,
                    :renew_advertisement, :boot_id, :u_search_port],
    }


    # @param [Hash] config config options
    def initialize(config={})
      @config_id = 1
      @services = []

      unless CONFIG[:required].all? { |key| config.has_key? key }
        raise DeviceInitializationError
      end

      CONFIG[:required].each do |key|
        instance_variable_set "@#{key}".to_sym, CONFIG[:required][key]
        define_attr_accessor_on key
      end
      CONFIG[:optional].each do |key|
        instance_variable_set "@#{key}".to_sym, CONFIG[:optional][key]
        define_attr_accessor_on key unless key == :uuid
      end

      @uuid ||= UUID.generate
      @renew_advertisement ||= 1800
      @bootid ||= 1
      @u_search_port ||= DISCOVERY_PORT
    end


    def start
      # Generate Device Description XML file
      generate_xml_device_description

      # Start server for M-SEARCH request
      start_ssdp_server

      # Start server for HTTP request
      start_http_server

      # Send initial notification
      notify :alive

      # increase BOOTID
      @boot_id = (@boot_id + 1) % 2**31

      # and then set a periodic timer for future notifications
      @notify_timer = EM.add_periodic_timer(@notify_interval) { notify :alive }
    end

    def stop
      notify :byebye
      stop_ssdp_server

      sleep 2
      stop_http_server
    end

    # When device configuration is updated, control points must be notified.
    # Execute this method when :
    # * root device description changed ;
    # * at least one serice description changed.
    def update_config
      @config_id = (@config_id + 1) % 2**24
      notify :alive
    end

    def urn
      "schemas-upnp-org:device:#@device_type:#@type_version"
    end

    private

    def define_attr_accessor_on(iv)
      # Standard reader
      instance_eval "def #{iv}; @#{iv}; end"
      # Standard writer
      instance_eval "def #{iv}=(value); @#{iv} = value; end"
    end

    def generate_xml_device_description
    end

    def start_ssdp_server
    end

    def stop_ssdp_server
    end

    def start_http_server
    end

    def stop_http_server
    end

    def notify(subtype)
      options = {
        max_age: @notify_interval,
        ip: @ip,
        uuid: @uuid,
        boot_id: @boot_id,
        config_id: @config_id,
        u_search_port: @u_search_port,
      }
      SSDP.notify :root, subtype, options
      SSDP.notify "uuid:#@uuid", subtype, options
      SSDP.notify "urn:#{urn}", subtype, options
      @services.each do |service|
        SSDP.notify "urn:#{service.urn}", subtype, options
      end
    end
  end

end
