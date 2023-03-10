class SeedGcmConnections < ActiveRecord::Migration[6.1]
  def change
    Scheduled::Connection.create!(from_stop_internal_id: "631", name: "LIRR", mode: "train", min_transfer_time: 300, access_time_from: 19800, access_time_to: 86399)
    Scheduled::Connection.create!(from_stop_internal_id: "723", name: "LIRR", mode: "train", min_transfer_time: 300, access_time_from: 19800, access_time_to: 86399)
    Scheduled::Connection.create!(from_stop_internal_id: "901", name: "LIRR", mode: "train", min_transfer_time: 300, access_time_from: 19800, access_time_to: 86399)
  end
end
