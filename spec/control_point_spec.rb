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
      em do
        uuid1 = UUID.generate
        generate_search_responder uuid1, 1234
        generate_search_responder uuid1, 1234
        uuid2 = UUID.generate
        generate_search_responder uuid2, 1235

        stub_request(:get, '127.0.0.1:1234').to_return :headers => {
          'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'
        }, :body => generate_xml_device_description(uuid1)
        stub_request(:get, '127.0.0.1:1235').to_return :headers => {
          'SERVER' => 'OS/1.0 UPnP/1.1 TEST/1.0'
        }, :body => generate_xml_device_description(uuid2)

        cp.search_only

        EM.add_timer(1) do
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

