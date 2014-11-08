module ClosureTree
  module ActsAsManyTrees
    extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
      def acts_as_many_trees(options = {})
        # your code will go here
      end
    end
  end
end
ActiveRecord::Base.send :include, ClosureTree::ActsAsManyTrees
