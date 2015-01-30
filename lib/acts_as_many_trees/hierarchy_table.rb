require 'bigdecimal'
module ActsAsManyTrees
  module HierarchyTable 
    extend ActiveSupport::Concern

    included do
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
        wrk_item   = self.find_or_create_by(descendant_id:item.id,ancestor_id:item.id,generation: 0,hierarchy_scope: hierarchy_scope) if item
        wrk_parent = self.find_or_create_by(descendant_id:new_parent.id,ancestor_id:new_parent.id,generation: 0,hierarchy_scope: hierarchy_scope) if new_parent
        if item
          temp_name = SecureRandom.hex
          create_tree(wrk_item,wrk_parent,temp_name)
          delete_item_ancestors(wrk_item)
          delete_ancestors_of_item_children(wrk_item,hierarchy_scope)
          rename_tree(temp_name,hierarchy_scope)
        end
      end

      private
      def self.create_tree(wrk_item,wrk_parent,temp_name)
        if wrk_parent
          sql=<<-SQL
        insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope)
        select a.ancestor_id,b.descendant_id,a.generation+b.generation+1,'#{temp_name}'
          from #{table_name} a, #{table_name} b
          where a.descendant_id=#{wrk_parent.descendant_id}
          and b.ancestor_id=#{wrk_item.ancestor_id}
          and a.hierarchy_scope = b.hierarchy_scope
          and a.hierarchy_scope = '#{wrk_item.hierarchy_scope}'
        union
        select c.ancestor_id,c.descendant_id,c.generation,'#{temp_name}'
          from #{table_name} c
          where c.ancestor_id = #{wrk_item.descendant_id}
          and c.hierarchy_scope = '#{wrk_item.hierarchy_scope}'
          SQL
        else
          sql=<<-SQL
        insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope)
        select c.ancestor_id,c.descendant_id,c.generation,'#{temp_name}'
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

      def self.fill_in_parent_for(new_parent,item,hierarchy_scope='',after_node=nil,before_node=nil)
        if new_parent
          p_rec = find_by(descendant_id: new_parent.id,hierarchy_scope: hierarchy_scope)
          unless p_rec
            p_rec=create!(ancestor_id: new_parent.id,descendant_id: new_parent.id,hierarchy_scope: hierarchy_scope,generation:0,position:Random.rand(1000000))
          end
          #          p "p_rec.position = #{p_rec.position}"
          a_rec = nil
          if after_node
            a_rec = after_node
            a_rec_h = find_by(ancestor_id: new_parent.id, descendant_id:a_rec.id,hierarchy_scope: hierarchy_scope)
            a_rec_pos = a_rec_h.position
          elsif new_parent.children.last
            a_rec = new_parent.children.last
            a_rec_h = find_by(ancestor_id: new_parent.id, descendant_id:a_rec.id,hierarchy_scope: hierarchy_scope)
            a_rec_pos = a_rec_h.position
          else
            a_rec_pos = p_rec.position
          end

          if before_node 
            b_rec = find_by(descendant_id: before_node.id,hierarchy_scope: hierarchy_scope,generation: 1)
            if b_rec
              b_position = b_rec.position
            end
          end
          if b_position && !after_node
            #            p "b_position #{b_position} parent position #{p_rec.position}"
            new_position = (Random.rand(10)*(b_position - p_rec.position)/11)+p_rec.position
          elsif b_position && after_node
            #            p "b_position #{b_position}  after position #{a_rec_pos}"
            new_position = (Random.rand(10)*(b_position - a_rec_pos)/11)+a_rec_pos
          else
            new_position = a_rec_pos + Random.rand(1000000)
          end
          #create(ancestor_id: item.id,descendant_id: item.id,hierarchy_scope: hierarchy_scope,position:new_position,generation:0)
          if item
            #          p "id = #{item.id} position=#{new_position}"
            create(ancestor_id: new_parent.id,descendant_id: item.id,generation: 1,hierarchy_scope: hierarchy_scope,position:new_position)
          end
        end
      end

      def self.fill_in_ancestors_for(new_parent,item,hierarchy_scope)
        if new_parent
          sql=<<-SQL
       insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope,position)
       select it.ancestor_id,new_itm.descendant_id,it.generation+1,it.hierarchy_scope,new_itm.position
       from #{table_name} it 
       join #{table_name} new_itm on it.descendant_id = new_itm.ancestor_id and it.hierarchy_scope=new_itm.hierarchy_scope
       where new_itm.ancestor_id=#{new_parent.id}
       and new_itm.descendant_id=#{item.id}
       and (it.ancestor_id <> it.descendant_id)
       and it.hierarchy_scope = '#{hierarchy_scope}'
          SQL
          ActiveRecord::Base.connection.execute(sql)
        end
      end

      def self.add_self(item,hierarchy)
        sql=<<-SQL
       insert into #{table_name}(ancestor_id,descendant_id,generation,hierarchy_scope,position)
         values(#{item.id},#{item.id},0,'#{hierarchy}',null)
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
      def self.reset_descendant_position(parent,hierarchy_scope='')
        #select ancestor_id,descendant_id,generation,position, 
        #(CAST ((rank() over (partition by ancestor_id order by position)) AS numeric))
        #/( CAST (count(*) over (partition by ancestor_id)+1 AS numeric)) from item_hierarchies where ancestor_id=1;
      end
    end
  end
end
