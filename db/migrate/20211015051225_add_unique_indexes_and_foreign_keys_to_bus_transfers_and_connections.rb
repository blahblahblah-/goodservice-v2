class AddUniqueIndexesAndForeignKeysToBusTransfersAndConnections < ActiveRecord::Migration[6.1]
  def change
    add_index :bus_transfers, [:from_stop_internal_id, :bus_route], unique: true
    add_index :connections, [:from_stop_internal_id, :name], unique: true

    add_foreign_key :bus_transfers, :stops, column: :from_stop_internal_id, primary_key: :internal_id
    add_foreign_key :connections, :stops, column: :from_stop_internal_id, primary_key: :internal_id
  end
end
