# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20141108152400) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "item_hierarchies", id: false, force: true do |t|
    t.integer "ancestor_id"
    t.integer "descendant_id"
    t.integer "generation"
    t.string  "hierarchy_scope"
    t.decimal "position"
  end

  add_index "item_hierarchies", ["ancestor_id", "descendant_id", "hierarchy_scope"], name: "idx_unq_item_hierachy_ancestor_descendant_scope", unique: true, using: :btree
  add_index "item_hierarchies", ["ancestor_id", "hierarchy_scope", "position"], name: "idx_ancestor_scope_position", using: :btree
  add_index "item_hierarchies", ["descendant_id", "hierarchy_scope"], name: "index_item_hierarchies_on_descendant_id_and_hierarchy_scope", using: :btree

  create_table "items", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
