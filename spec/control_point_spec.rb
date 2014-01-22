require_relative 'spec_helper'

module RUPNP

  describe ControlPoint do
    include EM::SpecHelper

    let(:cp) { ControlPoint.new(:all, :response_wait_time => 1) }
    let(:notify_options) { {
        max_age: 10,
        ip: '127.0.0.1',
        port: 1234,
        uuid: UUID.generate,
        boot_id: 1,
        config_id: 1,
        u_search_port: DISCOVERY_PORT,
        try_number: 1
      } }

    it 'should initialize a new instance' do
      expect(cp.devices).to be_a(Array)
      expect(cp.devices).to be_empty
    end

    [:search_only, :start].each do |meth|
      it "##{meth} should detect devices" do
        em do
          uuid1 = UUID.generate
          generate_search_responder uuid1, 1234
          generate_search_responder uuid1, 1234
          uuid2 = UUID.generate
          generate_search_responder uuid2, 1235

          stub_request(:get, '127.0.0.1:1234').to_return :headers => {
            'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'
          }, :body => generate_device_description(uuid1)
          stub_request(:get, '127.0.0.1:1235').to_return :headers => {
            'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'
          }, :body => generate_device_description(uuid2)

          cp.send meth

          EM.add_timer(1) do
            expect(cp.devices).to have(2).item
            done
          end
        end
      end
    end

    it '#search_only should not register devices after wait time is expired' do
      em do
        uuid = UUID.generate
        stub_request(:get, '127.0.0.1:1234').to_return :headers => {
          'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'
        }, :body => generate_device_description(uuid)

        cp.search_only

        EM.add_timer(2) do
          expect(cp.devices).to be_empty
          generate_search_responder uuid, 1234
          EM.add_timer(1) do
            expect(cp.devices).to be_empty
            done
          end
        end
      end
    end

    it '#start should listen for alive notifications' do
      em do
        cp.start
        stub_request(:get, '127.0.0.1:1234/root_description.xml').
          to_return :headers => {
            'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'
          }, :body => generate_device_description(notify_options[:uuid])

        EM.add_timer(2) do
          expect(cp.devices).to be_empty
          SSDP.notify :root, :alive, notify_options
          EM.add_timer(1) do
            expect(cp.devices).to have(1).item
            expect(cp.devices[0].udn).to eq(notify_options[:uuid])
            done
          end
        end
      end
    end

    it '#start should listen for update notifications' do
      em do
        cp.start
        stub_request(:get, '127.0.0.1:1234/root_description.xml').
          to_return :headers => {
            'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'
          }, :body => generate_device_description(notify_options[:uuid])

        EM.add_timer(2) do
          expect(cp.devices).to be_empty
          SSDP.notify :root, :alive, notify_options
          EM.add_timer(1) do
            SSDP.notify :root, :update, notify_options.merge(boot_id: 2)
            EM.add_timer(1) do
              expect(cp.devices).to have(1).item
              expect(cp.devices[0].udn).to eq(notify_options[:uuid])
              expect(cp.devices[0].boot_id).to eq(2)
              done
            end
          end
        end
      end
    end

    it '#start should listen for byebye notifications' do
      em do
        cp.start
        stub_request(:get, '127.0.0.1:1234/root_description.xml').
          to_return :headers => {
            'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'
          }, :body => generate_device_description(notify_options[:uuid])

        EM.add_timer(2) do
          expect(cp.devices).to be_empty
          SSDP.notify :root, :alive, notify_options
          EM.add_timer(1) do
            expect(cp.devices).to have(1).item
            expect(cp.devices[0].udn).to eq(notify_options[:uuid])
            SSDP.notify :root, :byebye, notify_options
            EM.add_timer(1) do
              expect(cp.devices).to be_empty
              done
            end
          end
        end
      end
    end

    it '#find_device_by_udn should get known devices' do
      uuid1 = UUID.generate
      cp.devices << double('rdevice1', :udn => uuid1)
      uuid2 = UUID.generate
      cp.devices << double('rdevice2', :udn => uuid2)
      uuid3 = UUID.generate

      expect(cp.find_device_by_udn(uuid1)).to eq(cp.devices[0])
      expect(cp.find_device_by_udn(uuid2)).to eq(cp.devices[1])
      expect(cp.find_device_by_udn(uuid3)).to be_nil
    end
  end

end

