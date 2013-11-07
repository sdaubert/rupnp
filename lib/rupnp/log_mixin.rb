module RUPNP

  module LogMixin


    # @private
    LOG_LEVEL = {
      :failure => 5,
      :error   => 4,
      :warn    => 3,
      :info    => 2,
      :debug   => 1
    }
    LOG_LEVEL.default = 0

    def log(level, msg='')
      if LOG_LEVEL[level] >= LOG_LEVEL[RUPNP.log_level]
        RUPNP.logdev.puts "[#{level}] #{msg}"
      end
    end

  end

end
