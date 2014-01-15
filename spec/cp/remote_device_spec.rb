require_relative '../spec_helper'

module RUPNP
  module CP

    describe RemoteDevice do
      include EM::SpecHelper

      let(:notification) { {
          'cache-control' => 'max-age=1800',
          'date' => Time.now.strftime("%a, %d %b %Y %H:%M:%S %Z"),
          'ext' => '',
          'location' => 'http://127.0.0.1/root_description.xml',
          'server' => 'OS/1.0 UPnP/1.1 TEST/1.0',
          'st' => 'upnp:rootdevice',
          'usn' =>  "uuid:#{UUID.generate}::upnp:rootdevice",
          'bootid.upnp.org' => 10,
          'confid.upnp.org' => 23,
        } }
      let(:rd) { RemoteDevice.new(double('control_point'), notification)}

      context '#fetch' do

        it "should fail when notification has no BOOTID.UPNP.ORG field" do
          notification.delete 'bootid.upnp.org'
          em do
            rd.errback { done }
            rd.callback { fail 'RemoteDevice#fetch should not work' }
            rd.fetch
          end
        end

        it "should fail when location is unreachable"
        it "should fail when description is not a UPnP 1.x response"
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
