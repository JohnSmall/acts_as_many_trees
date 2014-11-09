require 'rails_helper'


RSpec.describe 'order by position' do
   describe 'set the position in the hierarchy' do
     let(:items){create_list(:item,5)}
     let(:lots_of_items){create_list(:item,10)}
     it 'should put a new record at the end' do
       items[4].parent=items[1]
       items[3].parent=items[1]
       items[2].parent=items[1]
       expect(items[1].children.pluck(:id)).to eq([4,3,2].map{|n| items[n].id})
    end
     it 'should allow a new record at the begining' do
       items[4].parent=items[1]
       items[3].parent={new_parent:items[1],before_node:items[4]}
       items[2].parent={new_parent:items[1],before_node:items[3]}
       expect(items[1].children.pluck(:id)).to eq([2,3,4].map{|n| items[n].id})
     end
     it 'should allow a new record between two siblings' do
       items[4].parent=items[1]
       items[3].parent={new_parent:items[1],before_node:items[4]}
       items[2].parent={new_parent:items[1],before_node:items[3]}
       items[0].parent={new_parent:items[1],before_node:items[4],after_node:items[3]}
       expect(items[1].children.pluck(:id)).to eq([2,3,0,4].map{|n| items[n].id})
     end
     it 'should put a last record between two roots' do

     end
     it 'should move all descendants when the parent moves'
     it 'should reset all position number when requested'
   end
end
