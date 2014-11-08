require 'rails_helper'

FactoryGirl.define do
  factory :item do
    name 'item'
  end
end
RSpec.describe ActsAsManyTrees do
  describe Item do
    it 'should respond to #children' do
      item = create(:item)
      expect(item).to respond_to(:children)
    end
    it 'should have many closure_tree_links' do
      item = create(:item)
      expect(item).to respond_to( :unscoped_ancestor_links)
    end
    it 'should point unscoped_ancestor_links to ItemHierarchies' do
      item = create(:item)
      expect(item.unscoped_ancestor_links.klass).to be(ItemHierarchy)
    end
  end
  describe 'item class methods' do
    it 'should respond to acts_as_many_trees' do
      expect(Item).to respond_to(:acts_as_many_trees)
    end
    it 'should respond to hierarchy_class' do
      expect(Item).to respond_to(:hierarchy_class)
    end
    it 'should respond to hierarchy_table_name' do
      expect(Item).to respond_to(:hierarchy_table_name)
    end

    it 'the hierarchy class exists' do
      expect(Item.hierarchy_class).to be(ItemHierarchy)
    end
  end
end
