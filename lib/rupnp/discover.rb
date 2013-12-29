require 'eventmachine-le'
require 'pry'
require 'rupnp'

class RUPNP::Discover
  attr_reader :devices

  def self.run
    d = new
    d.pry
  end

  def initialize
    configure_rupnp
    configure_pry
    create_command_set
  end


  private

  def configure_rupnp
    RUPNP.logdev = devnull = File.open('/dev/null', 'w')
    at_exit { devnull.close }
  end

  def configure_pry
    ::Pry.config.should_load_rc = false
    ::Pry.config.history.should_save = false
    ::Pry.config.history.should_load = false
    ::Pry.config.prompt = [proc { 'discover> ' }, proc { 'discover* ' }]
  end

  def create_command_set
    discover = self

    command_set = Pry::CommandSet.new do
      block_command 'search', 'Search for devices' do |target|
        target ||= :all
        cp = RUPNP::ControlPoint.new(target)
        EM.run do
          cp.search_only
          EM.add_timer(RUPNP::ControlPoint::DEFAULT_RESPONSE_WAIT_TIME+2) do
            discover.instance_eval { @devices = cp.devices }
            output.puts "#{discover.devices.size} devices found"
            EM.stop
          end
        end
      end
    end

    Pry::Commands.import command_set
  end

end
