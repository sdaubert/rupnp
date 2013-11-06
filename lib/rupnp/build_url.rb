module RUPNP

  module BuildUrl

    def build_url(base, rest)
      url = base + (base.end_with?('/') ? '' : '/')
      url + (rest.start_with?('/') ? rest[1..-1] : rest)
    end
  end

end
