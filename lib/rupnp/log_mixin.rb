module RUPNP

  # Mixin to add log facility to others classes.
  # @author Sylvain Daubert
  module LogMixin


    # Log severity levels
    LOG_LEVEL = {
      :failure => 5,
      :error   => 4,
      :warn    => 3,
      :info    => 2,
      :debug   => 1
    }
    LOG_LEVEL.default = 0

    # log a message
    # @param [Symbol] level severity level.  May be +:debug+, 
    #    +:info+, +warn+, or +:error+
    # @param [String] msg message to log
    def log(level, msg='')
      if LOG_LEVEL[level] >= LOG_LEVEL[RUPNP.log_level]
        RUPNP.logdev.puts "[#{level}] #{msg}"
      end
    end

  end

end
