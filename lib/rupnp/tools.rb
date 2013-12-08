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

    # Check if two URN are equivalent. They are equivalent if they have
    # the same name and the same major version.
    # @param [String] urn1
    # @param [String] urn2
    # @return [Boolean]
    def urn_are_equivalent?(urn1, urn2)
      u1 = urn1
      if urn1[0..3] == 'urn:'
        u1 = urn1[4..-1]
      end
      u2 = urn2
      if urn2[0..3] == 'urn:'
        u2 = urn2[4..-1]
      end

      m1 = u1.match(/(\w+):(\w+):(\w+):([\d-]+)/)
      m2 = u2.match(/(\w+):(\w+):(\w+):([\d-]+)/)
      if m1[1] == m2[1]
        if m1[2] == m2[2]
          if m1[3] == m2[3]
            v1_major = m1[4].split(/-/).first
            v2_major = m2[4].split(/-/).first
            if v1_major == v2_major
              return true
            end
          end
        end
      end
      false
    end

  end

end
