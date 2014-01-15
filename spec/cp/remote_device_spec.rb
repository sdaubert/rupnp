require_relative '../spec_helper'

module RUPNP
  module CP

    describe RemoteDevice do
      include EM::SpecHelper

      context '#fetch' do
        it "should fetch its description"
        it "should fail when notification has no BOOTID.UPNP.ORG field"
        it "should fail when location is unreachable"
        it "should fail when description is not a UPnP 1.x response"
        it "should fail when description is blank"
        it "should fail when description is not conform to UPnP specifications"
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
