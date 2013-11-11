module RUPNP

  module Tools

    def build_url(base, rest)
      url = base + (base.end_with?('/') ? '' : '/')
      url + (rest.start_with?('/') ? rest[1..-1] : rest)
    end

    def snake_case(str)
      g = str.gsub(/([^A-Z_])([A-Z])/,'\1_\2')
      g.downcase || str.downcase
    end

  end

end
