require "csv"

Scheduled::Route.create(name: '1', internal_id: '1', color: 'db2828')
Scheduled::Route.create(name: '2', internal_id: '2', color: 'db2828')
Scheduled::Route.create(name: '3', internal_id: '3', color: 'db2828')
Scheduled::Route.create(name: '4', internal_id: '4', color: '21ba45')
Scheduled::Route.create(name: '5', internal_id: '5', color: '21ba45')
Scheduled::Route.create(name: '6', internal_id: '6', color: '21ba45')
Scheduled::Route.create(name: '6X', internal_id: '6X', color: '21ba45', visible: false)
Scheduled::Route.create(name: '7', internal_id: '7', color: 'a333c8')
Scheduled::Route.create(name: '7X', internal_id: '7X', color: 'a333c8', visible: false)
Scheduled::Route.create(name: 'S', alternate_name: '42 St Shuttle', internal_id: 'GS', color: '767676')
Scheduled::Route.create(name: 'A', internal_id: 'A', color: '2185d0')
Scheduled::Route.create(name: 'B', internal_id: 'B', color: 'f2711c')
Scheduled::Route.create(name: 'C', internal_id: 'C', color: '2185d0')
Scheduled::Route.create(name: 'D', internal_id: 'D', color: 'f2711c')
Scheduled::Route.create(name: 'E', internal_id: 'E', color: '2185d0')
Scheduled::Route.create(name: 'F', internal_id: 'F', color: 'f2711c')
Scheduled::Route.create(name: 'FX', internal_id: 'FX', color: 'f2711c', visible: false)
Scheduled::Route.create(name: 'S', alternate_name: 'Franklin Avenue Shuttle', internal_id: 'FS', color: '767676')
Scheduled::Route.create(name: 'G', internal_id: 'G', color: 'b5cc18')
Scheduled::Route.create(name: 'J', internal_id: 'J', color: 'a5673f')
Scheduled::Route.create(name: 'L', internal_id: 'L', color: 'A0A0A0')
Scheduled::Route.create(name: 'M', internal_id: 'M', color: 'f2711c')
Scheduled::Route.create(name: 'N', internal_id: 'N', color: 'fbbd08', text_color: '000000')
Scheduled::Route.create(name: 'Q', internal_id: 'Q', color: 'fbbd08', text_color: '000000')
Scheduled::Route.create(name: 'R', internal_id: 'R', color: 'fbbd08', text_color: '000000')
Scheduled::Route.create(name: 'S', alternate_name: 'Rockaway Park Shuttle', internal_id: 'H', color: '767676')
Scheduled::Route.create(name: 'W', internal_id: 'W', color: 'fbbd08', text_color: '000000')
Scheduled::Route.create(name: 'Z', internal_id: 'Z', color: 'a5673f')
Scheduled::Route.create(name: 'SIR', internal_id: 'SI', color: '2185d0', visible: false)

csv_text = File.read(Rails.root.join('import', 'calendar.txt'))
csv = CSV.parse(csv_text, headers: true)
csv.each do |row|
  s = Scheduled::Schedule.new
  s.service_id = row['service_id']
  s.monday = row['monday']
  s.tuesday = row['tuesday']
  s.wednesday = row['wednesday']
  s.thursday = row['thursday']
  s.friday = row['friday']
  s.saturday = row['saturday']
  s.sunday = row['sunday']
  s.start_date = row['start_date']
  s.end_date = row['end_date']
  s.save!
  puts "#{s.service_id} saved"
end

csv_text = File.read(Rails.root.join('import', 'calendar_dates.txt'))
csv = CSV.parse(csv_text, headers: true)
csv.each do |row|
  c = Scheduled::CalendarException.new
  c.schedule_service_id = row['service_id']
  c.date = row['date']
  c.exception_type = row['exception_type']
  c.save!
  puts "#{c.date} saved"
end

csv_text = File.read(Rails.root.join('import', 'stops.txt'))
csv = CSV.parse(csv_text, headers: true)
csv.each do |row|
  s = Scheduled::Stop.new
  s.internal_id = row['stop_id']
  next if s.internal_id.end_with?('N') || s.internal_id.end_with?('S')
  next if s.internal_id == 'H19'
  next if s.internal_id == 'N12'
  s.stop_name = row['stop_name']
  s.save!
  puts "#{s.internal_id} saved"
end

csv_text = File.read(Rails.root.join('import', 'trips.txt'))
csv = CSV.parse(csv_text, headers: true)
csv.each do |row|
  t = Scheduled::Trip.new
  t.route_internal_id = row['route_id']
  t.route_internal_id = "5" if t.route_internal_id == "5X"
  t.schedule_service_id = row['service_id']
  t.internal_id = row['trip_id']
  t.destination = row['trip_headsign']
  t.destination = t.destination.gsub(/-/, ' - ')
  t.destination = "34 St - Hudson Yards" if t.destination == "34 St - 11 Av"
  t.destination = "Essex St" if t.destination == "Delancy St - Essex St"
  t.destination = "Court Sq" if t.destination == "Court Sq - 23 St"
  t.direction = row['direction_id']
  t.save!
  puts "#{t.internal_id} saved"
end

CSV.foreach(Rails.root.join('import', 'stop_times.txt'), headers: true) do |row|
  s = Scheduled::StopTime.new
  s.trip_internal_id = row['trip_id']
  str = row['departure_time']
  array = str.split(':').map(&:to_i)
  s.departure_time = array[0] * 3600 + array[1] * 60 + array[2]
  s.stop_internal_id = row['stop_id'][0..2]
  s.stop_sequence = row['stop_sequence']
  s.save!
  puts "#{s.trip_internal_id} at #{s.stop_internal_id} saved"
end

csv_text = File.read(Rails.root.join('import', 'transfers.txt'))
csv = CSV.parse(csv_text, headers: true)
csv.each do |row|
  t = Scheduled::Transfer.new
  t.from_stop_internal_id = row['from_stop_id']
  t.to_stop_internal_id = row['to_stop_id']
  t.min_transfer_time = row['min_transfer_time']
  t.save!
  puts "Transfer from #{t.from_stop_internal_id} to #{t.to_stop_internal_id} saved"
end

transfer = Scheduled::Transfer.find_by!(from_stop_internal_id: 'R31', to_stop_internal_id: 'D24')
transfer.interchangeable_platforms = true
transfer.save!

transfer = Scheduled::Transfer.find_by!(from_stop_internal_id: 'D24', to_stop_internal_id: 'R31')
transfer.interchangeable_platforms = true
transfer.save!

transfer = Scheduled::Transfer.find_by!(from_stop_internal_id: '222', to_stop_internal_id: '415')
transfer.interchangeable_platforms = true
transfer.save!

transfer = Scheduled::Transfer.find_by!(from_stop_internal_id: '415', to_stop_internal_id: '222')
transfer.interchangeable_platforms = true
transfer.save!

transfer = Scheduled::Transfer.find_by!(from_stop_internal_id: 'Q01', to_stop_internal_id: 'R23')
transfer.interchangeable_platforms = true
transfer.save!

transfer = Scheduled::Transfer.find_by!(from_stop_internal_id: 'R23', to_stop_internal_id: 'Q01')
transfer.interchangeable_platforms = true
transfer.save!

transfer = Scheduled::Transfer.find_by!(from_stop_internal_id: 'A12', to_stop_internal_id: 'D13')
transfer.interchangeable_platforms = true
transfer.save!

transfer = Scheduled::Transfer.find_by!(from_stop_internal_id: 'D13', to_stop_internal_id: 'A12')
transfer.interchangeable_platforms = true
transfer.save!

transfer = Scheduled::Transfer.find_by!(from_stop_internal_id: 'A32', to_stop_internal_id: 'D20')
transfer.interchangeable_platforms = true
transfer.save!

transfer = Scheduled::Transfer.find_by!(from_stop_internal_id: 'D20', to_stop_internal_id: 'A32')
transfer.interchangeable_platforms = true
transfer.save!

# SeedTimesSqToBryantPkTransfer
Scheduled::Transfer.create!(from_stop_internal_id: "D16", to_stop_internal_id: "902", min_transfer_time: 300, access_time_from: 21600, access_time_to: 86399)
Scheduled::Transfer.create!(from_stop_internal_id: "D16", to_stop_internal_id: "R16", min_transfer_time: 420, access_time_from: 21600, access_time_to: 86399)
Scheduled::Transfer.create!(from_stop_internal_id: "D16", to_stop_internal_id: "127", min_transfer_time: 420, access_time_from: 21600, access_time_to: 86399)
Scheduled::Transfer.create!(from_stop_internal_id: "902", to_stop_internal_id: "D16", min_transfer_time: 300, access_time_from: 21600, access_time_to: 86399)
Scheduled::Transfer.create!(from_stop_internal_id: "R16", to_stop_internal_id: "D16", min_transfer_time: 420, access_time_from: 21600, access_time_to: 86399)
Scheduled::Transfer.create!(from_stop_internal_id: "127", to_stop_internal_id: "D16", min_transfer_time: 420, access_time_from: 21600, access_time_to: 86399)

# SeedBusTransfers
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

# SeedConnections
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

Scheduled::Connection.create!(from_stop_internal_id: "A07", name: "GWB Bus Station", mode: "bus", min_transfer_time: 300)

Scheduled::Connection.create!(from_stop_internal_id: "S31", name: "SI Ferry", mode: "ship", min_transfer_time: 300)
Scheduled::BusTransfer.create!(from_stop_internal_id: "J12", bus_route: "Q10 to JFK", min_transfer_time: 300, airport_connection: true)
Scheduled::Connection.create!(from_stop_internal_id: "418", name: "PATH", mode: "subway", min_transfer_time: 300)

csv_text = File.read(Rails.root.join('import', 'Stations.csv'))
csv = CSV.parse(csv_text, headers: true)
csv.each do |row|
  stop_id = row['GTFS Stop ID']
  stop = Scheduled::Stop.find_by!(internal_id: stop_id)
  stop.latitude = row['GTFS Latitude']
  stop.longitude = row['GTFS Longitude']
  stop.save!
  puts "Geolocation for #{stop_id} saved"
end
