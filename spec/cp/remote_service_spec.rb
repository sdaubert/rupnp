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
          :event_url => '/service/event' } }
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
        it 'should start event server'
        it 'should subscribe to an event'
        it 'should not fail if subscribtion is not possible'
      end

    end

  end
end
