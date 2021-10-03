class SeedMissingSiFerryConnection < ActiveRecord::Migration[6.1]
  def change
    Scheduled::Connection.create!(from_stop_internal_id: "S31", name: "SI Ferry", mode: "ship", min_transfer_time: 300)
  end
end
