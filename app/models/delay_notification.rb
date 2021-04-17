class DelayNotification
  attr_accessor :routes, :direction, :stops, :destinations, :last_tweet_id, :last_tweet_time, :mins_since_observed

  def initialize(route, direction, stops, routing, destinations)
    @routes = [route]
    @direction = direction
    @stops = stops
    @destinations = destinations.uniq
    @mins_since_observed = 0
  end

  def append!(route, new_stops, routing, new_destinations)
    @routes = (routes + [route]).uniq.sort
    indices = [stops.first, stops.last, new_stops.first, new_stops.last].map {|s| routing.index(s) }
    @stops = routing[indices.min..indices.max]
    @destinations = (destinations + new_destinations).uniq
  end

  def match_routing?(routing)
    routing.each_cons(stops.size).any? { |arr| arr == stops }
  end

  def update_not_observed!
    @mins_since_observed = mins_since_observed.to_i.succ
  end
end