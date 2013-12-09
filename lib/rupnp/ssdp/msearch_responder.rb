module RUPNP

  # M-SEARCH responder for M-SEARCH multicast requests from control points.
  # @author Sylvain Daubert
  class SSDP::MSearchResponder < SSDP::MulticastConnection
    include HTTP
    include SSDP::SearchResponder

    # @param [Hash] options
    # @option options [Integer] :ttl
    def initialize(device, options={})
      @device = device
      @options = options
      super options[:ttl]
    end

  end

end
