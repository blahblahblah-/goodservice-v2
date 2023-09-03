class ServiceChanges::ServiceChange
  attr_accessor :direction, :stations_affected, :related_routes, :affects_some_trains, :origin, :destinations, :routing, :long_term_override

  def initialize(direction, stations_affected, origin, routing, long_term_override)
    self.direction = direction
    self.stations_affected = stations_affected
    self.affects_some_trains = false
    self.origin = origin
    self.routing = routing
    self.destinations = [routing&.last].compact
    self.long_term_override = long_term_override
  end

  def first_station
    stations_affected.first || stations_affected.second
  end

  def last_station
    stations_affected.last || stations_affected.second_to_last
  end

  def begin_of_route?
    stations_affected.first.nil?
  end

  def end_of_route?
    stations_affected.last.nil?
  end

  def intermediate_stations
    stations_affected - [first_station, last_station]
  end

  def applicable_to_routing?(routing)
    [first_station, last_station].all? { |s| routing.include?(s) }
  end

  def hash
    self.class.hash ^ self.direction.hash ^ self.stations_affected.first.hash ^ self.stations_affected.last.hash
  end

  def ==(other)
    self.class == other.class && self.direction == other.direction && self.stations_affected.first == other.stations_affected.first && self.stations_affected.last == other.stations_affected.last
  end

  def eql?(other)
    self == other
  end

  def as_json(options = {})
    {
      type: self.class.name.demodulize,
      stations_affected: stations_affected,
      related_routes: related_routes,
    }
  end

  def not_long_term?
    !self.long_term_override
  end
end