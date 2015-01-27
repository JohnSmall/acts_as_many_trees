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
        class_name:hierarchy_class.to_s,
        foreign_key: 'ancestor_id',
        dependent: :delete_all,
        inverse_of: :unscoped_ancestor

      has_many :unscoped_ancestor_links,
        class_name: hierarchy_class.to_s,
        foreign_key: 'descendant_id',
        dependent: :delete_all,
        inverse_of: :unscoped_descendant
      has_many :unscoped_ancestors,through: :unscoped_ancestor_links
      has_many :unscoped_descendants, through: :unscoped_descendant_links
      scope :roots , ->(hierarchy=''){
        on = Arel::Nodes::On.new(Arel::Nodes::Equality.new(arel_table[:id],hierarchy_class.arel_table[:descendant_id])
                                 .and(hierarchy_class.arel_table[:hierarchy_scope].eq(hierarchy))
                                )
        outer_join = Arel::Nodes::OuterJoin.new(hierarchy_class.arel_table,on)
        joins(outer_join).merge(hierarchy_class.where(ancestor_id: nil))
      }
      scope :not_this,->(this_id) { where.not(id: this_id)}
      }
    end
    delegate :hierarchy_class, to: :class
    def parent=(new_parent,hierarchy_scope='')
      hierarchy_class.set_parent_of(self,new_parent,hierarchy_scope)
    end

    def set_parent(new_parent,hierarchy_scope='')
      hierarchy_class.set_parent_of(self,new_parent,hierarchy_scope)
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

    def descendants(hierarchy='')
      self_and_descendants(hierarchy).not_this(self.id)
    end

  end

end
ActiveRecord::Base.send :include, ActsAsManyTrees::Base
