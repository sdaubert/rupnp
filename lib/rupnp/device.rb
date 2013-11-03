require 'em-http-request'

module RUPNP

  class Device
    include EM::Deferrable

    HTTP_COMMON_CONFIG = {
      :head => { :user_agent => USER_AGENT },
    }

    attr_reader :st
    attr_reader :usn
    attr_reader :server
    attr_reader :location
    attr_reader :ext
    attr_reader :date
    attr_reader :cache_control
    attr_reader :bootid

    def initialize(notification)
      @notification = notification
    end

    def fetch
      description_getter = EM::DefaultDeferrable.new

      description_getter.errback do
        msg = "Failed getting description"
        puts msg
        set_deffered_status :failed, msg
      end

      extract_from_ssdp_notification description_getter

      description_getter.callback do |description|
        #todo
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

      max_age = @cache_control.match(/max-age\s*=\s*(\d+)/)[0].to_i
      @expiration = if @date.empty?
                      Time.now + max_age
                    else
                      Time.parse(@date) + max_age
                    end

      if @location
        get_description @location, getter
      else
        set_deffered_status :failed, 'M-SEARCH response has no location'
      end
    end

    def get_description(location, getter)
      puts "getting description for #{location}"
      http = EM::HttpRequest.new(location).get HTTP_COMMON_CONFIG

      http.errback do |error|
        getter.set_deffered_status :failed, 'Cannot get description'
      end

      http.callback do
        description = http.response
        puts description
        getter.set_deferred_status :ok, description
      end
    end

  end

end
