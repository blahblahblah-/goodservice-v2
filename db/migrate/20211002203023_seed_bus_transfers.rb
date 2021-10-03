class SeedBusTransfers < ActiveRecord::Migration[6.1]
  def change
    Scheduled::BusTransfer.create!(from_stop_internal_id: "113", bus_route: "Bx6 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 75599)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A11", bus_route: "Bx6 SBS", min_transfer_time: 300, access_time_from: 21600, access_time_to: 75599)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "D11", bus_route: "Bx6 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 75599)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "414", bus_route: "Bx6 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 75599)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "218", bus_route: "Bx6 SBS", min_transfer_time: 300, access_time_from: 21600, access_time_to: 75599)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "613", bus_route: "Bx6 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 75599)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "A02", bus_route: "Bx12 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "108", bus_route: "Bx12 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "407", bus_route: "Bx12 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "D05", bus_route: "Bx12 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "211", bus_route: "Bx12 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "504", bus_route: "Bx12 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "601", bus_route: "Bx12 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 86399)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "221", bus_route: "Bx41 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 75600)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "208", bus_route: "Bx41 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 75600)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "M18", bus_route: "M14A SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "F15", bus_route: "M14A SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "L06", bus_route: "M14 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "L01", bus_route: "M14 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "635", bus_route: "M14 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "R20", bus_route: "M14 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "D19", bus_route: "M14 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "132", bus_route: "M14 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A31", bus_route: "M14 SBS", min_transfer_time: 180)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "142", bus_route: "M15 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 79199)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "R27", bus_route: "M15 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 79199)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "F14", bus_route: "M15 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 79199)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "L06", bus_route: "M15 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 79199)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "Q03", bus_route: "M15 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 79199)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "Q04", bus_route: "M15 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 79199)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "Q05", bus_route: "M15 SBS", min_transfer_time: 300, access_time_from: 18000, access_time_to: 79199)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "R19", bus_route: "M23 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A30", bus_route: "M23 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "D18", bus_route: "M23 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "130", bus_route: "M23 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "634", bus_route: "M23 SBS", min_transfer_time: 180)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "726", bus_route: "M34 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A28", bus_route: "M34 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "128", bus_route: "M34 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "R17", bus_route: "M34 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "D17", bus_route: "M34 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "632", bus_route: "M34 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "117", bus_route: "M60 SBS to LGA", min_transfer_time: 180, airport_connection: true)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A15", bus_route: "M60 SBS to LGA", min_transfer_time: 180, airport_connection: true)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "225", bus_route: "M60 SBS to LGA", min_transfer_time: 180, airport_connection: true)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "621", bus_route: "M60 SBS to LGA", min_transfer_time: 180, airport_connection: true)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "R03", bus_route: "M60 SBS to LGA", min_transfer_time: 180, airport_connection: true)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "122", bus_route: "M79 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A21", bus_route: "M79 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "627", bus_route: "M79 SBS", min_transfer_time: 300)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "121", bus_route: "M86 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A20", bus_route: "M86 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "626", bus_route: "M86 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "Q04", bus_route: "M86 SBS", min_transfer_time: 180)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "G05", bus_route: "Q44 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "G06", bus_route: "Q44 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "F05", bus_route: "Q44 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "F04", bus_route: "Q44 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "701", bus_route: "Q44 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "608", bus_route: "Q44 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "214", bus_route: "Q44 SBS", min_transfer_time: 180)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "712", bus_route: "Q70 SBS to LGA", airport_connection: true)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "710", bus_route: "Q70 SBS to LGA", airport_connection: true)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "G14", bus_route: "Q70 SBS to LGA", airport_connection: true)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "S18", bus_route: "Q52 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "G11", bus_route: "Q52 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "J15", bus_route: "Q52 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A61", bus_route: "Q52 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "H12", bus_route: "Q52 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "H06", bus_route: "Q52 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 86399)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "712", bus_route: "Q53 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "G14", bus_route: "Q53 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "710", bus_route: "Q53 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "G12", bus_route: "Q53 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "G11", bus_route: "Q53 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "J15", bus_route: "Q53 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A61", bus_route: "Q53 SBS", min_transfer_time: 180)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "H15", bus_route: "Q53 SBS", min_transfer_time: 180)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "M16", bus_route: "B44 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 82799)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A46", bus_route: "B44 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 82799)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "248", bus_route: "B44 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 82799)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "242", bus_route: "B44 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 82799)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "247", bus_route: "B44 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 82799)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "J31", bus_route: "B46 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 82799)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A48", bus_route: "B46 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 82799)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "250", bus_route: "B46 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 82799)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "L29", bus_route: "B82 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 82799)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "D35", bus_route: "B82 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 82799)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "F35", bus_route: "B82 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 82799)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "N08", bus_route: "B82 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 82799)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "B21", bus_route: "B82 SBS", min_transfer_time: 180, access_time_from: 21600, access_time_to: 82799)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "R44", bus_route: "S79 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "S18", bus_route: "S79 SBS", min_transfer_time: 180, access_time_from: 18000, access_time_to: 86399)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "710", bus_route: "Q47 to LGA", airport_connection: true, access_time_from: 18000, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "G14", bus_route: "Q47 to LGA", airport_connection: true, access_time_from: 18000, access_time_to: 86399)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "702", bus_route: "Q48 to LGA", airport_connection: true, access_time_from: 18000, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "701", bus_route: "Q48 to LGA", airport_connection: true, access_time_from: 18000, access_time_to: 86399)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "707", bus_route: "Q72 to LGA", airport_connection: true, access_time_from: 18000, access_time_to: 86399)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "G10", bus_route: "Q72 to LGA", airport_connection: true, access_time_from: 18000, access_time_to: 86399)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "F01", bus_route: "Q3 to JFK", airport_connection: true)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "F06", bus_route: "Q10 to JFK", airport_connection: true)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "A65", bus_route: "Q10 to JFK", airport_connection: true)

    Scheduled::BusTransfer.create!(from_stop_internal_id: "257", bus_route: "B15 to JFK", airport_connection: true)
    Scheduled::BusTransfer.create!(from_stop_internal_id: "L27", bus_route: "B15 to JFK", airport_connection: true)
  end
end
