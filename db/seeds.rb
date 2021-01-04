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
  s.stop_name = row['stop_name']
  s.parent_stop_id = row['parent_station'].presence
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
  s.stop_internal_id = row['stop_id']
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