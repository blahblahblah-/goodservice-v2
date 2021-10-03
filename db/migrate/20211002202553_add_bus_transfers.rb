class AddBusTransfers < ActiveRecord::Migration[6.1]
  def change
    create_table :bus_transfers, force: :cascade do |t|
      t.string :from_stop_internal_id, null: false
      t.string :bus_route, null: false
      t.integer :min_transfer_time, default: 0, null: false
      t.integer :access_time_from
      t.integer :access_time_to
      t.boolean :airport_connection, default: false, null: false
      t.index ["from_stop_internal_id"], name: "index_bus_transfers_on_from_stop_internal_id"
    end
  end
end
