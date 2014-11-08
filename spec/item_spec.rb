require 'rails_helper'

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
      expect(@items[1].unscoped_ancestors.pluck(:id).sort).to eq([@items[2].id,@items[3].id])
    end

    it 'should set the join child ancestors to new parent ancestors' do
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
      @items[2].parent = @items[3]
      @items[1].parent = @items[2]
      @items[4].parent = @items[5]
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

  end
end

