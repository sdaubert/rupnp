require 'em-http-request'
require 'nori'

module RUPNP

  class Device
    include EM::Deferrable

    HTTP_COMMON_CONFIG = {
      :head => {
        :user_agent => USER_AGENT,
        :host => "#{HOST_IP}:#{DISCOVERY_PORT}",
      },
    }

    attr_reader :st
    attr_reader :usn
    attr_reader :server
    attr_reader :location
    attr_reader :ext
    attr_reader :date
    attr_reader :cache_control
    attr_reader :bootid

    attr_reader :upnp_version
    attr_reader :xmlns
    attr_reader :url_base # uPnP 1.0 only
    attr_reader :device_type
    attr_reader :friendly_name
    attr_reader :manufacturer
    attr_reader :manufacturer_url
    attr_reader :model_description
    attr_reader :model_name
    attr_reader :model_number
    attr_reader :model_url
    attr_reader :serial_umber
    attr_reader :udn
    attr_reader :upc
    attr_reader :presentation_url


    def initialize(notification)
      @notification = notification
      @parser = Nori.new(:convert_tags_to => ->(tag){ tag.snakecase.to_sym })
    end

    def fetch
      description_getter = EM::DefaultDeferrable.new

      description_getter.errback do
        msg = "Failed getting description"
        puts msg
        fail self, msg
      end

      extract_from_ssdp_notification description_getter

      description_getter.callback do |description|
        @description = description
        unless description
          fail self, 'Blank description returned'
          next
        end

        if bad_description?
          fail self, "Bad description returned: #@description"
          next
        end

        extract_url_base
        extract_device_info

        succeed self
      end
    end

    def extract_from_ssdp_notification(getter)
      ap @notification
      @st = @notification['st']
      @usn = @notification['usn']
      @server = @notification['server']
      @location = @notification['location']
      @ext = @notification['ext']
      @date = @notification['date'] || ''
      @cache_control = @notification['cache-control'] || ''
      @server = @notification['server']

      max_age = @cache_control.match(/max-age\s*=\s*(\d+)/)[1].to_i
      @expiration = if @date.empty?
                      Time.now + max_age
                    else
                      puts "max-age: #{max_age}"
                      Time.parse(@date) + max_age
                    end

      if @location
        get_description @location, getter
      else
        fail self, 'M-SEARCH response has no location'
      end
    end

    def get_description(location, getter)
      puts "getting description for #{location}"
      http = EM::HttpRequest.new(location).get(HTTP_COMMON_CONFIG)

      http.errback do |error|
        getter.set_deffered_status :failed, 'Cannot get description'
      end

      callback = Proc.new do
        description = @parser.parse(http.response)
        puts 'Description received'
        getter.succeed description
      end

      http.headers do |h|
        unless h['SERVER'] =~ /UPnP\/1\.\d/
          puts "Not a supported UPnP response : #{h['SERVER']}"
          http.cancel_callback callback
        end
      end

      http.callback &callback
    end

    def bad_description?
      if @description[:root]
        bd = false
        @xmlns = @description[:root][:@xmlns]
        bd |= @xmlns != 'urn:schemas-upnp-org:device-1-0'
        bd |= @description[:root][:spec_version][:major].to_i != 1
        @upnp_version = @description[:root][:spec_version][:major] + '.'
        @upnp_version += @description[:root][:spec_version][:minor]
        bd |= !@description[:root][:device]
      else
        true
      end
    end

    def extract_url_base
      if @upnp_version == '1.0'
        if @description[:root][:url_base]
          @url_base =  @description[:root][:url_base]
        end
      end
    end

    def extract_device_info
      device = @description[:root][:device]
      @device_type = device[:device_type]
      @friendly_name = device[:friendly_name]
      @manufacturer = device[:manufacturer]
      @manufacturer_url = device[:manufacturer_url] || ''
      @model_description = device[:model_description] || ''
      @model_name = device[:model_name]
      @model_number = device[:model_number] || ''
      @model_url = device[:model_url] || ''
      @serial_umber = device[:serial_number] || ''
      @udn = device[:udn]
      @upc = device[:upc] || ''
      @presentation_url = device[:presentation_url] || ''
    end

  end

end
