class SeedMoreBusTransfersAndConnections < ActiveRecord::Migration[6.1]
  def change
    Scheduled::BusTransfer.create!(from_stop_internal_id: "J12", bus_route: "Q10 to JFK", min_transfer_time: 300, airport_connection: true)
    Scheduled::Connection.create!(from_stop_internal_id: "418", name: "PATH", mode: "subway", min_transfer_time: 300)
  end
end
