module RUPNP

  # Helper module
  # @author Sylvain Daubert
  module Tools

    # Build an url from a base and a relative url
    # @param [String] base
    # @param [String] rest
    # @return [String]
    def build_url(base, rest)
      url = base + (base.end_with?('/') ? '' : '/')
      url + (rest.start_with?('/') ? rest[1..-1] : rest)
    end

    # Convert a camel cased string to a snake cased one
    #   snake_case("iconList")     # => "icon_list"
    #   snake_case("eventSubURL")  # => "event_sub_url"
    # @param [String] str
    # @return [String]
    def snake_case(str)
      g = str.gsub(/([^A-Z_])([A-Z])/,'\1_\2')
      g.downcase || str.downcase
    end

  end

end
