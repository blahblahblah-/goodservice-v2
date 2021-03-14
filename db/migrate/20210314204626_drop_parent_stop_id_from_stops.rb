class DropParentStopIdFromStops < ActiveRecord::Migration[6.1]
  def change
    remove_column :stops, :parent_stop_id
  end
end
