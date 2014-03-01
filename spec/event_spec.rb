require_relative 'spec_helper'

module RUPNP

  describe Event do
    include EM::SpecHelper

    let(:host) { '192.169.15.48:45678' }
    let(:location) { "#{host}/event_subscription" }
    let(:ev_suburl) { "http://#{location}" }
    let(:sid) { "uuid:#{UUID.generate}" }
    let(:options) { { :auto_renew => true, :before_timeout => 1 } }
    let(:ev) { Event.new(ev_suburl, '', sid, 2, options)}

    it 'should send timeout message' do
      em do
        ev = Event.new('', '', '', 1, :auto_renew => false,
                       :before_timeout => 0)
        ev.subscribe do |msg|
          expect(msg).to eq(:timeout)
          done
        end
      end
    end

    it 'should renew subscription on demand' do
      em do
        stub_request(:subscribe, location).
          with(:headers => { 'HOST' => host, 'SID' => sid,
               'TIMEOUT' => "Second-#{ev.timeout}"}).
          to_return(:status => 200,
                    :headers => {
                      'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0',
                      'SID' => sid,
                      'TIMEOUT' => 'Second-1800'
                    })
        ev.renew_subscription
        ev.subscribe do |msg|
          expect(msg).to eq(:renewed)
          expect(ev.timeout).to eq(1800)
          done
        end
      end
    end

    it 'should automatically renew subscription' do
      em do
        stub_request(:subscribe, location).
          with(:headers => { 'HOST' => host, 'SID' => sid,
               'TIMEOUT' => "Second-#{ev.timeout}"}).
          to_return(:status => 200,
                    :headers => {
                      'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0',
                      'SID' => sid,
                      'TIMEOUT' => 'Second-1800'
                    })

        ev.subscribe do |msg|
          expect(msg).to eq(:renewed)
          expect(ev.timeout).to eq(1800)
          done
        end
      end
    end

    it 'should cancel subscription'
  end

end
