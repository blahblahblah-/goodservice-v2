class AddConnections < ActiveRecord::Migration[6.1]
  def change
    create_table :connections, force: :cascade do |t|
      t.string :from_stop_internal_id, null: false
      t.string :name, null: false
      t.string :mode
      t.integer :min_transfer_time, default: 0, null: false
      t.integer :access_time_from
      t.integer :access_time_to
      t.index ["from_stop_internal_id"], name: "index_connections_on_from_stop_internal_id"
    end
  end
end
