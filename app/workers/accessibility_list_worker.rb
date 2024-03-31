class AccessibilityListWorker
  include Sidekiq::Worker
  sidekiq_options retry: 1, queue: 'low'

  FEED_URI = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fnyct_ene_equipments.json"

  def perform
    feed_data = retrieve_feed
    update_accessible_stops_list(feed_data)
  end

  private

  def retrieve_feed
    uri = URI.parse(FEED_URI)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Get.new uri
      request["x-api-key"] = ENV["MTA_KEY"]

      response = http.request request
      JSON.parse(response.body).select { |h| h['equipmenttype'] == 'EL' && h['ADA'] == 'Y' }
    end
  end

  def update_accessible_stops_list(data)
    accessible_stations = Set.new
    elevator_map = {}

    data.each do |elevator|
      stations = elevator['elevatorsgtfsstopid'].split('/')
      stations.each do |s|
        accessible_stations << s
      end
      elevator_map[elevator['equipmentno']] = stations
    end

    RedisStore.update_accessible_stops_list(accessible_stations.to_a.to_json)
    RedisStore.update_elevator_map(elevator_map.to_json)
  end
end
