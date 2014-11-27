require 'rails_helper'
require 'support/utils'
describe Item do
    let(:sub_item){build(:sub_item)}
    it 'should respond to parent' do
      expect(sub_item).to respond_to(:parent)
    end

end
