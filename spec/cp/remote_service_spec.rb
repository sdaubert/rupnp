require_relative '../spec_helper'
module RUPNP
  module CP

    describe RemoteService do
      include EM::SpecHelper
      include RUPNP::Tools

      let(:url_base) { 'http://127.0.0.1:1234/' }
      let(:sd) { {
          :service_type => 'urn:schemas-upnp-org:service:Service:1-0',
          :service_id => 'urn:upnp-org:serviceId:Service',
          :scpdurl => '/service/description.xml',
          :control_url => '/service/control',
          :event_sub_url => '/service/event' } }
      let(:rs){ RemoteService.new(double('rdevice'), url_base, sd)}

      context '#fetch' do

        it 'should fetch SCPD' do
          stub_request(:get, build_url(url_base, sd[:scpdurl])).
            to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                      :body => generate_scpd)
          em do
            rs.errback { fail 'RemoteService#fetch should work' }
            rs.callback do
              done
            end
            rs.fetch
          end
        end

        it 'should set state table' do
          stub_request(:get, build_url(url_base, sd[:scpdurl])).
            to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                      :body => generate_scpd(:nb_state_var => 4))
          em do
            rs.errback { fail 'RemoteService#fetch should work' }
            rs.callback do
              expect(rs.state_table).to have(4).items
              expect(rs.state_table[0][:name]).to eq('X_variableName1')
              expect(rs.state_table[1][:data_type]).to eq('ui4')
              expect(rs.state_table[2][:default_value]).to eq('2')
              expect(rs.state_table[3][:allowed_value_range][:maximum]).
                to eq('255')
              done
            end
            rs.fetch
          end
        end

        it 'should define actions as methods from description' do
          stub_request(:get, build_url(url_base, sd[:scpdurl])).
            to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                      :body => generate_scpd(:nb_state_var => 2,
                                             :define_action => true))
          stub_request(:post, build_url(url_base, sd[:control_url])).
            to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                      :body => action_response(var2: 1))
          em do
            rs.errback { fail 'RemoteService#fetch should work' }
            rs.callback do
              expect(rs).to respond_to(:test_action)
              res = rs.test_action('var1' => 10)
              expect(res[:var2]).to eq(1)
              done
            end
            rs.fetch
          end
        end

        it 'should fail when SCPDURL is unreachable' do
          stub_request(:get, build_url(url_base, sd[:scpdurl])).to_timeout

          em do
            rs.errback  do |msg|
              expect(msg).to match(/cannot get SCPD/)
              done
            end
            rs.callback { fail 'RemoteService#fetch should not work' }
            rs.fetch
          end
        end

        it 'should fail when SCPDURL does not return a SCPD' do
          stub_request(:get, build_url(url_base, sd[:scpdurl])).
            to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                      :body => 'This is only text!')

          em do
            rs.errback do |msg|
              expect(msg).to match(/not a UPNP .* SCPD/)
              done
            end
            rs.callback { fail 'RemoteService#fetch should not work' }
            rs.fetch
          end
        end

        it "should fail when SCPD does not conform to UPnP spec" do
          stub_request(:get, build_url(url_base, sd[:scpdurl])).
            to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                      :body => generate_scpd(:version_major => 2))

          em do
            rs.errback do |msg|
              expect(msg).to match(/not a UPNP .* SCPD/)
              done
            end
            rs.callback { fail 'RemoteService#fetch should not work' }
            rs.fetch
          end
        end
      end

      context '#subscribe_to_event' do

        before(:each) do
          stub_request(:get, build_url(url_base, sd[:scpdurl])).
            to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                      :body => generate_scpd)
          @webstub = stub_request(:subscribe,
                                  build_url(url_base, sd[:event_sub_url])).
            with(:headers => { 'NT' => 'upnp:event'}).
            to_return(:headers => {
                        'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0',
                        'SID' => "uuid:#{UUID.generate}",
                        'CONTENT-LENGTH' => 0,
                        'TIMEOUT' => 'Second-1800'})
          rs.device.stub(:control_point => ControlPoint.new(:root))
        end

        it 'should start event server' do
          em do
            rs.errback { fail 'RemoteService#fetch should work' }
            rs.callback do
              expect(rs.device.control_point.event_port).to be_nil
              rs.subscribe_to_event {}
              expect(rs.device.control_point.event_port).to be_a(Integer)
              done
            end
            rs.fetch
          end
        end

        it 'should subscribe to an event' do
          em do
            rs.errback { fail 'RemoteService#fetch should work' }
            rs.callback do
              expect(rs.state_table.first[:name]).to eq('X_variableName1')
              expect(rs.state_table.first[:name]).to eq('X_variableName1')
              rs.subscribe_to_event do |msg|
                done
                pending 'verify variable update'
              end
            end
            rs.fetch

            EM.add_timer(1) do
              event = class EventServer; @@events.last; end
              url = "http://127.0.0.1:8080#{event.callback_url}"
              conn = EM::HttpRequest.new(url)
              send_notify_request(conn, 'SID' => event.sid)
            end
          end
        end

        it 'should not fail if subscribtion is not possible' do
          rd_io, wr_io = IO.pipe
          begin
            RUPNP.logdev = wr_io
            RUPNP.log_level = :warn

            remove_request_stub(@webstub)
            stub_request(:subscribe, build_url(url_base, sd[:event_sub_url])).
              with(:headers => { 'NT' => 'upnp:event'}).
              to_timeout.then.
              to_return(:status => 404)

            em do
              rs.errback { fail 'RemoteService#fetch should work' }
              rs.callback do
                expect { rs.subscribe_to_event { fail } }.to_not raise_error
                expect { rs.subscribe_to_event { fail } }.to_not raise_error
                EM.add_timer(1) do
                  expect(rd_io.readline).to match(/timeout/)
                  expect(rd_io.readline).to match(/Not Found/)
                  done
                end
              end
              rs.fetch
            end
          ensure
            rd_io.close
            wr_io.close
          end
        end
      end

    end

  end
end
