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
  end
  module InstanceMethods
    extend ActiveSupport::Concern
    included do
      has_many :unscoped_descendant_links,
        ->{order(:position)},
        class_name:hierarchy_class.to_s,
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
        ->{where('unscoped_ancestor_links_siblings_before_join.position > item_hierarchies.position').where('unscoped_ancestor_links_siblings_before_join.generation=1')},
        {:through=>:unscoped_ancestor_links, 
         :source=>:item_siblings
        }
      has_many :siblings_after,
        ->{where('unscoped_ancestor_links_siblings_after_join.position < item_hierarchies.position').where('unscoped_ancestor_links_siblings_after_join.generation=1')},
        {:through=>:unscoped_ancestor_links, 
         :source=>:item_siblings
        }

        scope :roots , ->(hierarchy=''){
          on = Arel::Nodes::On.new(Arel::Nodes::Equality.new(arel_table[:id],hierarchy_class.arel_table[:descendant_id])
                                   .and(hierarchy_class.arel_table[:hierarchy_scope].eq(hierarchy))
                                   .and(hierarchy_class.arel_table[:generation].not_eq(0))
                                  )
          outer_join = Arel::Nodes::OuterJoin.new(hierarchy_class.arel_table,on)
          joins(outer_join).merge(hierarchy_class.where(ancestor_id: nil))
        }
        scope :not_this,->(this_id) { where.not(id: this_id)}
    end
    delegate :hierarchy_class, to: :class
    def parent=(inpt_parent)
      if inpt_parent.is_a?(Hash)
        new_parent=inpt_parent[:new_parent]
        after_node=inpt_parent[:after_node] 
        before_node=inpt_parent[:before_node] 
        hierarchy_scope=inpt_parent[:hierarchy_scope] || ''
      else
        new_parent=inpt_parent
        after_node=inpt_parent.children.last unless inpt_parent.nil?
        before_node=inpt_parent.next_sibling unless inpt_parent.nil?
        hierarchy_scope = ''
      end  
      hierarchy_class.set_parent_of(self,new_parent,hierarchy_scope,after_node,before_node)
    end

    def set_parent(new_parent,hierarchy_scope='')
      hierarchy_class.set_parent_of(self,new_parent,hierarchy_scope)
    end

    def add_child(new_child,hierarchy_scope='')
      hierarchy_class.set_parent_of(new_child,self,hierarchy_scope)
    end

    def parent(hierarchy_scope='')
      ancestors(hierarchy_scope).where('generation=1').first
    end

    def children(hierarchy_scope='')
      descendants(hierarchy_scope).where('generation=1')
    end

    def self_and_ancestors(hierarchy='')
      unscoped_ancestors.merge(hierarchy_class.scope_hierarchy(hierarchy))
    end

    def ancestors(hierarchy='')
      self_and_ancestors(hierarchy).not_this(self.id)
    end

    def self_and_descendants(hierarchy='')
      unscoped_descendants.merge(hierarchy_class.scope_hierarchy(hierarchy))
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

    def descendants(hierarchy='')
      self_and_descendants(hierarchy).not_this(self.id)
    end
  end
end
ActiveRecord::Base.send :include, ActsAsManyTrees::Base
