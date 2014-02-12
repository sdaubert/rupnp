require_relative '../spec_helper'

def start_server
  EM.start_server('127.0.0.1', RUPNP::EVENT_SUB_DEFAULT_PORT,
                  RUPNP::CP::EventServer)
end


module RUPNP
  module CP

    describe EventServer do
      include EM::SpecHelper

      let(:timeout) { 2 }
      let(:sid) { "uuid:#{UUID.generate}" }
      let(:event) { Event.new('', '', sid, timeout) }
      let(:event_uri) { '/event/1' }
      let(:port) { RUPNP::EVENT_SUB_DEFAULT_PORT }
      let(:req) {EM::HttpRequest.new("http://127.0.0.1:#{port}#{event_uri}")}

      it 'should receive a NOTIFY request'

      it 'should return 404 error on bad HTTP method URI' do
        em do
          start_server

          req = EM::HttpRequest.new("http://127.0.0.1:#{port}/unknown")
          http = send_notify_request(req)
          http.callback do
            expect(http.response_header.status).to eq(404)
            done
          end
        end
      end

      it 'should return 405 error on bad HTTP method' do
        em do
          start_server

          http = req.get
          http.callback do
            expect(http.response_header.status).to eq(405)
            done
          end
        end
      end

      it 'should return 400 error on malformed request' do
        em do
          req2 = req.dup
          EventServer.add_event_url [event_uri, event]
          start_server

          http = send_notify_request(req, :delete => 'NT')
          http.errback { fail 'must not fail!' }
          http.callback do
            expect(http.response_header.status).to eq(400)
            http2 = send_notify_request(req2, :delete => 'NTS')
            http2.callback do
              expect(http2.response_header.status).to eq(400)
              done
            end
          end
        end
      end

      it 'should return 412 error on bad request' do
        em do
          EventServer.add_event_url [event_uri, event]
          start_server
          http = send_notify_request(req, 'SID' => "uuid:#{UUID.generate}")
          http.errback { fail 'must not fail!' }
          http.callback do
            expect(http.response_header.status).to eq(412)
            done
          end
        end

        em do
          EventServer.add_event_url [event_uri, event]
          start_server
          http = send_notify_request(req, 'NT' => "upnp:other")
          http.errback { fail 'must not fail!' }
          http.callback do
            expect(http.response_header.status).to eq(412)
            done
          end
        end


        em do
          EventServer.add_event_url [event_uri, event]
          start_server
          http = send_notify_request(req, 'NTS' => "upnp:other")
          http.errback { fail 'must not fail!' }
          http.callback do
            expect(http.response_header.status).to eq(412)
            done
          end
        end


        em do
          EventServer.add_event_url [event_uri, event]
          start_server
          http = send_notify_request(req, :delete => 'SID')
          http.errback { fail 'must not fail!' }
          http.callback do
            expect(http.response_header.status).to eq(412)
            done
          end
        end
      end

      it "should return updated variables through 'events' channel"
      it 'should serve multiple URLs'
    end

  end
end
