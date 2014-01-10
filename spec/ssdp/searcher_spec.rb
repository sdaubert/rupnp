require_relative '../spec_helper'

module RUPNP
  module SSDP

    describe Searcher do
      include EM::SpecHelper

      let(:config) do
        {response_wait_time: RUPNP::ControlPoint::DEFAULT_RESPONSE_WAIT_TIME}
      end

      it "should send 2 M-SEARCH packets" do
        em do
          receiver = EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                                             FakeMulticast)
          searcher = RUPNP::SSDP.search(:all, config)

          EM.add_timer(1) do
            expect(receiver.packets).to have(2).items
            receiver.packets.each do |packet|
              expect(packet).to be_a_msearch_packet
            end
            receiver.close_connection
            done
          end
        end
      end

      it 'should send configured number of M-SEARCH packets' do
        em do
          foreach = Proc.new do |n, iter|
            receiver = EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                                               FakeMulticast)
            cfg = config.merge!(try_number: n)
            searcher = RUPNP::SSDP.search(:root, cfg)

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

      it "should discard and log bad responses" do
        reader, writer = IO.pipe
        begin
          RUPNP.logdev = writer
          em do
            receiver = EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                                               FakeMulticast)
            receiver.onmessage do
              receiver.send_data "HTTP/1.1 404 Not Found\r\n\r\n"
              receiver.send_data "this is not an HTTP message!"
            end
            searcher = RUPNP::SSDP.search(:all, config.merge(:try_number => 1))
            searcher.discovery_responses.subscribe do |n|
              next unless n['server'] =~ /RUPNP/
              fail
            end

            EM.add_timer(1) do
              expect(reader.readline).to match(/\[error\] bad HTTP response/)
              expect(reader.readline).to match(/404/)
              reader.readline
              expect(reader.readline).to match(/\[error\] bad HTTP response/)
              expect(reader.readline).to match(/not/)
              done
            end
          end
        ensure
          reader.close
          writer.close
        end
      end
    end

  end
end
