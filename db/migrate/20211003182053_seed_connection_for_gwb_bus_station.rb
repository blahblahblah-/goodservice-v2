class SeedConnectionForGwbBusStation < ActiveRecord::Migration[6.1]
  def change
    Scheduled::Connection.create!(from_stop_internal_id: "A07", name: "GWB Bus Station", mode: "bus", min_transfer_time: 300)
  end
end
