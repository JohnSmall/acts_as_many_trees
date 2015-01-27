require 'rails_helper'


RSpec.describe 'order by position' do
   describe 'set the position in the hierarchy' do
     let(:items){create_list(:item,9)}
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
     
     it 'should have self and siblings' do
       items[1].parent = items[0]
       items[2].parent = items[0]
       items[3].parent = items[0]
       expect(items[2].self_and_siblings.pluck(:id)).to eq([1,2,3].map{|i| items[i].id})
     end
     
     it 'should have siblings' do
       items[1].parent = items[0]
       items[2].parent = items[0]
       items[3].parent = items[0]
       set_logging_on
       expect(items[2].siblings.pluck(:id)).to eq([items[1].id,items[3].id])
     end
     
     it 'should have a previous sibling' do
       items[1].parent = items[0]
       items[2].parent = items[0]
       items[3].parent = items[0]
       expect(items[2].previous_sibling.id).to eq(items[1].id)
     end

     it 'should have a next sibling' do
       items[1].parent = items[0]
       items[2].parent = items[0]
       items[3].parent = items[0]
       expect(items[2].next_sibling.id).to eq(items[3].id)
     end

     it 'should put a last child in place before the next root' do
       items[1].parent = items[0]
       items[2].parent = items[0]
       items[3].parent = items[1]
       items[4].parent = items[1]
       items[5].parent = items[2]
       items[6].parent = items[2]
       items[7].parent = items[1]
       expect(items[0].descendants.pluck(:id)).to eq([1,3,4,7,2,5,6].map{|i| items[i].id})
     end

#     it 'should move all descendants when the parent moves'
#     it 'should reset all position number when requested'
   end
end
