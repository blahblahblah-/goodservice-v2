class Trip
  attr_reader :route_id, :direction, :timestamp, :stops
  attr_accessor :id, :previous_trip, :delayed_time

  def initialize(route_id, direction, id, timestamp, trip_update)
    @route_id = route_id
    @direction = direction
    @id = id
    @timestamp = timestamp
    @stops = trip_update.stop_time_update.to_h {|update|
      [update.stop_id[0..2], (update.departure || update.arrival).time]
    }
  end

  def similar(trip)
    trip.route_id == route_id &&
      trip.direction == direction &&
      destination == trip.destination &&
      (destination_time - trip.destination_time).abs <= 3.minutes.to_i &&
      (trip.stops.keys - stops.keys).size <= 1
  end

  def stop_ids
    stops.keys
  end

  def previous_stop
    return unless upcoming_stop
    i = stops.keys.index(upcoming_stop)
    return unless i && i > 0

    stops.keys[i - 1]
  end

  def previous_stop_arrival_time
    previous_stop && stops[previous_stop]
  end

  def upcoming_stop
    stops.find { |_, v| v > timestamp }&.first
  end

  def upcoming_stop_arrival_time
    stops.find { |_, v| v > timestamp }&.last || timestamp
  end

  def time_until_upcoming_stop
    (stops.find { |_, v| v > timestamp }&.last || timestamp) - timestamp
  end

  def upcoming_stops
    stops.select { |_, v| v > timestamp }.map(&:first)
  end

  def upcoming_stops_by_at_least_a_minute
    stops.select { |_, v| v >= (timestamp + 1.minute) }.map(&:first)
  end

  def stops_behind(trip)
    i = upcoming_stops.index(trip.upcoming_stop)
    return [] unless i && i > 0

    upcoming_stops[0..i]
  end

  def stops_made
    return [] unless previous_trip

    previous_trip.stops.select { |stop_id, time|
      !stops.keys.include?(stop_id)
    }.map { |stop_id, time|
      [stop_id, [timestamp, time].min]
    }.to_h
  end

  def update_delay!
    self.delayed_time = 0
    return unless previous_trip
    return unless next_stop_time
    return unless (next_stop_time - timestamp) <= 1080
    return if stops_made.present? && (destination_time - previous_trip.destination_time) <= 30
    self.delayed_time = previous_trip.delayed_time if previous_trip.delayed_time
    self.delayed_time += (destination_time - previous_trip.destination_time)
  end

  def time_between_stops(time_limit)
    stops.select { |_, time| time <= timestamp + time_limit}.each_cons(2).map { |a, b| ["#{a.first}-#{b.first}", b.last - a.last]}.to_h
  end

  def next_stop_time
    stops.first&.last
  end

  def destination
    stops.keys.last
  end

  def destination_time
    stops.values.last
  end
end