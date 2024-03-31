class AccessibilityStatusesWorker
  include Sidekiq::Worker
  sidekiq_options retry: 1, queue: 'low'

  FEED_URI = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fnyct_ene.json"

  def perform
    feed_data = retrieve_feed
    update_elevator_advisories(feed_data)
  end

  private

  def retrieve_feed
    uri = URI.parse(FEED_URI)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Get.new uri
      request["x-api-key"] = ENV["MTA_KEY"]

      response = http.request request
      JSON.parse(response.body).select{ |s| s['equipmenttype'] == 'EL' && s['ADA'] == 'Y' }
    end
  end

  def update_elevator_advisories(data)
    elevator_map_json = RedisStore.elevator_map
    return unless elevator_map_json
    elevator_map = JSON.parse(elevator_map_json)

    advisories = Hash.new { |h, k| h[k] = [] }
    data.each do |status|
      elevator_map[status['equipment']]&.flatten&.each do |station|
        advisories[station] << HTMLEntities.new.decode(status['serving'])
      end
    end

    RedisStore.update_elevator_advisories(advisories.to_json)
  end
end
