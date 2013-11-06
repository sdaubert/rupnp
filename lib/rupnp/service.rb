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
        fail
        return
      end

      scpd_getter = EM::DefaultDeferrable.new

      scpd_getter.errback do
        fail
      end

      scpd_getter.callback do |scpd|
        fail unless scpd && !scpd.empty?

        @xmlns = scpd[:scpd][:@xmlns]
        # TODO: get spec_version, actions and state_table
        succeed self
      end

      get_description @scpd_url, scpd_getter
    end

  end

end
