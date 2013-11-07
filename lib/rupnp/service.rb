require_relative 'base'

module RUPNP

  class Service < Base
    attr_reader :type
    attr_reader :id
    attr_reader :scpd_url
    attr_reader :control_url
    attr_reader :event_sub_url

    attr_reader :xmlns
    attr_reader :spec_version
    attr_reader :actions
    attr_reader :state_table

    def initialize(url_base, service)
      super()
      @description = service

      @type = build_url(url_base, service[:service_type].to_s)
      @scpd_url = build_url(url_base,  service[:scpdurl].to_s)
      @control_url =  build_url(url_base, service[:control_url].to_s)
      @event_sub_url =  build_url(url_base, service[:event_sub_url].to_s)
      @actions = []
    end

    def fetch
      if @scpd_url.empty?
        fail 'no SCPD URL'
        return
      end

      scpd_getter = EM::DefaultDeferrable.new

      scpd_getter.errback do
        fail "cannot get SCPD from #@scpd_url"
      end

      scpd_getter.callback do |scpd|
        if !scpd or scpd.empty?
          fail "SCPD from #@scpd_url is empty"
          next
        end

        if bad_description?(scpd)
          fail 'not a UPNP 1.0/1.1 SCPD'
          next
        end

        succeed self
      end

      get_description @scpd_url, scpd_getter
    end


    private

    def bad_description?(scpd)
      if scpd[:scpd]
        bd = false
        @xmlns = scpd[:scpd][:@xmlns]
        bd |= @xmlns != "urn:schemas-upnp-org:service-1-0"
        bd |= scpd[:scpd][:spec_version][:major].to_i != 1
        @spec_version = scpd[:scpd][:spec_version][:major] + '.'
        @spec_version += scpd[:scpd][:spec_version][:minor]
        bd |= !scpd[:scpd][:service_state_table]
        bd | scpd[:scpd][:service_state_table].empty?
      else
        true
      end
    end

  end

end
