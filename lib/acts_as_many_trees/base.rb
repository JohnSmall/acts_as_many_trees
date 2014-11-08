
module ActsAsManyTrees
  module Concern
    extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
      def acts_as_many_trees(options = {})
        include ActsAsManyTrees::InstanceMethods
        extend ActsAsManyTrees::ClassMethods
      end
    end

  end
  module ClassMethods
      def hierarchy_class
        (name+'Hierarchy').constantize
      end
      def hierarchy_table_name
        hierarchy_class.table_name
      end
  end
    module InstanceMethods
      def children
      end
    end
 
end
ActiveRecord::Base.send :include, ActsAsManyTrees::Concern
