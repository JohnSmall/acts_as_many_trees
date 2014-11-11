
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

      def self.set_parent_of(item,new_parent,hierarchy_scope='')
        self.delete_ancestors(item,hierarchy_scope) if item
        self.fill_in_parent_for(new_parent,item,hierarchy_scope) if item || new_parent
        self.fill_in_ancestors_for(new_parent,item,hierarchy_scope) if item && new_parent
        self.delete_ancestors_of_item_children(item,hierarchy_scope) if item
        self.set_new_ancestors_of_item_children(item,hierarchy_scope) if item
      end

      private
      def self.delete_ancestors(item,hierarchy_scope)
        delete_all(descendant_id: item.id,hierarchy_scope: hierarchy_scope )
      end

      def self.delete_ancestors_of_item_children(item,hierarchy_scope)
        sql = <<-SQL
    delete from #{table_name} as p using #{table_name} as p1 
    where p.descendant_id = p1.descendant_id 
    and p1.ancestor_id = #{item.id} 
    and p.generation > p1.generation 
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

      def self.fill_in_parent_for(new_parent,item,hierarchy_scope,after_record=nil,before_record=nil)
        if new_parent
          p_rec = find_by(descendant_id: new_parent.id,hierarchy_scope: hierarchy_scope)
          unless p_rec
            p_rec=create!(ancestor_id: new_parent.id,descendant_id: new_parent.id,hierarchy_scope: hierarchy_scope,generation:0,position:Random.rand(1000000))
          end
          a_rec = nil
          if after_record
            a_rec = after_record
          elsif new_parent.children.last
            a_rec = new_parent.children.last
          end
          if a_rec  
            a_rec_h = find_by(ancestor_id: new_parent.id, descendant_id:a_rec.id,hierarchy_scope: hierarchy_scope)
            a_rec_pos = a_rec_h.position
          end
          last_position = a_rec_pos || p_rec.position
          new_position = last_position + Random.rand(1000000)
          #create(ancestor_id: item.id,descendant_id: item.id,hierarchy_scope: hierarchy_scope,position:new_position,generation:0)
          if item
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
    end

  end
end
