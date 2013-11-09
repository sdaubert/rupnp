require 'savon'
require_relative 'base'

module RUPNP

  class Service < Base
    attr_reader :type
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

      initialize_savon
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

        extract_service_state_table scpd
        extract_actions scpd

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

    def extract_service_state_table(scpd)
      if scpd[:scpd][:service_state_table][:state_variable]
        @state_table = scpd[:scpd][:service_state_table][:state_variable]
        # ease debug print
        @state_table.each { |s| s.each { |k, v| s[k] = v.to_s } }
      end
    end

    def extract_actions(scpd)
      if scpd[:scpd][:action_list] and scpd[:scpd][:action_list][:action]
        log :info, "extract actions for service #@type"
        @action_list = scpd[:scpd][:action_list][:action]
        @action_list.each do |action|
          action[:argument_list] = action[:argument_list][:argument]
          define_method_from_action action
        end
        p @action_list
        p self.singleton_methods
      end
    end

    def define_method_from_action(action)
      action_name = action[:name]
      name = snake_case(action_name).to_sym
      define_singleton_method(name) do |params|
        @soap.call(action_name) do |locals|
          local.message_tags 'xmlns:u' => @type
          local.soap_action "#{type}##{action_name}"
          if params
            unless params.is_a? Hash
              raise ArgumentError, 'only hash arguments are accepted'
            end
            soap.body params
          end
        end

        ## TODO: process return value
      end
    end

    def initialize_savon
      @soap = Savon.client do |globals|
        globals.endpoint @control_url
        globals.namespace @type
        globals.convert_request_keys_to :camel_case
        globals.log true
        globals.headers :HOST => "#{HOST_IP}"
      end
    end

  end

end
