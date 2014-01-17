require_relative '../spec_helper'

module RUPNP
  module CP

    describe RemoteDevice do
      include EM::SpecHelper

      let(:location) { 'http://127.0.0.1:1234/root_description.xml' }
      let(:uuid) { UUID.generate }
      let(:notification) { {
          'cache-control' => 'max-age=1800',
          'date' => Time.now.strftime("%a, %d %b %Y %H:%M:%S %Z"),
          'ext' => '',
          'location' => location,
          'server' => 'OS/1.0 UPnP/1.1 TEST/1.0',
          'st' => 'upnp:rootdevice',
          'usn' =>  "uuid:#{uuid}::upnp:rootdevice",
          'bootid.upnp.org' => 10,
          'confid.upnp.org' => 23,
        } }
      let(:rd) { RemoteDevice.new(double('control_point'), notification)}

      context '#fetch' do

        it "should fail when notification has no BOOTID.UPNP.ORG field" do
          notification.delete 'bootid.upnp.org'
          em do
            rd.errback do |dev, msg|
              expect(dev).to eq(rd)
              expect(msg).to match(/no BOOTID/)
              done
            end
            rd.callback { fail 'RemoteDevice#fetch should not work' }
            rd.fetch
          end
        end

        it "should fail when location is unreachable" do
          em do
            stub_request(:get, location).to_timeout
            rd.errback do |dev, msg|
              expect(dev).to eq(rd)
              expect(msg).to match(/Failed getting description/)
              done
            end
            rd.callback { fail 'RemoteDevice#fetch should not work' }
            rd.fetch
          end
        end

        it "should fail when description header is not a UPnP 1.x response" do
          em do
            stub_request(:get, location).
              to_return(:body => generate_xml_device_description(uuid),
                        :headers => { 'SERVER' => 'Linux/1.2 Apache/1.0' })

            rd.errback do |dev, msg|
              expect(dev).to eq(rd)
              expect(msg).to match(/Failed getting description/)

              desc = generate_xml_device_description(uuid, :spec_major => 0)
              stub_request(:get, location).
                to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/0.9 TEST/1.0'},
                          :body => desc)

              rd.errback do |dev, msg|
                expect(dev).to eq(rd)
                expect(msg).to match(/Failed getting description/)
                done
              end
              rd.fetch
            end
            rd.callback { fail 'RemoteDevice#fetch should not work' }
            rd.fetch
          end
        end

        it "should fail when description is blank"
        it "should fail when description is not conform to UPnP specifications"
        it "should fetch its description"
        it "should extract services if any"
        it "should not fail when a service cannot be extracted"
      end

      context "#update" do
        it 'should update expiration date'
        it 'should update BOOTID'
        it 'should update CONFIGID.UPNP.ORG'
      end

    end

  end
end
