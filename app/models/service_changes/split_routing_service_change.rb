class ServiceChanges::SplitRoutingServiceChange < ServiceChanges::ServiceChange
  attr_accessor :routing_tuples, :related_routes_by_segments

  def initialize(direction, routing_tuples)
    self.direction = direction
    self.affects_some_trains = false
    self.routing_tuples = routing_tuples
    self.related_routes_by_segments = {}
  end

  def match?(comparing_change)
    routing_tuples.size == comparing_change.routing_tuples.size &&
      routing_tuples.all? { |r| comparing_change.routing_tuples.any? { |c| c.first == r.last && c.last == r.first }}
  end

  def begin_of_route?
    false
  end

  def end_of_route?
    false
  end

  def applicable_to_routing?(_)
    true
  end

  def hash
    self.class.hash ^ self.direction.hash ^ self.routing_tuples.hash
  end

  def ==(other)
    self.class == other.class && self.direction == other.direction && self.routing_tuples == other.routing_tuples
  end
end