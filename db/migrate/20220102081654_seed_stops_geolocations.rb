class SeedStopsGeolocations < ActiveRecord::Migration[6.1]
  def change
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
  end
end
