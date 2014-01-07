require_relative '../spec_helper'

module RUPNP
  module SSDP

    describe Listener do
      include EM::SpecHelper

      it "should receive alive and byebye notifications"

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
