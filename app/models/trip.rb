class Trip
  attr_reader :route_id, :direction, :timestamp, :stops
  attr_accessor :id, :previous_trip, :delay

  def initialize(route_id, direction, id, timestamp, trip_update)
    @route_id = route_id
    @direction = direction
    @id = id
    @timestamp = timestamp
    @stops = trip_update.stop_time_update.to_h {|update|
      [update.stop_id, (update.departure || update.arrival).time]
    }
  end

  def similar(trip)
    trip.route_id == route_id &&
      trip.direction == direction &&
      destination == trip.destination &&
      (destination_time - trip.destination_time).abs <= 3.minutes.to_i &&
      (trip.stops.keys - stops.keys).size <= 1
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
    self.delay = 0
    return unless previous_trip
    return unless (next_stop_time - timestamp) <= 600
    return if stops_made.present?

    self.delay += (destination_time - previous_trip.destination_time)
  end

  def next_stop_time
    stops.first.last
  end

  def destination
    stops.keys.last
  end

  def destination_time
    stops.values.last
  end
end