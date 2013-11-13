require 'awesome_print'
require 'eventmachine-le'

# Module for RUPNP namespace
# @author Sylvain Daubert
module RUPNP

  # RUPNP version
  VERSION = '0.1.0'

  @logdev = STDERR
  @log_level = :info

  # Set log device
  # @param [IO,String] io_or_string io or filename to log to
  # @return [IO]
  def self.logdev=(io_or_string)
    if io_or_string.is_a? String
      @logdev = File.open(io_or_string, 'w')
    else
      @logdev = io_or_string
    end
  end

  # Get log device
  # @return [IO] io used to log
  def self.logdev
    @logdev
  end

  # Set log level
  # @param [:debug,:info,:warn,:error] lvl
  def self.log_level=(lvl)
    @log_level = lvl
  end

  # Get log level
  # @return [Symbol]
  def self.log_level
    @log_level
  end

end


require_relative 'rupnp/constants'
require_relative 'rupnp/log_mixin'
require_relative 'rupnp/event_server'
require_relative 'rupnp/event_subscriber'
require_relative 'rupnp/event'
require_relative 'rupnp/control_point'
require_relative 'rupnp/base'
require_relative 'rupnp/service'
require_relative 'rupnp/device'
require_relative 'rupnp/ssdp'
