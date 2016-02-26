module ActsAsManyTrees
  module Base
    extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
      def acts_as_many_trees(options = {})
        class_attribute :hierarchy_class
        self.hierarchy_class = (name+'Hierarchy').constantize
        include ActsAsManyTrees::InstanceMethods
        extend ActsAsManyTrees::ClassMethods
        hierarchy_class.send :include,ActsAsManyTrees::HierarchyTable
      end
    end

  end
  module ClassMethods
    def hierarchy_table_name
      hierarchy_class.table_name
    end

    def default_tree_name
      ''
    end

  end
  module InstanceMethods
    extend ActiveSupport::Concern
    included do
      has_many :unscoped_descendant_links,
        # ->{order(:position)},
        class_name: hierarchy_class.to_s,
        foreign_key: 'ancestor_id',
        dependent: :delete_all,
        inverse_of: :unscoped_ancestor

      has_many :unscoped_ancestor_links,
         ->{order(:position)},
        class_name: hierarchy_class.to_s,
        foreign_key: 'descendant_id',
        dependent: :delete_all,
        inverse_of: :unscoped_descendant

      has_many :unscoped_ancestors,through: :unscoped_ancestor_links
      has_many :unscoped_descendants,  {:through=>:unscoped_descendant_links, :source=>:unscoped_descendant}
      has_many :self_and_siblings,  
        {:through=>:unscoped_ancestor_links, 
         :source=>:item_siblings
        }
      has_many :siblings_before,
        ->{where("unscoped_ancestor_links_siblings_before_join.position > #{hierarchy_table_name}.position").where('unscoped_ancestor_links_siblings_before_join.generation=1')},
        {:through=>:unscoped_ancestor_links, 
         :source=>:item_siblings
        }
      has_many :siblings_after,
        ->{where("unscoped_ancestor_links_siblings_after_join.position < #{hierarchy_table_name}.position").where('unscoped_ancestor_links_siblings_after_join.generation=1')},
        {:through=>:unscoped_ancestor_links, 
         :source=>:item_siblings
        }

        scope :roots , ->(tree_name=self.default_tree_name){
        h1 = hierarchy_class.arel_table
        h2 = hierarchy_class.arel_table.alias
          on1 = Arel::Nodes::On.new(Arel::Nodes::Equality.new(arel_table[:id],h1[:descendant_id])
                                   .and(h1[:hierarchy_scope].eq(tree_name))
                                   .and(h1[:generation].eq(0))
                                  )
          on2 = Arel::Nodes::On.new(Arel::Nodes::Equality.new(h1[:ancestor_id],h2[:descendant_id])
                                    .and(Arel::Nodes::Equality.new(h1[:hierarchy_scope],h2[:hierarchy_scope]))
                                   .and(h2[:generation].not_eq(0))
                                   )
          inner_join = Arel::Nodes::InnerJoin.new(h1,on1)
          outer_join = Arel::Nodes::OuterJoin.new(h2,on2)
          joins(inner_join).joins(outer_join).merge(where(Arel::Nodes::Equality.new(h2[:ancestor_id],nil)))
        }
        scope :not_this,->(this_id) { where.not(id: this_id)}
        scope :ordered,->{order("#{hierarchy_table_name}.position")}
    end
    delegate :hierarchy_class, to: :class
    #can be over-ridden in the instance 
    def default_tree_name
      ''
    end

    def parent=(inpt_parent)
      if inpt_parent.is_a?(Hash)
        new_parent=inpt_parent[:new_parent]
        after_node=inpt_parent[:after_node] 
        before_node=inpt_parent[:before_node] 
        tree_name = inpt_parent[:tree_name] || (new_parent ? new_parent.default_tree_name : self.default_tree_name)
        existing_tree_name = inpt_parent[:existing_tree_name] || self.default_tree_name
      else
        new_parent=inpt_parent
        after_node=inpt_parent.children.ordered.last unless inpt_parent.nil?
        before_node=inpt_parent.next_sibling unless inpt_parent.nil?
        tree_name = inpt_parent ? inpt_parent.default_tree_name : self.default_tree_name
        existing_tree_name = self.default_tree_name
      end  
      hierarchy_class.set_parent_of(item:self,new_parent:new_parent,hierarchy_scope:tree_name,existing_scope:existing_tree_name,after_node:after_node,before_node:before_node)
    end

    def set_parent(new_parent:,tree_name:self.default_tree_name,existing_tree:self.default_tree_name,clone_sub_tree:false)
      hierarchy_class.set_parent_of(item:self,new_parent:new_parent,hierarchy_scope:tree_name,existing_scope:existing_tree,clone_sub_tree:clone_sub_tree)
    end

    def add_child(new_child,tree_name=self.default_tree_name)
      hierarchy_class.set_parent_of(item:new_child,new_parent:self,hierarchy_scope:tree_name)
    end

    def parent(tree_name=self.default_tree_name)
      ancestors(tree_name).where('generation=1').first
    end

    def children(tree_name=self.default_tree_name)
      descendants(tree_name).where('generation=1')
    end

    def self_and_ancestors(tree_name=self.default_tree_name)
      unscoped_ancestors.merge(hierarchy_class.scope_hierarchy(tree_name))
    end

    def ancestors(tree_name=self.default_tree_name)
      self_and_ancestors(tree_name).not_this(self.id)
    end

    def self_and_descendants(tree_name=self.default_tree_name)
      unscoped_descendants.merge(hierarchy_class.scope_hierarchy(tree_name))
    end

    def siblings
      self_and_siblings.where.not(id: id)
    end

    def previous_sibling
      siblings_before.last
    end

    def next_sibling
      siblings_after.first
    end

    def descendants(tree_name=self.default_tree_name)
      self_and_descendants(tree_name).not_this(self.id)
    end

    def position(tree_name=self.default_tree_name)
       link = unscoped_ancestor_links.where(ancestor_id: id,hierarchy_scope: tree_name).first
       link ? link.position: 0
    end
  end
end
ActiveRecord::Base.send :include, ActsAsManyTrees::Base
