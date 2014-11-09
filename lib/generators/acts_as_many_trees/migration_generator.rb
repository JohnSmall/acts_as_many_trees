require 'rails/generators/named_base'
require 'rails/generators/active_record/migration'
require 'forwardable'

module ActsAsManyTrees
  module Generators # :nodoc:
    class MigrationGenerator < ::Rails::Generators::NamedBase # :nodoc:
      include ActiveRecord::Generators::Migration

      extend Forwardable
      def_delegators :hierarchy_table_name

      def self.default_generator_root
        File.dirname(__FILE__)
      end

      def create_migration_file
        migration_template 'create_hierarchies_table.rb.erb', "db/migrate/create_#{hierarchy_table_name}.rb"
      end

      def migration_class_name
        "Create#{hierarchy_table_name.camelize}"
      end

      def hierarchy_table_name
         (class_name+'Hierarchy').tableize
      end
    end
  end
end
