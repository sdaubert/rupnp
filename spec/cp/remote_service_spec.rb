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
            rs.errback { fail 'RemoteDevice#fetch should work' }
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
            rs.errback { fail 'RemoteDevice#fetch should work' }
            rs.callback do
              p rs.state_table
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

        it 'should define actions as methods from description'
        it 'should fail when no SCPD URL is given'
        it 'should fail when SCPDURL is incorrect'
        it 'should fail when SCPDURL is incorrect is empty'
        it "should fail when SCPD does not conform to UPnP spec"
      end

      context '#subscribe_to_event' do
        it 'should start event server'
        it 'should subscribe to an event'
        it 'should not fail if subscribtion is not possible'
      end

    end

  end
end
