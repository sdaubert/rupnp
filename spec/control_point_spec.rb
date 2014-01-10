require_relative 'spec_helper'

module RUPNP

  describe ControlPoint do
    include EM::SpecHelper

    it 'should initialize a new instance' do
      cp = ControlPoint.new(:all)
      expect(cp.devices).to be_a(Array)
      expect(cp.devices).to be_empty
    end

    it '#search_only should detect devices'
    it '#start should detect devices'
    it '#start should listen for update or byebye notifications from devices'
    it '#find_device_by_udn should get known devices'
  end

end

