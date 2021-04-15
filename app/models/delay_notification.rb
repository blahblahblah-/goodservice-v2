class DelayNotification
  attr_accessor :routes, :direction, :stops, :destinations, :last_tweet_id

  def initialize(route, direction, stops, routing)
    @routes = [route]
    @direction = direction
    @stops = stops
    @destinations = [routing.last]
  end

  def append!(route, new_stops, routing)
    @routes = (routes + [route]).uniq.sort
    indices = [stops.first, stops.last, new_stops.first, new_stops.last].map {|s| routing.index(s) }
    @stops = routing[indices.min..indices.max]
    @destinations = (destinations + [routing.last]).uniq
  end

  def match_routing?(routing)
    routing.each_cons(stops.size).any? { |arr| arr == stops }
  end
end