require_relative 'spec_helper'

module RUPNP

  describe ControlPoint do
    include EM::SpecHelper

    let(:cp) { ControlPoint.new(:all) }

    it 'should initialize a new instance' do
      expect(cp.devices).to be_a(Array)
      expect(cp.devices).to be_empty
    end

    it '#search_only should detect devices' do
      # TODO: use webmock to catch HTTP request getting device description
      em do
        uuid = UUID.generate
        generate_search_responder uuid
        generate_search_responder uuid
        uuid = UUID.generate
        generate_search_responder uuid

        cp.search_only

        EM.add_timer(1) do
          p cp.devices
          expect(cp.devices).to have(2).item
          done
        end
      end
    end

    it '#start should detect devices'
    it '#start should listen for update or byebye notifications from devices'
    it '#find_device_by_udn should get known devices'
  end

end

