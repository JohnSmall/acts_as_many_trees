require 'bigdecimal'
module ActsAsManyTrees
  module HierarchyTable 
    extend ActiveSupport::Concern

    included do
      UPPER_BOUND=10**20 unless !!defined?(UPPER_BOUND)
      class_attribute :item_class_name
      self.item_class_name = self.to_s.gsub('Hierarchy','')
      class_attribute :item_class
      self.item_class = item_class_name.constantize 

      belongs_to :unscoped_ancestor,
        class_name: item_class_name,
        foreign_key: 'ancestor_id', 
        inverse_of: :unscoped_descendant_links

      belongs_to :unscoped_descendant,
        class_name: item_class_name,
        foreign_key: 'descendant_id', 
        inverse_of: :unscoped_ancestor_links

      has_many :self_and_ancestors,
        ->(rec){where(hierarchy_scope: rec.hierarchy_scope)},
        class_name: self.name,
        foreign_key: 'descendant_id',
        primary_key: 'ancestor_id'

      has_many :ancestors,
        ->(rec){where(hierarchy_scope: rec.hierarchy_scope).where.not(generation:0)},
        class_name: self.name,
        foreign_key: 'descendant_id',
        primary_key: 'ancestor_id'

      has_many :self_and_descendants,
        ->(rec){where(hierarchy_scope: rec.hierarchy_scope).where.order(:position)}, 
        class_name: self.name,
        foreign_key: 'ancestor_id',
        primary_key: 'descendant_id'

      has_many :descendants,
        ->(rec){where(hierarchy_scope: rec.hierarchy_scope).where.not(generation:0).order(:position)}, 
        class_name: self.name,
        foreign_key: 'ancestor_id',
        primary_key: 'descendant_id'

      has_many :siblings,
        ->{where(generation: 1)}, 
        class_name: self.name,
        foreign_key: 'ancestor_id',
        primary_key: 'ancestor_id'

      has_many :children,
        ->(rec){where(hierarchy_scope: rec.hierarchy_scope,generation: 1).order(:position)}, 
        class_name: self.name,
        foreign_key: 'ancestor_id',
        primary_key: 'descendant_id'

      has_many :item_siblings,{through: :siblings, source: :unscoped_descendant}

      scope :scope_hierarchy,->(scope_hierarchy=''){ where hierarchy_scope: scope_hierarchy}
      # select t1.* from item_trees t1 left outer join item_trees t2 on t1.ancestor_id = t2.descendant_id and t1.tree_scope = t2.tree_scope where t2.ancestor_id is null
      scope :roots,->do
        t1 = arel_table
        t2 = arel_table.alias
        t1.project(Arel::star).join(t2,Arel::Nodes::OuterJoin)
        .on(t1[:ancestor_id]
            .eq(t2[:descendant_id])
            .and(t1[:hierarchy_scope].eq(t2[:hierarchy_scope])
                )
           )
        .where(t2[:ancestor_id].eq(nil)
              )
      end
      scope :self_and_siblings, ->(item,hierarchy_scope='')do
        joins(:siblings)
      end
      scope :siblings_before_this,->(rec) do
        joins(:siblings).where(:position,lt(rec.position))
      end

      def self.set_parent_of(item,new_parent,hierarchy_scope='',after_node=nil,before_node=nil)
        if new_parent
          wrk_parent = self.find_by(descendant_id:new_parent.id,ancestor_id:new_parent.id,generation: 0,hierarchy_scope: hierarchy_scope) 
          unless wrk_parent
            position = ((after_this(nil,nil,hierarchy_scope)+before_this(nil,hierarchy_scope))/2.0).round(15)
            wrk_parent=self.create(descendant_id:new_parent.id,ancestor_id:new_parent.id,generation: 0,hierarchy_scope: hierarchy_scope,position: position)
          end
        end
        if item
          after_position  = after_this(wrk_parent,after_node,hierarchy_scope)
          before_position = before_this(before_node,hierarchy_scope)
          position = ((after_position+before_position)/2.0).round(15)
          wrk_item = self.find_by(descendant_id:item.id,ancestor_id:item.id,generation: 0,hierarchy_scope: hierarchy_scope)
          if wrk_item
            wrk_item.position = position
          else
            wrk_item=self.create(descendant_id:item.id,ancestor_id:item.id,generation: 0,hierarchy_scope: hierarchy_scope,position: position)
          end
          temp_name = SecureRandom.hex
          create_tree(wrk_item,wrk_parent,temp_name)
          delete_item_ancestors(wrk_item)
          delete_ancestors_of_item_children(wrk_item,hierarchy_scope)
          reset_descendant_position(wrk_item,before_position,temp_name)
          rename_tree(temp_name,hierarchy_scope)
        end
      end

      private
      # the new position is after the maximum of the after_node, the parent, the current maximum of all
      def self.after_this(wrk_parent,after_node,hierarchy_scope)
        if after_node
          position = after_node.position(hierarchy_scope)
        elsif wrk_parent
          position = wrk_parent.position
        else
          position = self.where(hierarchy_scope: hierarchy_scope).maximum(:position) || 0
        end
        position
      end

      # and before the minimum of the before_node, the parent's next sibling or 10**20
      def self.before_this(before_node,hierarchy_scope)
        if before_node
          position = before_node.position(hierarchy_scope)
        else
          position = UPPER_BOUND
        end
        position
      end

      def self.create_tree(wrk_item,wrk_parent,temp_name)
        if wrk_parent
          sql=<<-SQL
        insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope,position)
        select a.ancestor_id,b.descendant_id,a.generation+b.generation+1,'#{temp_name}',b.position
          from #{table_name} a, #{table_name} b
          where a.descendant_id=#{wrk_parent.descendant_id}
          and b.ancestor_id=#{wrk_item.ancestor_id}
          and a.hierarchy_scope = b.hierarchy_scope
          and a.hierarchy_scope = '#{wrk_item.hierarchy_scope}'
        union
        select c.ancestor_id,c.descendant_id,c.generation,'#{temp_name}',c.position
          from #{table_name} c
          where c.ancestor_id = #{wrk_item.descendant_id}
          and c.hierarchy_scope = '#{wrk_item.hierarchy_scope}'
          SQL
        else
          sql=<<-SQL
        insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope,position)
        select c.ancestor_id,c.descendant_id,c.generation,'#{temp_name}',c.position
          from #{table_name} c
          where c.ancestor_id = #{wrk_item.descendant_id}
          and c.hierarchy_scope = '#{wrk_item.hierarchy_scope}'
          SQL
        end
        connection.execute(sql)
      end

      def self.delete_item_ancestors(wrk_item)
        sql=<<-SQL
          delete from #{table_name}
          where hierarchy_scope='#{wrk_item.hierarchy_scope}'
          and descendant_id=#{wrk_item.descendant_id}
        SQL
        connection.execute(sql)
      end

      def self.rename_tree(old_name,new_name)
        sql=<<-SQL
          update #{table_name}
          set hierarchy_scope='#{new_name}'
          where hierarchy_scope='#{old_name}'
        SQL
        connection.execute(sql)
      end

      def self.delete_ancestors(item,hierarchy_scope)
        delete.where(descendant_id: item.id,hierarchy_scope: hierarchy_scope ).where.not(generation: 0)
      end

      def self.delete_ancestors_of_item_children(item,hierarchy_scope)
        sql = <<-SQL
    delete from #{table_name} as p using #{table_name} as p1 
    where p.descendant_id = p1.descendant_id 
    and p1.ancestor_id = #{item.descendant_id} 
    and p.hierarchy_scope = p1.hierarchy_scope
    and p1.hierarchy_scope = '#{hierarchy_scope}'
    and p.generation > 0
        SQL
        connection.execute(sql)
      end

      def self.set_new_ancestors_of_item_children(item,hierarchy_scope)
        sql=<<-SQL
       insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope,position)
       select it.ancestor_id,ct.descendant_id,it.generation+ct.generation,ct.hierarchy_scope,ct.position 
       from #{table_name} it 
       join #{table_name} ct 
       on ct.ancestor_id = it.descendant_id
       and ct.hierarchy_scope = it.hierarchy_scope
       where it.descendant_id=#{item.id}
       and it.hierarchy_scope = '#{hierarchy_scope}'
        SQL
        connection.execute(sql)
      end

      def self.reset_descendant_position(parent,before_position,hierarchy_scope='')
        after_position = parent.position
        gap = before_position - after_position
#        p "before position: #{before_position}, after_position: #{after_position} gap: #{gap}"
#        sql = <<-SQL
#        select ancestor_id,descendant_id,hierarchy_scope,(#{after_position} + ( 
#        (CAST ((rank() over (partition by ancestor_id order by position)-1) AS numeric))
#        /( CAST (count(*) over (partition by ancestor_id) AS numeric)) * #{gap})) as position
#        from #{table_name} 
#        where ancestor_id=#{parent.descendant_id}
#        and hierarchy_scope='#{hierarchy_scope}'
#        SQL
#        res = connection.execute(sql)
#        res.each_row do |row|
#          p row
#        end
        sql = <<-SQL
        with new_position as (select ancestor_id,descendant_id,hierarchy_scope,(#{after_position} + ( 
        (CAST ((rank() over (partition by ancestor_id order by position)-1) AS numeric))
        /( CAST (count(*) over (partition by ancestor_id) AS numeric)) * #{gap})) as position
        from #{table_name} 
        where ancestor_id=#{parent.descendant_id}
        and hierarchy_scope='#{hierarchy_scope}'
        )
        update  
        #{table_name} as t 
        set position = new_position.position
        from new_position
        where t.descendant_id = new_position.descendant_id
        and t.hierarchy_scope = new_position.hierarchy_scope
        SQL
        connection.execute(sql)
#        sql=<<-SQL
#        select * from #{table_name} where hierarchy_scope='#{hierarchy_scope}' order by position
#        SQL
#        res = connection.execute(sql)
#        res.each_row do |row|
#          p row
#        end
      end
    end
  end
end
