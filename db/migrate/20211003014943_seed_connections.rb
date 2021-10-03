class SeedConnections < ActiveRecord::Migration[6.1]
  def change
    Scheduled::Connection.create!(from_stop_internal_id: "A28", name: "LIRR", min_transfer_time: 300, mode: "train")
    Scheduled::Connection.create!(from_stop_internal_id: "128", name: "LIRR", min_transfer_time: 300, mode: "train")

    Scheduled::Connection.create!(from_stop_internal_id: "720", name: "LIRR", min_transfer_time: 300, mode: "train", access_time_from: 55800, access_time_to: 67200)

    Scheduled::Connection.create!(from_stop_internal_id: "712", name: "LIRR", min_transfer_time: 300, mode: "train")

    Scheduled::Connection.create!(from_stop_internal_id: "701", name: "LIRR", min_transfer_time: 300, mode: "train")

    Scheduled::Connection.create!(from_stop_internal_id: "L24", name: "LIRR", min_transfer_time: 300, mode: "train")
    Scheduled::Connection.create!(from_stop_internal_id: "A51", name: "LIRR", min_transfer_time: 300, mode: "train")

    Scheduled::Connection.create!(from_stop_internal_id: "G06", name: "LIRR", min_transfer_time: 300, mode: "train")

    Scheduled::Connection.create!(from_stop_internal_id: "235", name: "LIRR", min_transfer_time: 300, mode: "train")
    Scheduled::Connection.create!(from_stop_internal_id: "R31", name: "LIRR", min_transfer_time: 300, mode: "train")
    Scheduled::Connection.create!(from_stop_internal_id: "D24", name: "LIRR", min_transfer_time: 300, mode: "train")

    Scheduled::Connection.create!(from_stop_internal_id: "A46", name: "LIRR", min_transfer_time: 300, mode: "train")

    Scheduled::Connection.create!(from_stop_internal_id: "631", name: "Metro-North", mode: "train", min_transfer_time: 300, access_time_from: 19800, access_time_to: 86399)
    Scheduled::Connection.create!(from_stop_internal_id: "723", name: "Metro-North", mode: "train", min_transfer_time: 300, access_time_from: 19800, access_time_to: 86399)
    Scheduled::Connection.create!(from_stop_internal_id: "901", name: "Metro-North", mode: "train", min_transfer_time: 300, access_time_from: 19800, access_time_to: 86399)

    Scheduled::Connection.create!(from_stop_internal_id: "621", name: "Metro-North", mode: "train", min_transfer_time: 300, access_time_from: 19800, access_time_to: 86399)

    Scheduled::Connection.create!(from_stop_internal_id: "205", name: "Metro-North", mode: "train", min_transfer_time: 300, access_time_from: 19800, access_time_to: 86399)

    Scheduled::Connection.create!(from_stop_internal_id: "106", name: "Metro-North", mode: "train", min_transfer_time: 300, access_time_from: 19800, access_time_to: 86399)

    Scheduled::Connection.create!(from_stop_internal_id: "A28", name: "NJ Transit", mode: "train", min_transfer_time: 300, access_time_from: 18000, access_time_to: 86399)    
    Scheduled::Connection.create!(from_stop_internal_id: "128", name: "NJ Transit", mode: "train", min_transfer_time: 300, access_time_from: 18000, access_time_to: 86399)    

    Scheduled::Connection.create!(from_stop_internal_id: "D17", name: "PATH", mode: "subway", min_transfer_time: 180)
    Scheduled::Connection.create!(from_stop_internal_id: "R17", name: "PATH", mode: "subway", min_transfer_time: 180)

    Scheduled::Connection.create!(from_stop_internal_id: "D18", name: "PATH", mode: "subway", min_transfer_time: 180)

    Scheduled::Connection.create!(from_stop_internal_id: "D19", name: "PATH", mode: "subway", min_transfer_time: 180)
    Scheduled::Connection.create!(from_stop_internal_id: "132", name: "PATH", mode: "subway", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "L02", name: "PATH", mode: "subway", min_transfer_time: 180)

    Scheduled::Connection.create!(from_stop_internal_id: "A32", name: "PATH", mode: "subway", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "D20", name: "PATH", mode: "subway", min_transfer_time: 300)

    Scheduled::Connection.create!(from_stop_internal_id: "138", name: "PATH", mode: "subway", min_transfer_time: 180)
    Scheduled::Connection.create!(from_stop_internal_id: "R25", name: "PATH", mode: "subway", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "E01", name: "PATH", mode: "subway", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "A36", name: "PATH", mode: "subway", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "228", name: "PATH", mode: "subway", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "M22", name: "PATH", mode: "subway", min_transfer_time: 300)

    Scheduled::Connection.create!(from_stop_internal_id: "A27", name: "Port Authority", mode: "bus", min_transfer_time: 180)
    Scheduled::Connection.create!(from_stop_internal_id: "R16", name: "Port Authority", mode: "bus", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "127", name: "Port Authority", mode: "bus", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "725", name: "Port Authority", mode: "bus", min_transfer_time: 180)
    Scheduled::Connection.create!(from_stop_internal_id: "902", name: "Port Authority", mode: "bus", min_transfer_time: 300)

    Scheduled::Connection.create!(from_stop_internal_id: "A28", name: "Amtrak", mode: "train", min_transfer_time: 300, access_time_from: 18000, access_time_to: 86399)
    Scheduled::Connection.create!(from_stop_internal_id: "128", name: "Amtrak", mode: "train", min_transfer_time: 300, access_time_from: 18000, access_time_to: 86399)

    Scheduled::Connection.create!(from_stop_internal_id: "G06", name: "JFK AirTrain", mode: "plane", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "H03", name: "JFK AirTrain", mode: "plane", min_transfer_time: 300)

    Scheduled::Connection.create!(from_stop_internal_id: "142", name: "SI Ferry", mode: "ship", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "R27", name: "SI Ferry", mode: "ship", min_transfer_time: 300)
    Scheduled::Connection.create!(from_stop_internal_id: "420", name: "SI Ferry", mode: "ship", min_transfer_time: 300)
  end
end
