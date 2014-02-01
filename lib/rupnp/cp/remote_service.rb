require 'uri'
require 'savon'
require_relative 'base'

module RUPNP

  # Service class for device's services.
  #
  # ==Actions
  # This class defines ruby methods from actions defined in
  # service description, as provided by the device.
  #
  # By example, from this description:
  #  <action>
  #    <name>actionName</name>
  #    <argumentList>
  #    <argument>
  #      <name>argumentNameIn</name>
  #      <direction>in</direction>
  #      <relatedStateVariable>stateVariableName</relatedStateVariable>
  #    </argument>
  #    <argument>
  #      <name>argumentNameOut</name>
  #      <direction>out</direction>
  #      <relatedStateVariable>stateVariableName</relatedStateVariable>
  #    </argument>
  #  </action>
  # a +#action_name+ method is created. This method requires a hash with
  # an element named +argument_name_in+.
  # If no <i>in</i> argument is required, an empty hash (<code>{}</code>)
  # must be passed to the method. Hash keys may not be symbols.
  #
  # A Hash is returned, with a key for each <i>out</i> argument.
  #
  # @author Sylvain Daubert
  class CP::RemoteService < CP::Base

    # @private
    @@event_sub_count = 0

    # Get event subscription count for all services
    # (unique ID for subscription)
    # @return [Integer]
    def self.event_sub_count
      @@event_sub_count += 1
    end


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

    # Get device to which this service belongs to
    # @return [Device]
    attr_reader :device

    # Get service type
    # @return [String]
    attr_reader :type
    # Get service id
    # @return [String]
    attr_reader :id
    # URL for service description
    # @return [String]
    attr_reader :scpd_url
    # URL for control
    # @return [String]
    attr_reader :control_url
    # URL for eventing
    # @return [String]
    attr_reader :event_sub_url

    # XML namespace for device description
    # @return [String]
    attr_reader :xmlns
    # Define architecture on which the service is implemented
    # @return [String]
    attr_reader :spec_version
    # Available actions on this service
    # @return [Array<Hash>]
    attr_reader :actions
    # State table for the service
    # @return [Array<Hash>]
    attr_reader :state_table

    # @param [Device] device
    # @param [String] url_base
    # @param [Hash] service
    def initialize(device, url_base, service)
      super()
      @device = device
      @description = service

      @type = service[:service_type].to_s
      @id = service[:service_id].to_s
      @scpd_url = build_url(url_base,  service[:scpdurl].to_s)
      @control_url =  build_url(url_base, service[:control_url].to_s)
      @event_sub_url =  build_url(url_base, service[:event_sub_url].to_s)
      @actions = []

      initialize_savon
    end

    # Get service from its description
    # @return [void]
    def fetch
      scpd_getter = EM::DefaultDeferrable.new

      scpd_getter.errback do
        fail "cannot get SCPD from #@scpd_url"
        next
      end

      scpd_getter.callback do |scpd|
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

    # Subscribe to event
    # @param [Hash] options
    # @option options [Integer] timeout
    # @yieldparam [Event] event event received
    # @yieldparam [Object] msg message received
    # @return [Integer] subscribe id. May be used to unsubscribe on event
    def subscribe_to_event(options={}, &blk)
      cp = device.control_point

      cp.start_event_server

      port = cp.event_port
      num = self.class.event_sub_count
      @callback_url = "http://#{HOST_IP}:#{port}/event#{num}}"

      uri = URI(@event_sub_url)
      options[:timeout] ||= EVENT_SUB_DEFAULT_TIMEOUT

      log :info, "send SUBSCRIBE request to #{uri}"
      con = EM::HttpRequest.new(@event_sub_url)
      http = con.setup_request(:subscribe, :head => {
                                 'HOST' => "#{uri.host}:#{uri.port}",
                                 'USER-AGENT' => RUPNP::USER_AGENT,
                                 'CALLBACK' => @callback_url,
                                 'NT' => 'upnp:event',
                                 'TIMEOUT' => "Second-#{options[:timeout]}"})

      http.errback do |error|
        log :warn, "Cannot subscibe to event: #{error}"
      end

      http.callback do
        log :debug, 'Close connection to subscribe event URL'
        con.close
        if http.response_header.status != 200
          log :warn, "Cannot subscribe to event #@event_sub_url:" +
            " #{http.response_header.http_status}"
        else
          timeout = http.response_header['TIMEOUT'].match(/(\d+)/)[1] || 1800
          event = Event.new(@event_sub_url, @callback_url,
                            http.response_header['SID'], timeout.to_i)
          cp.add_event_url << ["/event#{num}", event]
          event.subscribe &blk
        end
      end
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

        if @state_table.is_a? Hash
          @state_table = [@state_table]
        end
      end
    end

    def extract_actions(scpd)
      if scpd[:scpd][:action_list] and scpd[:scpd][:action_list][:action]
        log :info, "extract actions for service #@type"
        @actions = scpd[:scpd][:action_list][:action]
        @actions = [@actions] unless @actions.is_a? Array
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
        if params
          unless params.is_a? Hash
            raise ArgumentError, 'only hash arguments are accepted'
          end
        end
        response = @soap.call(action_name) do |locals|
          locals.attributes 'xmlns:u' => @type
          locals.soap_action "#{type}##{action_name}"
          locals.message params
        end

        if action[:arguments].is_a? Hash
          log :debug, 'only one argument in argument list'
          if action[:arguments][:direction] == 'out'
            process_soap_response name, response, action[:arguments]
          end
        else
          log :debug, 'true argument list'
          hsh = {}
          outer = action[:arguments].select { |arg| arg[:direction] == 'out' }
          outer.each do |arg|
            hsh.merge! process_soap_response(name, response, arg)
          end
          hsh
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
        globals.log_level :error
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
