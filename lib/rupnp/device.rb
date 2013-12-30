require 'uuid'

module RUPNP

  # Error when initializing device. Raised when a required configuration item
  # is missing.
  class DeviceInitializationError < Error
    def message() 'Not all required configuration items are set'; end
  end


  # UPnP device class. This is a main point to create a UPnP device.
  #
  # @note This implementation does not support embedded devices. A device is
  #   only a root.
  # @author Sylvain Daubert
  class Device

    # UUID for this device
    # @return [String]
    attr_reader :uuid
    # Configuration number for this device
    # @return [Fixnum]
    attr_reader :config_id
    # List of services
    # @return [Array]
    attr_reader :services


    # Configuration options for {#initialize}.
    #
    # Each item has an attribute accessor.
    # * Mandatory items:
    #   * +:device_type+: device type as defined by UPnP Forum;
    #   * +:type_version+: device type version;
    #   * +:friendly_name+: short description for end user;
    #   * +:manufacturer+: manufacturer name;
    #   * +:model_name+: model name;
    #   * +:ip+: device's IP address;
    #   * +:port+: device's port to listen to for requests;
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
                    :model_name, :ip, :port, :notify_interval],
      :optional => [:manufacturer_url, :model_description, :model_number,
                    :model_url, :serial_number, :upc, :presentation_url, :uuid,
                    :renew_advertisement, :boot_id, :u_search_port],
    }


    # @param [Hash] config configuration options
    def initialize(config={})
      @config_id = 1
      @icons = []
      @services = []

      unless CONFIG[:required].all? { |key| config.has_key? key }
        raise DeviceInitializationError
      end

      CONFIG[:required].each do |key|
        instance_variable_set "@#{key}".to_sym, config[key]
        define_attr_accessor_on key
      end
      CONFIG[:optional].each do |key|
        instance_variable_set "@#{key}".to_sym, config[key]
        define_attr_accessor_on key unless key == :uuid
      end

      @uuid ||= UUID.generate
      @renew_advertisement ||= 1800
      @boot_id ||= 1
      @u_search_port ||= DISCOVERY_PORT
    end


    # Start device.
    # Send notifications on network and wait for requests.
    # @return [void]
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

    # Send byebye notifications then stop device.
    # @return [void]
    def stop
      notify :byebye
      stop_ssdp_server

      sleep 2
      stop_http_server
    end

    # When device configuration is updated, control points must be notified.
    # Execute this method when :
    # * root device description changed ;
    # * at least one service description changed.
    # @return [void]
    def update_config
      @config_id = (@config_id + 1) % 2**24
      stop_ssdp_server
      notify :alive
    end

    # Get device URN
    # @return [String]
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
      if @xml_description
        @xml_descritpion
      else
        @xml_description = <<EOX
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0" configId="#@config_id">
<specVersion>
<major>1</major>
<minor>1</minor>
</specVersion>
<device>
<deviceType>urn:schemas-upnp-org:device:#@device_type:#@type_version</deviceType>
<friendlyName>#@friendly_name</friendlyName>
<manufacturer>#@manufacturer</manufacturer>
<manufacturerURL>URL to manufacturer site</manufacturerURL>
<modelName>model name</modelName>
<UDN>uuid:UUID</UDN>
EOX
        if @model_description
          @xml_description << "<modelDescription>#@model_description</modelDescription>\n"
        end
        if @model_number
          @xml_description << "<modelNumber>#@model_number</modelNumber>\n"
        end
        if @model_url
          @xml_description << "<modelURL>#@model_url</modelURL>\n"
        end
        if @model_site
          @xml_description << "<modelURL>#@model_site</modelURL>\n"
        end
        if @serial_number
          @xml_description << "<serialNumber>#@serial_number</serialNumber>\n"
        end
        if @upc
          @xml_description << "<UPC>#@upc</UPC>\n"
        end
        if @icons
        end
        if @services
        end
        if @presentation_url
          @xml_description << "<presentationURL>#@presentation_url</presentationURL>\n"
        end
        @xml_description << "</device>\n</root>\n"
      end
    end

    def start_ssdp_server
      options = {
        max_age: @notify_interval, ip: @ip, port: @port,
        boot_id: @boot_id, config_id: @config_id,
        u_search_port: @u_search_port
      }

      @mssdp = EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                                       SSDP::MSearchResponder, self, options)
      @ussdp = EM.open_datagram_socket(@ip, @u_search_port,
                                       SSDP::USearchResponder, self, options)
    end

    def stop_ssdp_server
      @mssdp.close_connection
      @ussdp.close_connection
    end

    def start_http_server
    end

    def stop_http_server
    end

    def notify(subtype)
      options = {
        max_age: @notify_interval,
        ip: @ip,
        port: @port,
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
