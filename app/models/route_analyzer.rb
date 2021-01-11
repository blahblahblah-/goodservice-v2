class RouteAnalyzer
  def self.analyze_route(route_id, actual_trips, actual_routings, actual_headways_by_routes, timestamp, scheduled_trips, scheduled_routings, recent_scheduled_routings, scheduled_headways_by_routes)
    route = Scheduled::Route.find_by(internal_id: route_id)
    service_changes = ServiceChangeAnalyzer.service_change_summary(route_id, actual_routings, scheduled_routings, recent_scheduled_routings, timestamp)
    # status, secondary_status, direction_statuses, direction_secondary_statuses, service_summaries = route_status
    results = {
      id: route_id,
      name: route.name,
      color: route.color,
      text_color: route.text_color,
      alternate_name: route.alternate_name,
      # status: status,
      # secondary_status: secondary_status,
      # direction_statuses: direction_statuses,
      # direction_secondary_statuses: direction_secondary_statuses,
      # service_summaries: service_summaries,
      service_changes: service_changes,
      # service_change_summaries: service_change_summaries,
      scheduled_headways: scheduled_headways_by_routes,
      actual_headways: actual_headways_by_routes,
      scheduled: scheduled_trips.present?,
      visible: route.visible?,
      timestamp: timestamp
    }.to_json
    REDIS_CLIENT.set("route-status:#{route_id}", results, ex: 3600)
  end

  # def self.route_status

  # end
end