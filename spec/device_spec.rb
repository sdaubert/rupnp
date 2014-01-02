require_relative 'spec_helper'

RUPNP.log_level = :failure

module RUPNP

  describe Device do
    include EM::SpecHelper

    let(:config) do
       {:device_type => 'Basic',
        :type_version => 1,
        :ip => '127.0.0.1',
        :port => 3001,
        :notify_interval => 18000,
        :friendly_name => 'Test',
        :manufacturer => 'RUPNP',
        :model_name => ''}
    end
    let(:device) { Device.new(config) }

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
          device.start
        end
      end

      it "should start HTTP server"

      it "should notify 'alive' message" do
        em do
          listener = SSDP.listen
          count = 0
          listener.notifications.subscribe do |notification|
            expect(notification['nts']).to eq('ssdp:alive')
            count += 1
          end
          device.start

          EM.add_timer(2) do
            expect(count).to eq(3 * RUPNP::SSDP::Notifier::DEFAULT_NOTIFY_TRY)
            device.stop
            done
          end
        end
      end
    end

    context "#stop" do
      it "should stop SSDP server" do
        em do
          device.start

          EM.add_timer(1) do
            device.stop
          end

          EM.add_timer(2) do
            count = 0
            searcher = SSDP.search
            searcher.discovery_responses.subscribe do |resp|
              count += 1 if resp['server'] =~ /rupnp/
            end
            EM.add_timer(1) do
              searcher.close_connection
              expect(count).to eq(0)
              done
            end
          end
        end
      end

      it "should stop HTTP server"

      it "should notify 'byebye' message" do
        em do
          device.start
          EM.add_timer(1) do
            listener = SSDP.listen
            count = 0
            listener.notifications.subscribe do |notification|
              expect(notification['nts']).to eq('ssdp:byebye')
              count += 1
            end

            device.stop

            EM.add_timer(1) do
              expect(count).to eq(3 * RUPNP::SSDP::Notifier::DEFAULT_NOTIFY_TRY)
              done
            end
          end
        end
      end
    end

  end
end
