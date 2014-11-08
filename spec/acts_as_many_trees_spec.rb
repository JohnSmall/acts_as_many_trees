require 'rails_helper'

FactoryGirl.define do
  factory :item do
    name 'item'
  end
end
RSpec.describe ActsAsManyTrees do
  describe 'item instance methods' do
    it 'should respond to #children' do
      item = create(:item)
      expect(item).to respond_to(:children)
    end
    it 'should have many closure_tree_links' do
      item = create(:item)
      expect(item).to have_many(:closure_tree_links)
    end
  end
  describe 'item class methods' do
    it 'should respond to acts_as_many_trees' do
      expect(Item).to respond_to(:acts_as_many_trees)
    end
  end
end
