require 'active_support'
require 'acts_as_many_trees/version'
require 'acts_as_many_trees/base'

module ActsAsManyTrees
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :HierarchyTable
  autoload :Version
end
