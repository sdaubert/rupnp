require_relative '../spec_helper'
module RUPNP
  module CP

    describe RemoteDevice do
      include EM::SpecHelper

      context '#fetch' do

        it 'should fetch SCPD'
        it 'should set state table'
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
