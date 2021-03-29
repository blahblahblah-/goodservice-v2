class AddMoreIndexes < ActiveRecord::Migration[6.1]
  def change
    add_index :trips, :schedule_service_id
    add_index :trips, :route_internal_id
    add_index :stop_times, :departure_time
  end
end
