require 'rails_helper'


RSpec.describe 'order by position' do
   describe 'set the position in the hierarchy' do
     let(:items){create_list(:item,5)}
     it 'should put a new record at the end' do
       items[4].parent=items[1]
       items[3].parent=items[1]
       items[2].parent=items[1]
       expect(items[1].children.pluck(:id)).to eq([4,3,2].map{|n| items[n].id})
    end
     it 'should allow a new record at be begining'
     it 'should allow a new record between two siblings'
     it 'should move all descendants when the parent moves'
     it 'should reset all position number when requested'
   end
end
