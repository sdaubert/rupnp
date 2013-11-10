require 'savon'
require_relative 'base'

module RUPNP

  class Service < Base

    # @private SOAP integer types
    INTEGER_TYPES = %w(ui1 ui2 ui4 i1 i2 i4 int).freeze
    # @private SOAP float types
    FLOAT_TYPES = %w(r4 r8 number float).freeze
    # @private SOAP string types
    STRING_TYPES = %w(char string uuid).freeze
    # @private SOAP true values
    TRUE_TYPES = %w(1 true yes).freeze
    # @private SOAP false values
    FALSE_TYPES = %w(0 false no).freeze

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

      @type = service[:service_type].to_s
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
        @actions = scpd[:scpd][:action_list][:action]
        @actions.each do |action|
          action[:arguments] = action[:argument_list][:argument]
          action.delete :argument_list
          define_method_from_action action
        end
      end
    end

    def define_method_from_action(action)
      action[:name] = action[:name].to_s
      action_name = action[:name]
      name = snake_case(action_name).to_sym
      define_singleton_method(name) do |params|
        response = @soap.call(action_name) do |locals|
          locals.attributes 'xmlns:u' => @type
          locals.soap_action "#{type}##{action_name}"
          if params
            unless params.is_a? Hash
              raise ArgumentError, 'only hash arguments are accepted'
            end
            locals.message params
          end
        end

        if action[:arguments].is_a? Hash
          log :debug, 'only one argument in argument list'
          if action[:arguments][:direction] == 'out'
            process_soap_response name, response, action[:arguments]
          end
        else
          log :debug, 'true argument list'
          action[:arguments].map do |arg|
            if params arg[:direction] == 'out'
              process_soap_response name, response, arg
            end
          end
        end
      end
    end

    def process_soap_response(action, resp, out_arg)
      if resp.success? and resp.to_xml.empty?
        log :debug, 'Successful SOAP request but empty response'
        return {}
      end

      state_var = @state_table.find do |h|
        h[:name] == out_arg[:related_state_variable]
      end

      action_response = "#{action}_response".to_sym
      out_arg_name = snake_case(out_arg[:name]).to_sym
      value = resp.hash[:envelope][:body][action_response][out_arg_name]

      transform_method = if INTEGER_TYPES.include? state_var[:data_type]
                           :to_i
                         elsif FLOAT_TYPES.include? state_var[:data_type]
                           :to_f
                         elsif STRING_TYPES.include? state_var[:data_type]
                           :to_s
                         end
      if transform_method
        { out_arg_name => value.send(transform_method) }
      elsif TRUE_TYPES.include? state_var[:data_type]
        {  out_arg_name => true }
      elsif FALSE_TYPES.include? state_var[:data_type]
        {  out_arg_name => false }
      else
        log :warn, "SOAP response has an unknown type: #{state_var[:data_type]}"
        {}
      end
    end

    def initialize_savon
      @soap = Savon.client do |globals|
        globals.endpoint @control_url
        globals.namespace @type
        globals.convert_request_keys_to :camel_case
        globals.log true
        globals.headers :HOST => "#{HOST_IP}"
        globals.env_namespace 's'
        globals.namespace_identifier 'u'
      end
    end

  end

end
