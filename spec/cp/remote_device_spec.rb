require_relative '../spec_helper'

module RUPNP
  module CP

    describe RemoteDevice do
      include EM::SpecHelper

      DESCRIPTIONS =
        ['this is not a UPnP description',
         '<?xml version="1.0"?><tag>UPnP</tag>',
         '<?xml version="1.0"?><root xmlns="urn:schemas-upnp-org:device-0-9" configId="1"></root>',
         '<?xml version="1.0"?><root xmlns="urn:schemas-upnp-org:device-1-0" configId="1"></root>',
         '<?xml version="1.0"?><root xmlns="urn:schemas-upnp-org:device-1-0" configId="1"><spec_version></spec_version></root>',
         '<?xml version="1.0"?><root xmlns="urn:schemas-upnp-org:device-1-0" configId="1"><spec_version><major>0</major><minor>9</minor></spec_version></root>',
         '<?xml version="1.0"?><root xmlns="urn:schemas-upnp-org:device-1-0" configId="1"><spec_version><major>1</major><minor>9</minor></spec_version></root>',
         '<?xml version="1.0"?><root xmlns="urn:schemas-upnp-org:device-1-0" configId="1"><spec_version><major>1</major><minor>9</minor></spec_version><device></device></root>']


      let(:location) { 'http://127.0.0.1:1234/root_description.xml' }
      let(:uuid) { UUID.generate }
      let(:max_age) { 1800 }
      let(:notification) { {
          'cache-control' => "max-age=#{max_age}",
          'date' => Time.now.strftime("%a, %d %b %Y %H:%M:%S %Z"),
          'ext' => '',
          'location' => location,
          'server' => 'OS/1.0 UPnP/1.1 TEST/1.0',
          'st' => 'upnp:rootdevice',
          'usn' =>  "uuid:#{uuid}::upnp:rootdevice",
          'bootid.upnp.org' => 10,
          'configid.upnp.org' => 23,
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

        it "should accept headers without BOOTID for UPnP 1.0 response" do
          notification.delete 'bootid.upnp.org'
          notification['server'] = 'OS/1.0 UPnP/1.0 TEST/1.0'
          em do
            stub_request(:get, location).
              to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.0 TEST/1.0'},
                          :body => generate_device_description(uuid))
            rd.errback { fail 'RemoteDevice#fetch should work' }
            rd.callback { done }
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
          desc = generate_device_description(uuid)
          em do
            stub_request(:get, location).
              to_return(:body => generate_device_description(uuid),
                        :headers => { 'SERVER' => 'Linux/1.2 Apache/1.0' },
                        :body => desc)

            rd.errback do |dev, msg|
              expect(dev).to eq(rd)
              expect(msg).to match(/Failed getting description/)

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

        it "should fail when description does not conform to UPnP spec" do
          DESCRIPTIONS.each do |desc|
            em do
              stub_request(:get, location).
                to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                          :body => desc)

              rd.errback do |dev, msg|
                expect(dev).to eq(rd)
                expect(msg).to match(/Bad description/)
                done
              end
              rd.callback { fail 'RemoteDevice#fetch should not work' }
              rd.fetch
            end
          end
        end

        it "should fetch its description" do
          em do
            stub_request(:get, location).
              to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                          :body => generate_device_description(uuid))
            rd.errback { fail 'RemoteDevice#fetch should work' }
            rd.callback do
              done
            end
            rd.fetch
          end
        end

        it "should extract services if any" do
          dev_desc = generate_device_description(uuid, :device_type => 'MediaServer')
          scpd = generate_scpd
          em do
            stub_request(:get, location).
              to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                        :body => dev_desc)
            stub_request(:get, 'http://127.0.0.1:1234/cd/description.xml').
              to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                        :body => scpd)
            stub_request(:get, 'http://127.0.0.1:1234/cd/control').
              to_return(:status => 404)

            rd.errback { |d, msg| fail msg }
            rd.callback do
              expect(rd.services).to have(1).item
              done
            end
            rd.fetch
          end
        end

        it "should not fail when a service cannot be extracted" do
          dev_desc = generate_device_description(uuid, :device_type => 'MediaServer')
          em do
            stub_request(:get, location).
              to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                        :body => dev_desc)
            stub_request(:get, 'http://127.0.0.1:1234/cd/description.xml').
              to_return(:status => 404)

            rd.errback { |d, msg| fail msg }
            rd.callback do
              expect(rd.services).to have(0).item
              done
            end
            rd.fetch
          end
        end

      end

      context "#update" do
        it 'should update expiration date' do
          em do
            stub_request(:get, location).
              to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'},
                        :body => generate_device_description(uuid))
            rd.errback { fail 'RemoteDevice#fetch should work' }
            rd.callback do
              not2 = notification.dup
              expiration_old = Time.parse(notification['date']) + max_age

              not2['date'] = (Time.now + 5).strftime("%a, %d %b %Y %H:%M:%S %Z")
              expiration_new = Time.parse(not2['date']) + max_age

              expect(not2['date']).not_to eq(notification['date'])
              expect { rd.update(not2) }.to change { rd.expiration }.
                from(expiration_old).to(expiration_new)
              done
            end
            rd.fetch
          end
        end

        it 'should update BOOTID' do
          em do
            stub_request(:get, location).
              to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0' },
                        :body => generate_device_description(uuid))
            rd.errback { fail 'RemoteDevice#fetch should work' }
            rd.callback do
              not2 = notification.merge('nextbootid.upnp.org' => 15)
              expect { rd.update(not2) }.to change{ rd.boot_id }.from(10).to(15)
              done
            end
            rd.fetch
          end
        end


        it 'should update CONFIGID.UPNP.ORG' do
          em do
            stub_request(:get, location).
              to_return(:headers => { 'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0' },
                        :body => generate_device_description(uuid))
            rd.errback { fail 'RemoteDevice#fetch should work' }
            rd.callback do
              not2 = notification.merge('configid.upnp.org' => 47)
              expect { rd.update(not2) }.to change{ rd.config_id }.
                from(23).to(47)
              done
            end
            rd.fetch
          end
        end
      end

    end

  end
end
