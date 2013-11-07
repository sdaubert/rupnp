require 'em-http-request'
require 'nori'
require 'ostruct'
require_relative 'service'
require_relative 'base'


module RUPNP

  class Device < Base
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
    attr_reader :type
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
    attr_reader :icons
    attr_reader :services
    attr_reader :devices


    def initialize(notification)
      super()
      @notification = notification

      @icons = []
      @services = []
      @devices = []
    end

    def fetch
      description_getter = EM::DefaultDeferrable.new

      description_getter.errback do
        msg = "Failed getting description"
        log :error, "Fetching device: #{msg}"
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
        extract_icons

        extract_services
        extract_devices

        succeed self
      end
    end

    def extract_from_ssdp_notification(getter)
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
                      Time.parse(@date) + max_age
                    end

      if @location
        get_description @location, getter
      else
        fail self, 'M-SEARCH response has no location'
      end
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
      @udn = device[:udn]
      @upc = device[:upc] || ''
      @presentation_url = device[:presentation_url] || ''
    end

    def extract_icons
      @description[:root][:device][:icon_list][:icon].each do |h|
        icon = OpenStruct.new(h)
        icon.url = build_url(@url_base, icon.url)
        @icons << icon
      end
    end

    def extract_services
      if @description[:root][:device][:service_list]
        if @description[:root][:device][:service_list][:service]
          sl = @description[:root][:device][:service_list][:service]
          EM::Iterator.new(sl).each do |s, iter|
            service = Service.new(@url_base, s)

            service.errback do |msg|
              log :error, "failed to extract service #{s[:service_id]}: #{msg}"
              iter.next
            end

            service.callback do |serv|
              @services << serv
              ap serv
              iter.next
            end

            service.fetch
          end
        end
      end
    end

    def extract_devices
      if @description[:root][:device_list]
        if @description[:root][:device_list][:device]
          dl = @description[:root][:device_list][:device]
          #p dl
        end
      end
    end

    end

end
