class SeedTimesSqToBryantPkTransfer < ActiveRecord::Migration[6.1]
  def change
    Scheduled::Transfer.create!(from_stop_internal_id: "D16", to_stop_internal_id: "902", min_transfer_time: 300, access_time_from: 21600, access_time_to: 86399)
    Scheduled::Transfer.create!(from_stop_internal_id: "D16", to_stop_internal_id: "R16", min_transfer_time: 420, access_time_from: 21600, access_time_to: 86399)
    Scheduled::Transfer.create!(from_stop_internal_id: "D16", to_stop_internal_id: "127", min_transfer_time: 420, access_time_from: 21600, access_time_to: 86399)
    Scheduled::Transfer.create!(from_stop_internal_id: "902", to_stop_internal_id: "D16", min_transfer_time: 300, access_time_from: 21600, access_time_to: 86399)
    Scheduled::Transfer.create!(from_stop_internal_id: "R16", to_stop_internal_id: "D16", min_transfer_time: 420, access_time_from: 21600, access_time_to: 86399)
    Scheduled::Transfer.create!(from_stop_internal_id: "127", to_stop_internal_id: "D16", min_transfer_time: 420, access_time_from: 21600, access_time_to: 86399)
  end
end
