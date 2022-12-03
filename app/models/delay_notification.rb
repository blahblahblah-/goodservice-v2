class DelayNotification
  attr_accessor :routes, :direction, :stops, :affected_sections, :destinations, :last_tweet_ids, :last_tweet_times, :mins_since_observed, :tracks

  def initialize(route, direction, stops, routing, destinations, tracks = {})
    affected_section_indices = stops.map {|s| routing.index(s) }
    affected_section = routing[affected_section_indices.min..affected_section_indices.max]

    @routes = [route]
    @direction = direction
    @stops = stops
    @affected_sections = [affected_section]
    @destinations = destinations.uniq
    @mins_since_observed = 0
    @last_tweet_ids = {}
    @last_tweet_times = {}
    @tracks = tracks.slice(stops)
  end

  def append!(route, new_stops, routing, new_destinations, new_tracks)
    @routes = (routes + [route]).uniq.sort
    @destinations = (destinations + new_destinations).uniq
    matched_section = affected_sections.find { |section|
      routing.include?(section.first) && routing.include?(section.last)
    }
    @tracks = tracks.merge(new_tracks.slice(*new_stops))

    p "Routes: #{routes}"
    p "Existing sections: #{affected_sections}"
    p "New section: #{new_stops}"
    p "Matched section: #{matched_section}"

    if matched_section
      indices = [matched_section.first, matched_section.last, new_stops.first, new_stops.last].map {|s| routing.index(s) }
      @affected_sections.delete(matched_section)
      @affected_sections << routing[indices.min..indices.max]
    else
      indices = [stops.first, stops.last, new_stops.first, new_stops.last].map {|s| routing.index(s) }
      @affected_sections = [] unless affected_sections
      @affected_sections << routing[indices.min..indices.max]
    end
    p "Updated affected sections: #{affected_sections}"
  end

  def match_routing?(routing, potential_matched_stops, potential_stop_tracks)
    return false unless routing.each_cons(stops.size).any? { |arr| arr == stops && arr.all? { |s| !tracks[s] || !potential_stop_tracks[s] || tracks[s].any? { |t| potential_stop_tracks[s].include?(t) }}
    return true if stops.any? { |s| potential_matched_stops.include?(s) && (!tracks[s] || !potential_stop_tracks[s] || tracks[s].any? { |t| potential_stop_tracks[s].include?(t)) }}

    stop_indices = [stops.first, stops.last].map {|s| routing.index(s) }
    potential_stop_indices = [potential_matched_stops.first, potential_matched_stops.last].map {|s| routing.index(s) }
    diffs = stop_indices.flat_map { |s| potential_stop_indices.map {|ps| (ps - s).abs }}
    diffs.min <= 5
  end

  def update_not_observed!
    @mins_since_observed += 1
  end
end