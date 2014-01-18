require 'nori'
require 'ostruct'


module RUPNP

  # A device is a UPnP service provider.
  # @author Sylvain Daubert.
  class CP::RemoteDevice < CP::Base

    # Number of seconds the advertisement is valid.
    # Used when +ssdp:update+ advertisement is received but no
    # previuous +ssdp:alive+ was received.
    DEFAULT_MAX_AGE = 600

    # Get control point which controls this device
    # @return [ControlPoint]
    attr_reader :control_point

    # Get search target.
    # @return [String]
    attr_reader :st
    # Get Unique Service Name
    # @return [String]
    attr_reader :usn
    # Get SERVER string
    # @return [String]
    attr_reader :server
    # URL to the UPnP description of the root device
    # @return [String]
    attr_reader :location
    # @return [String]
    attr_reader :ext
    # Date when response was generated
    # @return [String]
    attr_reader :date
    # Contains +max-age+ directive used to specify advertisement validity
    # @return [String]
    attr_reader :cache_control
    # Expiration time for the advertisement
    # @return [Time]
    attr_reader :expiration
    # BOOTID.UPNP.ORG field value
    # @return [Integer]
    attr_reader :boot_id
    # CONFIGID.UPNP.ORG field value
    # @return [nil, Integer]
    attr_reader :config_id

    # UPnP version used by the device
    # @return [String]
    attr_reader :upnp_version
    # XML namespace for device description
    # @return [String]
    attr_reader :xmlns
    # URL base for device access
    # @return [String]
    attr_reader :url_base
    # Device type
    # @return [String]
    attr_reader :type
    # Short description for end users
    # @return [String]
    attr_reader :friendly_name
    # Manufacturer's name
    # @return [String]
    attr_reader :manufacturer
    # Web site for manufacturer
    # @return [String]
    attr_reader :manufacturer_url
    # Long decription for end user
    # @return [String]
    attr_reader :model_description
    # Model name
    # @return [String]
    attr_reader :model_name
    # Model number
    # @return [String]
    attr_reader :model_number
    # Web site for model
    # @return [String]
    attr_reader :model_url
    # Serial number
    # @return [String]
    attr_reader :serial_umber
    # Unique Device Name
    # @return [String]
    attr_reader :udn
    # Universal Product Code
    # @return [String]
    attr_reader :upc
    # URL to presentation for device
    # @return [String]
    attr_reader :presentation_url
    # Array of icons to depict device in control point UI
    # @return [Array<OpenStruct>]
    attr_reader :icons
    # List of device's services
    # @return [Array<Service>]
    attr_reader :services
    # List of embedded devices
    # @return [Array<Device>]
    attr_reader :devices


    # @param [ControlPoint] control_point
    # @param [Hash] notification
    def initialize(control_point, notification)
      super()
      @control_point = control_point
      @notification = notification

      @icons = []
      @services = []
      @devices = []
    end

    # Get device from its description
    # @return [void]
    def fetch
      if @notification['nextbootid.upnp.org']
        @boot_id = @notification['nextbootid.upnp.org'].to_i
      elsif @notification['bootid.upnp.org']
        @boot_id = @notification['bootid.upnp.org'].to_i
      else
        fail self, 'no BOOTID.UPNP.ORG field. Message discarded.'
        return
      end
      @config_id = @notification['confgid.upnp.org']
      @config_id = @config_id.to_i if @config_id

      description_getter = EM::DefaultDeferrable.new

      description_getter.errback do
        msg = "Failed getting description"
        log :error, "Fetching device: #{msg}"
        fail self, msg
        next
      end

      extract_from_ssdp_notification description_getter

      description_getter.callback do |description|
        @description = description
      if bad_description?
          fail self, "Bad description returned: #@description"
          next
        else
          extract_url_base
          extract_device_info
          extract_icons

          @services_extracted = @devices_extracted = false
          extract_services
          extract_devices

          tick_loop = EM.tick_loop do
            :stop if @services_extracted and @devices_extracted
          end
          tick_loop.on_stop { succeed self }
        end
      end
    end

    # Update a device from a ssdp:update notification
    # @param [String] notification
    # @return [void]
    def update(notification)
      update_expiration notification
      @boot_id = notification['nextbootid.upnp.org'].to_i
      if notification['configid.upnp.org']
        @config_id = notification['configid.upnp.org'].to_i
      end
    end


    private


    def extract_from_ssdp_notification(getter)
      @st = @notification['st']
      @usn = @notification['usn']
      @server = @notification['server']
      @location = @notification['location']
      @ext = @notification['ext']

      update_expiration @notification

      if @location
        get_description @location, getter
      else
        fail self, 'M-SEARCH response has no location'
      end
    end

    def bad_description?
      if @description[:root]
        @xmlns = @description[:root][:@xmlns]
        return true unless @xmlns == 'urn:schemas-upnp-org:device-1-0'
        return true unless @description[:root][:spec_version]
        return true unless @description[:root][:spec_version][:major].to_i == 1
        @upnp_version = @description[:root][:spec_version][:major] + '.'
        @upnp_version += @description[:root][:spec_version][:minor]
        return true unless @description[:root][:device]
        false
      else
        true
      end
    end

    def extract_url_base
      if @description[:root][:url_base] and @upnp_version != '1.1'
        @url_base =  @description[:root][:url_base]
        @url_base += '/' unless @url_base.end_with?('/')
      else
        @url_base = @location.match(/[^\/]*\z/).pre_match
      end
    end

    def extract_device_info
      device = @description[:root][:device]
      @type = device[:device_type]
      @friendly_name = device[:friendly_name]
      @manufacturer = device[:manufacturer]
      @manufacturer_url = device[:manufacturer_url] || ''
      @model_description = device[:model_description] || ''
      @model_name = device[:model_name]
      @model_number = device[:model_number] || ''
      @model_url = device[:model_url] || ''
      @serial_umber = device[:serial_number] || ''
      @udn = device[:udn].gsub(/uuid:/, '')
      @upc = device[:upc] || ''
      @presentation_url = device[:presentation_url] || ''
    end

    def extract_icons
      return unless @description[:root][:device][:icon_list]
      @description[:root][:device][:icon_list][:icon].each do |h|
        icon = OpenStruct.new(h)
        icon.url = build_url(@url_base, icon.url)
        @icons << icon
      end
    end

    def extract_services
      if @description[:root][:device][:service_list] &&
          @description[:root][:device][:service_list][:service]
        sl = @description[:root][:device][:service_list][:service]

        proc_each = Proc.new do |s, iter|
          service = CP::RemoteService.new(self, @url_base, s)

          service.errback do |msg|
            log :error, "failed to extract service #{s[:service_id]}: #{msg}"
            iter.next
          end

          service.callback do |serv|
            @services << serv
            create_method_from_service serv
            iter.next
          end

          service.fetch
        end

        proc_after = Proc.new do
          @services_extracted = true
        end

        EM::Iterator.new(sl).each(proc_each, proc_after)
      else
        @services_extracted = true
      end
    end

    def extract_devices
      if @description[:root][:device_list]
        if @description[:root][:device_list][:device]
          dl = @description[:root][:device_list][:device]
          ## TODO
        end
      end
      @devices_extracted = true ## TEMP
    end

    def create_method_from_service(service)
      if service.type =~ /urn:.*:service:(\w+):\d/
        name = snake_case($1).to_sym
        define_singleton_method(name) { service }
      end
    end

    def update_expiration(notification)
      @date = @notification['date'] || ''
      @cache_control = @notification['cache-control'] || ''

      if @notification['nts'] == 'ssdp:alive'
        max_age = @cache_control.match(/max-age\s*=\s*(\d+)/)[1].to_i
      else
        max_age = DEFAULT_MAX_AGE
      end
      @expiration = (@date.empty? ? Time.now : Time.parse(@date)) + max_age
    end

  end

end
