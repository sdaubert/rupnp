require_relative 'spec_helper'

RUPNP.log_level = :failure

module RUPNP

  describe Device do
    include EM::SpecHelper

    let(:config) do
      Hash[Device::CONFIG[:required].map { |item| [item, 'value'] }]
    end

    context "#initialize" do

      it "should raise DeviceInitializationError if misconfigured" do
        Device::CONFIG[:required].each do |item|
          cfg = config.dup
          cfg.delete(item)
          expect { Device.new(cfg) }.to raise_error(DeviceInitializationError)
        end

        expect { Device.new(config) }.not_to raise_error
      end

      it "should generate a unique UID" do
        d1 = Device.new(config)
        d2 = Device.new(config)
        expect(d1.uuid).not_to eq(d2.uuid)
      end

      it "should use given UUID if configured for that" do
        d1 = Device.new(config)
        config[:uuid] = d1.uuid
        d2 = Device.new(config)
        expect(d1.uuid).to eq(d2.uuid)
      end
    end

    context "#start" do
      before(:each) do
        cfg = config.merge!({ :device_type => 'Basic',
                             :type_version => 1,
                             :ip => '127.0.0.1',
                             :port => 3001,
                             :notify_interval => 18000})
        @device = Device.new(config.merge(:ip => '127.0.0.1', :port => 3001))
      end

      it "should start SSDP server" do
        em do
          EM.add_timer(1) do
            searcher = SSDP.search
            searcher.discovery_responses.subscribe do |resp|
              searcher.close_connection
              expect(resp['location']).to match(/127.0.0.1/)
              expect(resp['server']).to match(/rupnp/)
              done
            end
          end
          EM.add_timer(2) do
            fail
            done
          end
          @device.start
        end
      end

      it "should start HTTP server"
      it "should notify 'alive' message"
    end

    context "#stop" do
      it "should stop SSDP server"
      it "should stop HTTP server"
      it "should notify 'byebye' messge"
    end

  end
end
