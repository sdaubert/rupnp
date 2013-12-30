require_relative 'spec_helper'


module RUPNP

  describe Device do

    context "#initialize" do
      let(:config) do
        Hash[Device::CONFIG[:required].map { |item| [item, 'value'] }]
      end

      it "should raise DeviceInitializationError if misconfigured" do
        Device::CONFIG[:required].each do |item|
          cfg = config.dup
          cfg.delete(item)
          expect { Device.new(cfg) }.to raise_error(DeviceInitializationError)
        end

        expect { Device.new(config) }.not_to raise_error
      end

      it "should generate a unique UID" do
        d1 = Device.new(config)
        d2 = Device.new(config)
        expect(d1.uuid).not_to eq(d2.uuid)
      end

      it "should use given UUID if configured for that" do
        d1 = Device.new(config)
        config[:uuid] = d1.uuid
        d2 = Device.new(config)
        expect(d1.uuid).to eq(d2.uuid)
      end
    end

  end

end
