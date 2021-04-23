class DelayNotification
  attr_accessor :routes, :direction, :stops, :affected_sections, :destinations, :last_tweet_id, :last_tweet_ids, :last_tweet_time, :mins_since_observed

  def initialize(route, direction, stops, routing, destinations)
    @routes = [route]
    @direction = direction
    @stops = stops
    @affected_sections = [stops]
    @destinations = destinations.uniq
    @mins_since_observed = 0
    @last_tweet_ids = {}
  end

  def append!(route, new_stops, routing, new_destinations)
    @routes = (routes + [route]).uniq.sort
    @destinations = (destinations + new_destinations).uniq
    matched_section = affected_sections.find { |section| routing.each_cons(section.size).any? { |arr| arr == section } }

    if matched_section
      indices = [matched_section.first, matched_section.last, new_stops.first, new_stops.last].map {|s| routing.index(s) }
      @affected_sections.delete(matched_section)
      @affected_sections << routing[indices.min..indices.max]
    else
      indices = [stops.first, stops.last, new_stops.first, new_stops.last].map {|s| routing.index(s) }
      @affected_sections = [] unless affected_sections
      @affected_sections << routing[indices.min..indices.max]
    end
  end

  def match_routing?(routing)
    routing.each_cons(stops.size).any? { |arr| arr == stops }
  end

  def update_not_observed!
    @mins_since_observed += 1
  end
end