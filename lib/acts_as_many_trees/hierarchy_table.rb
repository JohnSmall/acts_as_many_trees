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

      has_many :item_siblings, through: :siblings, source: :unscoped_descendant

      scope :scope_hierarchy,->(scope_hierarchy=''){ where hierarchy_scope: scope_hierarchy}
      # select t1.* from item_trees t1 left outer join item_trees t2 on t1.ancestor_id = t2.descendant_id and t1.tree_scope = t2.tree_scope where t2.ancestor_id is null
      scope :roots,->do
        t1 = arel_table
        t2 = arel_table.alias
        j=t1.project(Arel::star).join(t2,Arel::Nodes::OuterJoin)
        .on(t1[:ancestor_id]
            .eq(t2[:descendant_id])
            .and(t1[:hierarchy_scope].eq(t2[:hierarchy_scope])
                )
           )
        .where(t2[:ancestor_id].eq(nil)
              )
        joins(j)
      end
      scope :self_and_siblings, ->(item,hierarchy_scope='')do
        joins(:siblings)
      end
      scope :siblings_before_this,->(rec) do
        joins(:siblings).where(:position,lt(rec.position))
      end

      def self.set_parent_of(item:,new_parent:,hierarchy_scope:'',existing_scope:'',clone_sub_tree:false,after_node:nil,before_node:nil)
        if new_parent
          wrk_parent = self.find_by(descendant_id:new_parent.id,ancestor_id:new_parent.id,generation: 0,hierarchy_scope: hierarchy_scope)
          unless wrk_parent
            position = ((after_this(nil,nil,hierarchy_scope)+before_this(nil,hierarchy_scope))/2.0).round(15)
            wrk_parent=self.create(descendant_id:new_parent.id,ancestor_id:new_parent.id,generation: 0,hierarchy_scope: hierarchy_scope,position: position)
          end
        end
        # puts 'ppppppppppp'
        # debug_tree('')
        # puts 'pppppppp'
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
          # BEWARE this works when added default trees and adding default trees to a new scope but it won't work when moving
          # items within a named tree or when adding items from one named scope to another
          # puts "hierarchy_scope #{hierarchy_scope} existing_scope #{existing_scope}"
          if (hierarchy_scope != existing_scope)
             # debug_tree(existing_scope)
             # debug_tree(hierarchy_scope)
             # debug_tree(temp_name)
            if clone_sub_tree
              clone_sub_tree(item:wrk_item,temp_name:temp_name,existing_name:existing_scope)
            else
              clone_item_only(item:wrk_item,new_parent:wrk_parent,hierarchy_scope:temp_name)
            end
            add_all_ancestors(wrk_item,wrk_parent,temp_name)
            # debug_tree(temp_name)
          else
            # debug_tree
            # debug_tree(temp_name)
            # # add_all_ancestors(wrk_item,wrk_parent,temp_name)
            # puts wrk_item.attributes
            # puts wrk_parent.attributes
            create_tree(wrk_item:wrk_item,wrk_parent:wrk_parent,temp_name:temp_name)
             # debug_tree(temp_name)
            # delete_item_ancestors(wrk_item)
            #where({descendant_id: wrk_item.descendant_id,hierarchy_scope: hierarchy_scope }).delete_all
            # delete_ancestors(wrk_item,wrk_item.hierarchy_scope)
            delete_ancestors_of_item_children(wrk_item,hierarchy_scope)
          end
          reset_descendant_position(wrk_item,before_position,temp_name)
          rename_tree(temp_name,hierarchy_scope)
          # debug_tree('')
          # puts "***************\n\n"
        end
      end

      def self.debug_tree(hierarchy_scope='')
        puts '======================'
        self.where(hierarchy_scope:hierarchy_scope).order([:ancestor_id,:generation]).each{|r| puts r.attributes}
        puts '**********************'
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

      def self.clone_item_only(item:,new_parent:,hierarchy_scope:)
        sql=<<-SQL
        insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope,position)
        select b.ancestor_id,a.descendant_id,b.generation+1,'#{hierarchy_scope}',a.position
        from #{table_name} a,#{table_name} b
        where b.descendant_id = #{new_parent.descendant_id}
        and a.descendant_id = #{item.descendant_id}
        and a.hierarchy_scope = '#{item.hierarchy_scope}'
        and a.hierarchy_scope = b.hierarchy_scope
        and a.generation = 0
        SQL
        connection.execute(sql)
      end

      def self.clone_sub_tree(item:,temp_name:,existing_name:'')
        sql=<<-SQL
        insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope,position)
        WITH RECURSIVE sub_trees(ancestor_id,descendant_id,generation,hierarchy_scope,position) AS
          (select ancestor_id,descendant_id,generation,'#{temp_name}',position from #{table_name}
           where descendant_id = #{item.descendant_id}
           and hierarchy_scope = '#{existing_name}'
        UNION
           select s.ancestor_id,s.descendant_id,
           s.generation,'#{temp_name}',s.position
           from #{table_name} s, sub_trees st
           where s.ancestor_id = st.descendant_id
           and s.hierarchy_scope = '#{existing_name}'
           )
           select * from sub_trees;
        SQL
        connection.execute(sql)
      end

      def self.add_all_ancestors(item,parent,temp_name)
        sql=<<-SQL
        insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope,position)
        select a.ancestor_id,b.descendant_id,a.generation+b.generation+1,'#{temp_name}',b.position
          from #{table_name} a, #{table_name} b
          where a.descendant_id=#{parent.descendant_id}
          and b.ancestor_id=#{item.descendant_id}
          and b.hierarchy_scope = '#{temp_name}'
          and a.hierarchy_scope = '#{parent.hierarchy_scope}'
        SQL
        connection.execute(sql)
      end

      def self.create_tree(wrk_item:,wrk_parent:,temp_name:)
        if wrk_parent
          # if existing_name != wrk_item.hierarchy_scope
          #   puts 'new hierarchy'
          #   sql=<<-SQL
          # insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope,position)
          # select a.ancestor_id,b.descendant_id,a.generation+b.generation+1,'#{temp_name}',b.position
          # from #{table_name} a, #{table_name} b
          # where a.descendant_id=#{wrk_parent.descendant_id}
          # and b.ancestor_id=#{wrk_item.ancestor_id}
          # and a.hierarchy_scope = b.hierarchy_scope
          # and a.hierarchy_scope = '#{wrk_item.hierarchy_scope}'
          # union
          # select c.ancestor_id,c.descendant_id,c.generation,'#{temp_name}',c.position
          # from #{table_name} c
          # where c.ancestor_id = #{wrk_item.descendant_id}
          # and c.hierarchy_scope = '#{wrk_item.hierarchy_scope}'
          # union
          # select c.ancestor_id,c.descendant_id,c.generation,'#{temp_name}',c.position
          # from #{table_name} c
          # where c.ancestor_id = #{wrk_item.descendant_id}
          # and c.ancestor_id <> c.descendant_id
          # and c.hierarchy_scope = '#{existing_name}'
          # union
          # select #{wrk_parent.descendant_id},c.descendant_id,#{wrk_parent.generation}+c.generation+1,'#{temp_name}',c.position
          # from #{table_name} c
          # where c.ancestor_id = #{wrk_item.descendant_id}
          # and c.ancestor_id <> c.descendant_id
          # and c.hierarchy_scope = '#{existing_name}'
          # /* add existing descendants of descendants in the new tree */
          # union
          # select c.ancestor_id,c.descendant_id,c.generation,'#{temp_name}',c.position
          # from #{table_name} c, #{table_name} d
          # where c.ancestor_id = d.descendant_id
          # and d.ancestor_id =#{wrk_item.descendant_id}
          # and d.hierarchy_scope = c.hierarchy_scope
          # and c.ancestor_id != c.descendant_id
          # and c.hierarchy_scope = '#{existing_name}'
          #   SQL
          # else
          sql=<<-SQL
        insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope,position)
        /* add self and descendants to the new parent */
        select a.ancestor_id,b.descendant_id,a.generation+b.generation+1,'#{temp_name}',b.position
          from #{table_name} a, #{table_name} b
          where a.descendant_id=#{wrk_parent.descendant_id}
          and b.ancestor_id=#{wrk_item.ancestor_id}
          and a.hierarchy_scope = b.hierarchy_scope
          and a.hierarchy_scope = '#{wrk_item.hierarchy_scope}'

        /* add existing descendants in the new tree */
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
        #        puts '============='
        #        wrk_item.class.find_by_sql("select * from #{table_name} where hierarchy_scope='#{temp_name}'").each do | i |
        #          puts "a=#{i.ancestor_id} d=#{i.descendant_id} scope = #{i.hierarchy_scope} wrk.a = #{wrk_item.ancestor_id} wrk.b=#{wrk_item.descendant_id} parent_scope = #{wrk_parent.hierarchy_scope} parent.a =#{wrk_parent.ancestor_id} parent.d =#{wrk_parent.descendant_id}"
        #        end
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
          update #{table_name} h1
          set hierarchy_scope='#{new_name}'
          where hierarchy_scope='#{old_name}'
          and not exists(select h2.ancestor_id from #{table_name} h2
                         where h1.ancestor_id = h2.ancestor_id
                         and h1.descendant_id = h2.descendant_id
                         and h2.hierarchy_scope = '#{new_name}'
                         )
        SQL
        connection.execute(sql)
      end

      def self.delete_ancestors(item,hierarchy_scope='')
        puts "#{item.id}"
        self.delete(descendant_id: item.id,hierarchy_scope: hierarchy_scope )
      end

      def self.delete_ancestors_of_item_children(item,hierarchy_scope)
        sql = <<-SQL
    delete from #{table_name} as p using #{table_name} as p1, #{table_name} as p2
    where p.descendant_id = p1.descendant_id
    and p.ancestor_id = p2.ancestor_id
    and p2.descendant_id = #{item.descendant_id}
    and p1.ancestor_id = p2.descendant_id
    and p2.hierarchy_scope = p1.hierarchy_scope
    and p.hierarchy_scope = p1.hierarchy_scope
    and p1.hierarchy_scope = '#{hierarchy_scope}'
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
