module RUPNP

  class Service
    include EM::Deferrable

    attr_reader :type
    attr_reader :id
    attr_reader :scpd_url
    attr_reader :control_url
    attr_reader :event_sub_url

    attr_reader :xmlns
    attr_reader :config_id
    attr_reader :spec_version
    attr_reader :actions
    attr_reader :state_table

    def initialize(url_base, scpd)
      @url_base = url_base
      @description = scpd

      @type = scpd[:service_type].to_s
      @scpd_url = scpd[:scpdurl].to_s
      @control_url = scpd[:control_url].to_s
      @event_sub_url = scpd[:event_sub_url].to_s
      @actions = []
    end

    def fetch
      if @scpd_url.empty?
        fail
        return
      end

      succeed self
    end

  end

end
