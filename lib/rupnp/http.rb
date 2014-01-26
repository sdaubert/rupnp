module RUPNP

  # HTTP module to provide some helper methods
  # @author Sylvain Daubert
  module HTTP

    # Return status from HTTP response
    # @param [IO] sock
    # @return [Booelan]
    def is_http_status_ok?(sock)
      sock.readline =~ /\s*HTTP\/1.1 200 OK\r\n\z/i
    end

    # Get HTTP headers from response
    # @param [IO] sock
    # @return [Hash] keys are downcase header name strings
    def get_http_headers(sock)
      headers = {}
      sock.each_line do |l|
        l =~ /([\w\.-]+):\s*(.*)/
        if $1
          headers[$1.downcase] = $2.strip
        end
      end
      headers
    end

    # Get HTTP verb from HTTP request
    # @param [IO] sock
    # @return [nil,Hash] keys are +:verb+, +:path+, +:http_version+ and
    #   +:cmd+ (all line)
    def get_http_verb(sock)
      str = sock.readline
      if str =~ /([\w-]+)\s+(.*)\s+HTTP\/(\d\.\d)/
        {:verb => $1, :path => $2, :http_version => $3, :cmd => str}
      else
        nil
      end
    end

  end

end
