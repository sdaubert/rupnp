require_relative 'spec_helper'

module RUPNP

  describe Event do
    include EM::SpecHelper

    it 'should send timeout message' do
      em do
        ev = Event.new('', '', '', 1, :auto_renew => false,
                       :before_timeout => 0)
        ev.subscribe do |msg|
          expect(msg).to eq(:timeout)
          done
        end
      end
    end

    it 'should renew subscription on demand'
    it 'should automatically renew subscription'
    it 'should cancel subscription'
  end

end
