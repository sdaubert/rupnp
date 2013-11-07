require 'awesome_print'

module RUPNP

  VERSION = '0.1.0'

  @logdev = STDERR

  def self.logdev=(io_or_string)
    if io_or_string.is_a? String
      @logdev = File.open(io_or_string, 'w')
    else
      @logdev = io_or_string
    end
  end

  def self.logdev
    @logdev
  end

end


require_relative 'rupnp/constants'
require_relative 'rupnp/control_point'
require_relative 'rupnp/device'
require_relative 'rupnp/ssdp'
