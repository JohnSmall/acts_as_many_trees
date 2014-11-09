require 'rails_helper'
require 'support/utils'
describe Item do
  describe 'the methods required' do
    let(:item){build(:item)}
    it 'should respond to parent' do
      expect(item).to respond_to(:parent)
    end
  end
  describe 'add parent' do
    before(:each){@items = create_list(:item,6)}
    it 'should set the parent' do
      @items[1].parent = @items[2]
      expect(@items[1].parent).to eq(@items[2])
    end

    it 'should set the new ancestors when the parent moves' do
      @items[1].parent = @items[2]
      @items[2].parent = @items[3]
      expect(@items[1].ancestors.pluck(:id).sort).to eq([@items[2].id,@items[3].id])
    end

    it 'should set ancestors of the descendants to the new parent ancestors' do
      @items[0].parent = @items[1]
      @items[2].parent = @items[3]
      @items[1].parent = @items[2]
      expect(@items[0].ancestors.pluck(:id).sort).to eq([@items[1].id,@items[2].id,@items[3].id])
    end

    it 'should remove old ancestor when setting a new parent' do
      @items[0].parent = @items[1]
      @items[2].parent = @items[3]
      @items[1].parent = @items[2]
      @items[4].parent = @items[5]
      @items[4].parent = @items[0]
      expect(@items[4].ancestors.pluck(:id)).not_to include(@items[5].id)
    end

    it 'should set the grandparent' do
      @items[2].parent = @items[3]
      @items[1].parent = @items[2]
      expect(@items[1].ancestors.pluck(:id).sort).to eq([@items[2].id,@items[3].id])
    end


    it 'should allow setting the parent to nil' do
      @items[0].parent = @items[1]
      @items[2].parent = @items[3]
      @items[2].parent = nil
      expect(@items[2].ancestors.pluck(:id)).to be_empty
    end

    it 'should delete the old ancestors of children when the parent is set to nil' do
      @items[0].parent = @items[2]
      @items[2].parent = @items[3]
      @items[2].parent = nil
      expect(@items[0].ancestors.pluck(:id)).not_to include(@items[3].id)
    end

    it 'should keep child ancestor as me when my parent is set to nil' do
      @items[0].parent = @items[2]
      @items[2].parent = @items[3]
      @items[2].parent = nil
      expect(@items[0].ancestors.pluck(:id)).to include(@items[2].id)
    end

    it 'should list the roots' do
      @items[0].parent = @items[1]
      @items[1].parent = @items[2]
      @items[2].parent = @items[3]
      @items[4].parent = @items[5]
      expect(Item.roots.pluck(:id).sort).to eq([@items[3].id,@items[5].id])
    end

    it 'should list the roots when added in a different order' do
      @items[0].parent = @items[1]
      @items[2].parent = @items[3]
      @items[4].parent = @items[5]
      @items[1].parent = @items[2]
      expect(Item.roots.pluck(:id).sort).to eq([@items[3].id,@items[5].id])
    end

    it 'should not allow loops' do
      @items[0].parent = @items[1]
      @items[1].parent = @items[2]
      @items[2].parent = @items[3]
      @items[3].parent = @items[4]
      @items[4].parent = @items[5]
      expect{
        @items[5].parent = @items[0]}.to raise_error
    end

    describe 'with scopes' do
    it 'should list the roots' do
      @items[0].set_parent( @items[1],'a')
      @items[2].set_parent( @items[3],'a')
      @items[1].set_parent( @items[2],'a')
      @items[4].set_parent( @items[5],'a')
      expect(Item.roots('a').pluck(:id).sort).to eq([@items[3].id,@items[5].id])
    end

    it 'should have different roots for different scopes' do
      #hierarchy scope = 'a'
      @items[0].set_parent( @items[1],'a')
      @items[2].set_parent( @items[3],'a')
      @items[1].set_parent( @items[2],'a')
      @items[4].set_parent( @items[5],'a')

      #hierarchy scope = 'b'
      @items[1].set_parent( @items[0],'b')
      @items[3].set_parent( @items[2],'b')
      @items[2].set_parent( @items[1],'b')
      @items[5].set_parent( @items[4],'b')
      expect(Item.roots('a').pluck(:id).sort).to eq([@items[3].id,@items[5].id])
      expect(Item.roots('b').pluck(:id).sort).to eq([@items[0].id,@items[4].id])
    end

    it 'should set the parent' do
      @items[1].set_parent(@items[2],'a')
      @items[1].set_parent(@items[3],'b')
      expect(@items[1].parent('a')).to eq(@items[2])
      expect(@items[1].parent('b')).to eq(@items[3])
    end
    it 'should set the new ancestors when the parent moves' do
      @items[1].set_parent(@items[2],'a')
      @items[2].set_parent(@items[3],'a')
      expect(@items[1].ancestors('a').pluck(:id).sort).to eq([@items[2].id,@items[3].id])
    end

    it 'should set ancestors of the descendants to the new parent ancestors' do
      @items[0].set_parent(@items[1],'a')
      @items[2].set_parent(@items[3],'a')
      @items[1].set_parent(@items[2],'a')
      expect(@items[0].ancestors('a').pluck(:id).sort).to eq([@items[1].id,@items[2].id,@items[3].id])
    end

    it 'should remove old ancestor when setting a new parent' do
      @items[0].set_parent(@items[1],'a')
      @items[2].set_parent(@items[3],'a')
      @items[1].set_parent(@items[2],'a')
      @items[4].set_parent(@items[5],'a')
      @items[4].set_parent(@items[0],'a')
      expect(@items[4].ancestors('a').pluck(:id)).not_to include(@items[5].id)
    end

    it 'should set the grandparent' do
      @items[2].set_parent(@items[3],'a')
      @items[1].set_parent(@items[2],'a')
      expect(@items[1].ancestors('a').pluck(:id).sort).to eq([@items[2].id,@items[3].id])
    end


    it 'should allow setting the parent to nil' do
      @items[0].set_parent(@items[1],'a')
      @items[2].set_parent(@items[3],'a')
      @items[0].set_parent(@items[1],'b')
      @items[2].set_parent(@items[3],'b')
      @items[2].set_parent(nil,'a')
      expect(@items[2].ancestors('a').pluck(:id)).to be_empty
      expect(@items[2].ancestors('b').pluck(:id)).not_to be_empty
    end

      
    end

  end
end

