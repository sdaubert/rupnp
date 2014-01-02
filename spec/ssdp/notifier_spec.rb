require_relative '../spec_helper'

module RUPNP
  module SSDP

    describe Notifier do
      include EM::SpecHelper

      let(:config) do
        {max_age: 18000,
          ip: '127.0.0.1',
          port: 3001,
          uuid: UUID.generate,
          boot_id: 1,
          config_id: 1,
          u_search_port: 1900}
      end

      [:alive, :byebye].each do |type|
        it "should send 2 #{type} notify packets" do
          em do
            receiver = EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                                               FakeMulticast)
            notifier = RUPNP::SSDP.notify(:root, type, config)

            EM.add_timer(1) do
              expect(receiver.packets).to have(2).items
              receiver.packets.each do |packet|
                expect(packet).to be_a_notify_packet(type)
              end
              receiver.close_connection
              done
            end
          end
        end
      end

        it 'should send configured number of notify packets' do
        em do
          foreach = Proc.new do |n, iter|
            receiver = EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                                               FakeMulticast)
            cfg = config.merge!(try_number: n)
            notifier = RUPNP::SSDP.notify(:root, :alive, cfg)

            EM.add_timer(1) do
              expect(receiver.packets).to have(n).items
              receiver.close_connection
              iter.next
            end
          end
          after = Proc.new { done }

          EM::Iterator.new(3..5, 1).each(foreach, after)
        end
      end

    end

  end
end
