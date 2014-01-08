require_relative '../spec_helper'

module RUPNP
  module SSDP

    describe Listener do
      include EM::SpecHelper

      it "should receive alive and byebye notifications" do
        RUPNP.log_level = :failure
        em do
          notifications = []
          listener = SSDP.listen
          listener.notifications.subscribe do |notification|
            notifications << notification
          end

          EM.add_timer(1) do
            options = {
              max_age: 10,
              ip: '127.0.0.1',
              port: 65534,
              uuid: UUID.generate,
              boot_id: 1,
              config_id: 1,
              u_search_port: DISCOVERY_PORT,
              try_number: 1
            }
            SSDP.notify :root, :alive, options
            SSDP.notify :root, :byebye, options
          end

          EM.add_timer(2) do
            listener.close_connection
            expect(notifications).to have(2).items
            expect(notifications[0]['nts']).to eq('ssdp:alive')
            expect(notifications[1]['nts']).to eq('ssdp:byebye')
            done
          end
        end
      end

      it "should ignore M-SEARCH requests" do
        rd_io, wr_io = IO.pipe
        begin
          RUPNP.logdev = wr_io
          RUPNP.log_level = :warn
          em do
            listener = SSDP.listen
            listener.notifications.subscribe do |notification|
              fail
            end

            searcher = SSDP.search(:all, :try_number => 1)

            EM.add_timer(1) do
              begin
                warn = rd_io.read_nonblock(127)
                expect(warn).to be_empty
              rescue IO::WaitReadable
              end
              done
            end
          end
        ensure
         rd_io.close
         wr_io.close
        end
      end

      it "should ignore and log unknown requests" do
        rd_io, wr_io = IO.pipe
        begin
          RUPNP.logdev = wr_io
          RUPNP.log_level = :warn
          em do
            listener = SSDP.listen
            listener.notifications.subscribe do |notification|
              fail
            end

            fake = EM.open_datagram_socket(MULTICAST_IP, DISCOVERY_PORT,
                                           FakeMulticast)
            cmd = "GET / HTTP/1.1\r\n\r\n"
            fake.send_datagram(cmd, MULTICAST_IP, DISCOVERY_PORT)

            EM.add_timer(1) do
              warn = rd_io.readline
              expect(warn).to eq("[warn] Unknown HTTP command: #{cmd[0..-3]}")
              done
            end
          end
        ensure
         rd_io.close
         wr_io.close
        end
      end

    end

  end
end
