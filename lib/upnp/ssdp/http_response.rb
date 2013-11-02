module Upnp

  module SSDP::HTTPResponse

    def is_http_status_ok?(sock)
      sock.readline =~ /\s*HTTP\/1.1 200 OK\r\n\z/i
    end

    def get_http_headers(sock)
      headers = {}
      sock.each_line do |l|
        l =~ /([\w-]+):\s*(.*)/
        if $1
          headers[$1.downcase] = $2.strip
        end
      end
      headers
    end

  end

end
