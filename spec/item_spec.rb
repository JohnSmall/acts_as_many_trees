require 'rails_helper'
require 'support/utils'
describe Item do
  describe 'the methods required' do
    let(:item){build(:item)}
    it 'should respond to parent' do
      expect(item).to respond_to(:parent)
    end
    it 'should respond to self_and_ancestors' do
      expect(item).to respond_to(:self_and_ancestors)
    end
    it 'should respond to self_and_descendants' do
      expect(item).to respond_to(:self_and_descendants)
    end
  end
  describe 'add parent' do
    before(:each){@items = create_list(:item,10)}
    it 'should set the parent' do
      @items[1].parent = @items[2]
      expect(@items[1].parent).to eq(@items[2])
    end

    it 'should include itself in self_and_ancestors' do
      @items[1].parent = @items[2]
      expect(@items[1].self_and_ancestors.pluck(:id)).to match_array([1,2].map{|i| @items[i].id}.sort) 
    end

    it 'should set generation=0 in for self in self_and_ancestors' do
      @items[1].parent = @items[2]
      expect(@items[1].self_and_ancestors.pluck(:generation)).to match_array([0,1]) 
    end

    it 'should include itself in self_and_ancestors when the parent moves' do
      @items[1].parent = @items[2]
      @items[2].parent = @items[3]
      expect(@items[1].self_and_ancestors.pluck(:id).sort).to include(@items[1].id) 
    end

    it 'should set the new ancestors when the parent moves' do
      @items[1].parent = @items[2]
      @items[2].parent = @items[3]
      expect(@items[1].ancestors.pluck(:id)).to match_array([@items[2].id,@items[3].id])
    end

    it 'should set ancestors of the descendants to the new parent ancestors' do
      @items[0].parent = @items[1]
      @items[2].parent = @items[3]
      @items[1].parent = @items[2]
      expect(@items[0].ancestors.pluck(:id)).to match_array([@items[1].id,@items[2].id,@items[3].id])
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
      expect(@items[1].ancestors.pluck(:id)).to match_array([@items[2].id,@items[3].id])
    end

    it 'should create sub-trees all the way down' do
      # we had a problem where the sub-trees were being deleted but it only showed up on the third level and beyond
      @items[2].parent = @items[1]
      @items[3].parent = @items[2]
      @items[4].parent = @items[3]
      @items[5].parent = @items[4]
      @items[6].parent = @items[5]
      @items[7].parent = @items[6]
      @items[8].parent = @items[7]
      @items[9].parent = @items[8]
      @items[1].parent = @items[0]
      (0..9).each do |i|
        (i..9).each do |j|
          expect(@items[i].self_and_descendants).to include(@items[j]),"item[#{i}] should have item[#{j}] as a descendant"
        end
      end
    end
    it 'should create ancestors all the way up' do
      # we had a problem where the sub-trees were being deleted but it only showed up on the third level and beyond
      @items[2].parent = @items[1]
      @items[3].parent = @items[2]
      @items[4].parent = @items[3]
      @items[5].parent = @items[4]
      @items[6].parent = @items[5]
      @items[7].parent = @items[6]
      @items[8].parent = @items[7]
      @items[9].parent = @items[8]
      @items[1].parent = @items[0]
      (0..9).each do |i|
        (i..9).each do |j|
          expect(@items[j].self_and_ancestors).to include(@items[i]),"item[#{j}] should have item[#{i}] as a descendant"
        end
      end
    end
    it 'should have only two roots' do
      # we had a problem where the sub-trees weren't being copied but it only showed up on the third level and beyond
      @items[1].parent = @items[0]
      @items[2].parent = @items[1]
      @items[3].parent = @items[2]
      @items[4].parent = @items[3]

      @items[6].parent = @items[5]
      @items[7].parent = @items[6]
      @items[8].parent = @items[7]
      @items[9].parent = @items[8]
      expect(@items[0].class.roots.pluck(:id)).to match_array([@items[0].id,@items[5].id])
    end


    it 'should allow setting the parent to nil' do
      @items[0].parent = @items[2]
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

    it 'should let the parent add a child' do
      @items[0].add_child(@items[1])
      expect(@items[0].children.pluck(:id)).to eq [@items[1].id]
    end

    it 'should make the parent a root even if the child is nil' do
      @items[0].add_child(nil)
      expect(Item.roots.pluck(:id)).to include(@items[0].id)
    end

    it 'should list the roots' do
      # @items[2].parent = @items[3]
      # @items[0].parent = @items[1]
      # @items[1].parent = @items[2]
      # @items[4].parent = @items[5]
      #ItemHierarchy.debug_tree
      @items[2].parent = @items[1]
      @items[3].parent = @items[2]

      @items[7].parent = @items[6]
      @items[6].parent = @items[5]
      @items[9].parent = @items[8]
      @items[8].parent = @items[7]
      @items[4].parent = @items[0]
      @items[1].parent = @items[0]
      expect(Item.roots.pluck(:id)).to match_array([@items[0].id,@items[5].id])
    end

    it 'should list the roots when added in a different order' do
      @items[0].parent = @items[1]
      @items[2].parent = @items[3]
      @items[4].parent = @items[5]
      @items[1].parent = @items[2]
      expect(Item.roots.pluck(:id)).to match_array([@items[3].id,@items[5].id])
    end

    it 'should list the roots when added in a different order' do
      @items[0].parent = @items[1]
      @items[2].parent = @items[3]
      @items[4].parent = @items[5]
      @items[1].parent = @items[2]
      (6..9).each{|n| @items[n].parent=@items[n-1]}
      expect(Item.roots.pluck(:id)).to match_array([@items[3].id,@items[5].id])
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

    it 'each item should have a child' do
      # this test was created while debugging that children were being lost in some generations
      @items[0].parent = @items[1]
      @items[1].parent = @items[2]
      @items[2].parent = @items[3]
      @items[3].parent = @items[4]
      @items[4].parent = @items[5]
       (1..5).each do |i|
         expect(@items[i].children.count).to eq(1),"item #{i} did not have a child"
       end
    end

    describe 'self_and_ancestors' do
      it 'should include self in self and ancestors' do
        @items[1].parent = @items[0]
        @items[2].parent = @items[1]
        expect(@items[2].self_and_ancestors.pluck(:id).sort).to include(@items[2].id)
      end
    end

    describe 'with scopes' do
      it 'should list the roots' do
        @items[0].set_parent(new_parent:  @items[1],tree_name:'a',existing_tree:'a')
        @items[2].set_parent(new_parent:  @items[3],tree_name:'a',existing_tree:'a')
        @items[1].set_parent(new_parent:  @items[2],tree_name:'a',existing_tree:'a')
        @items[4].set_parent(new_parent:  @items[5],tree_name:'a',existing_tree:'a')
        expect(Item.roots('a').pluck(:id)).to match_array([@items[3].id,@items[5].id])
      end

      it 'should have different roots for different scopes' do
        #hierarchy scope = 'a'
        @items[0].set_parent(new_parent:  @items[1],tree_name:'a',existing_tree:'a')
        @items[2].set_parent(new_parent:  @items[3],tree_name:'a',existing_tree:'a')
        @items[1].set_parent(new_parent:  @items[2],tree_name:'a',existing_tree:'a')
        @items[4].set_parent(new_parent:  @items[5],tree_name:'a',existing_tree:'a')

        #hierarchy scope = 'b'
        @items[1].set_parent(new_parent:  @items[0],tree_name:'b',existing_tree:'b')
        @items[3].set_parent(new_parent:  @items[2],tree_name:'b',existing_tree:'b')
        @items[2].set_parent(new_parent:  @items[1],tree_name:'b',existing_tree:'b')
        @items[5].set_parent(new_parent:  @items[4],tree_name:'b',existing_tree:'b')
        expect(Item.roots('a').pluck(:id)).to match_array([@items[3].id,@items[5].id])
        expect(Item.roots('b').pluck(:id)).to match_array([@items[0].id,@items[4].id])
      end

      it 'should set the parent' do
        @items[1].set_parent(new_parent: @items[2],tree_name:'a',existing_tree:'a')
        @items[1].set_parent(new_parent: @items[3],tree_name:'b',existing_tree:'b')
        expect(@items[1].parent('a').id).to eq(@items[2].id)
        expect(@items[1].parent('b').id).to eq(@items[3].id)
      end
      it 'should set the new ancestors when the parent moves' do
        @items[1].set_parent(new_parent: @items[2],tree_name:'a',existing_tree:'a')
        @items[2].set_parent(new_parent: @items[3],tree_name:'a',existing_tree:'a')
        expect(@items[1].ancestors('a').pluck(:id)).to match_array([@items[2].id,@items[3].id])
      end

      it 'should set ancestors of the descendants to the new parent ancestors' do
        @items[0].set_parent(new_parent: @items[1],tree_name:'a',existing_tree:'a')
        @items[2].set_parent(new_parent: @items[3],tree_name:'a',existing_tree:'a')
        @items[1].set_parent(new_parent: @items[2],tree_name:'a',existing_tree:'a')
        expect(@items[0].ancestors('a').pluck(:id)).to match_array([@items[1].id,@items[2].id,@items[3].id])
      end

      it 'should remove old ancestor when setting a new parent' do
        @items[0].set_parent(new_parent: @items[1],tree_name:'a',existing_tree:'a')
        @items[2].set_parent(new_parent: @items[3],tree_name:'a',existing_tree:'a')
        @items[1].set_parent(new_parent: @items[2],tree_name:'a',existing_tree:'a')
        @items[4].set_parent(new_parent: @items[5],tree_name:'a',existing_tree:'a')
        @items[4].set_parent(new_parent: @items[0],tree_name:'a',existing_tree:'a')
        expect(@items[4].ancestors('a').pluck(:id)).not_to include(@items[5].id)
      end

      it 'should set the grandparent' do
        @items[2].set_parent(new_parent: @items[3],tree_name:'a',existing_tree:'a')
        @items[1].set_parent(new_parent: @items[2],tree_name:'a',existing_tree:'a')
        expect(@items[1].ancestors('a').pluck(:id)).to match_array([@items[2].id,@items[3].id])
      end

      it 'should accept the scope from the parent' do
        named_item = create(:named_item)
        @items[0].parent = named_item
        expect(named_item.children(named_item.default_tree_name).pluck(:id)).to match_array([@items[0].id])
      end

      it 'should use a default named scope for the childen' do
        named_item = create(:named_item)
        @items[0].parent = named_item
        expect(named_item.children).to include(@items[0])
      end

      context 'copy a single item' do
        let(:named_items){create_list(:named_item,2)}
        before(:each) do
          @items[2].parent = @items[1]
          named_items[0].parent = named_items[1]
          @items[3].parent = @items[2]
          @items[1].parent = @items[0]
          @items[0].parent = named_items[0]
        end
        it 'should have just one descendant' do
           expect(named_items[0].descendants.pluck(:id)).to match_array([@items[0].id])
        end

        it 'the grand-parent should have two descendants' do
           expect(named_items[1].descendants.pluck(:id)).to match_array([@items[0].id,named_items[0].id])
        end
      end
      context 'copy a complete sub-tree' do
        let(:named_item){create(:named_item)}
        before(:each) do
          @items[2].parent = @items[1]
          @items[3].parent = @items[2]
          @items[1].parent = @items[0]
          @items[0].set_parent(clone_sub_tree:true,new_parent:named_item,tree_name:named_item.default_tree_name)
        end

        it 'should have the named item as parent' do
          # puts named_item.id
          # ItemHierarchy.debug_tree(named_item.default_tree_name)
          (0..0).each do | i |
            expect(@items[i].self_and_ancestors(named_item.default_tree_name).pluck(:id)).to include(named_item.id)
          end
        end

        it 'should match all the way down' do
          # ItemHierarchy.debug_tree(named_item.default_tree_name)
          # puts named_item.id
          (0..2).each do |i|
            (i..2).each do |j|
              # puts "i=#{i} #{@items[i].id} j=#{j} #{@items[j].id}"
              expect(@items[i].self_and_descendants(named_item.default_tree_name)).to include(@items[j]),"item[#{i}] should have item[#{j}] as a descendant"
            end
          end
        end

        it 'should match going back up' do
          (0..3).each do |i|
            (i..3).each do |j|
              # puts "i=#{i} j=#{j}"
              expect(@items[j].self_and_ancestors(named_item.default_tree_name)).to include(@items[i]),"item[#{j}] should have item[#{i}] as an ancestor"
            end
          end
        end

        it 'should only have one child' do
          expect(named_item.children).not_to include(@items[1])
        end
      end

      it 'sub-trees should maintain the default scope' do
        @items[1].parent = @items[0]
        @items[2].parent = @items[1]
        named_item = create(:named_item)
        @items[0].parent = named_item
        expect(@items[0].descendants).to include(@items[2])
      end

      it 'should allow setting the parent to nil' do
        @items[0].set_parent(new_parent: @items[1],tree_name: 'a',existing_tree: 'a')
        @items[2].set_parent(new_parent: @items[3],tree_name:'a',existing_tree:'a')
        @items[0].set_parent(new_parent: @items[1],tree_name:'b',existing_tree:'b')
        @items[2].set_parent(new_parent: @items[3],tree_name:'b',existing_tree:'b')
        @items[2].set_parent(new_parent: nil,tree_name:'a',existing_tree:'a')
        expect(@items[2].ancestors('a').pluck(:id)).to be_empty
        expect(@items[2].ancestors('b').pluck(:id)).not_to be_empty
      end

      context 'with items that have default hierarchy names' do
        let(:named_item){create(:named_item)}
        it 'should accept the scope from the parent' do
          @items[0].parent = named_item
          expect(named_item.children(named_item.default_tree_name)).to include(@items[0])
        end

        it 'should use a default named scope for the childen' do
          @items[0].parent = named_item
          expect(named_item.children).to include(@items[0])
        end

        it 'the children should maintain their own scope for their own children' do
          @items[0].parent = named_item
          @items[1].parent = @items[0]
          expect(named_item.descendants).not_to include(@items[1])
        end
        #this is to resolve a strange problem discovered when testing a hiearchy with named defaults mixed with the standard hierarchy
        it 'should allow crossing hierarchies' do
          (0..0).each do |dummy|
            @items[0].parent = named_item
          end
          named_item.children.each do |child|
            @items[1].parent = child
          end

        end
      end


    end
  end
end

