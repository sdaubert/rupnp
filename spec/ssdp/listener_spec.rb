require_relative '../spec_helper'

module RUPNP
  module SSDP

    describe Listener do
      include EM::SpecHelper

      it "should receive alive and byebye notifications"
      it "should ignore M-SEARCH requests"
      it "should ignore and log unknown requests"
    end

  end
end
