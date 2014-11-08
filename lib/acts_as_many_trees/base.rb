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
  scope :roots , ->{
    includes(:unscoped_ancestor_links).where(item_hierarchies: {ancestor_id: nil})
  }
    end
  def parent=(new_parent)
    self.class.hierarchy_class.set_parent_of(self,new_parent)
  end

  def parent
    ancestors.where('generation=1').first
  end

  def children
    descendants.where('generation=1')
  end

  def ancestors(hierarchy='')
    unscoped_ancestors.merge(self.class.hierarchy_class.scope_hierarchy(hierarchy))
  end

  def descendants(hierarchy)
    unscoped_descendants.merge(self.class.hierarchy_class.scope_hierarchy(hierarchy))
  end
  end

end
ActiveRecord::Base.send :include, ActsAsManyTrees::Base
