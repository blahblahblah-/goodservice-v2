class Trip
  attr_reader :route_id, :direction, :timestamp, :stops, :tracks
  attr_accessor :id, :previous_trip, :schedule, :past_stops, :latest, :is_assigned

  def initialize(route_id, direction, id, timestamp, trip_update, is_assigned)
    @route_id = route_id
    @direction = direction
    @id = id
    @timestamp = timestamp
    stop_time_hash = trip_update.stop_time_update.filter { |update|
      (update.departure&.time || update.arrival&.time || 0) > 0
    }.to_h {|update|
      [update.stop_id[0..2], update.departure&.time && update.departure.time > 0 ? update.departure.time : update.arrival&.time]
    }
    @stops = stop_time_hash
    @schedule = stop_time_hash
    @tracks = trip_update.stop_time_update.filter { |update|
      (update.departure&.time || update.arrival&.time || 0) > 0
    }.to_h {|update|
      [update.stop_id[0..2], update.nyct_stop_time_update.actual_track.presence || update.nyct_stop_time_update.scheduled_track ]
    }
    @past_stops = {}
    @latest = true
    @is_assigned = is_assigned
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
    past_stops&.keys&.last
  end

  def previous_stop_arrival_time
    past_stops&.values&.last
  end

  def scheduled_previous_stop_arrival_time
    schedule ? (schedule[previous_stop] || previous_stop_arrival_time) : previous_stop_arrival_time
  end

  def upcoming_stop(time_ref: timestamp)
    upcoming_stops(time_ref: time_ref).first
  end

  def upcoming_stop_arrival_time(time_ref: timestamp)
    stops[upcoming_stop(time_ref: time_ref)] || time_ref
  end

  def scheduled_upcoming_stop_arrival_time
    schedule ? (schedule[upcoming_stop] || upcoming_stop_arrival_time) : upcoming_stop_arrival_time
  end

  def time_until_upcoming_stop(time_ref: timestamp)
    upcoming_stop_arrival_time(time_ref: time_ref) - time_ref
  end

  def upcoming_stops(time_ref: timestamp)
    stops.select { |_, v| v > time_ref }.map(&:first) - past_stops.keys
  end

  def stops_behind(trip)
    i = upcoming_stops.index(trip.upcoming_stop)
    return [] unless i && i > 0

    upcoming_stops[0..i]
  end

  def update_stops_made!
    (@past_stops || {}).merge!(stops_made)
  end

  def stops_made
    return {} unless previous_trip

    previous_trip.stops.select { |stop_id, time|
      # Because you'd never know with these data
      !upcoming_stops.include?(stop_id) && !past_stops.include?(stop_id)
    }.map { |stop_id, time|
      [stop_id, [timestamp, time].min]
    }.to_h
  end

  def time_traveled_between_stops_made
    stops_hash = {}
    stops_made_hash = stops_made

    return {} unless stops_made_hash.present?

    # add last stop made
    if past_stops.present?
      i = past_stops.keys.index(stops_made.keys.first)
      # filter out stops already made
      if i && i > 0
        last_stop_id = past_stops.keys[i - 1]
        stops_hash[last_stop_id] = past_stops[last_stop_id]
      elsif i.nil?
        last_stop_id = past_stops.keys.last
        stops_hash[last_stop_id] = past_stops[last_stop_id]
      end
    end

    stops_hash.merge!(stops_made_hash).each_cons(2).to_h do |(a_stop, a_timestamp), (b_stop, b_timestamp)|
      ["#{a_stop}-#{b_stop}", b_timestamp - a_timestamp]
    end
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

  def schedule_discrepancy
    upcoming_stop_arrival_time - scheduled_upcoming_stop_arrival_time
  end

  def previous_stop_schedule_discrepancy
    return 0 unless previous_stop
    previous_stop_arrival_time - scheduled_previous_stop_arrival_time
  end

  def is_phantom?
    !is_assigned && previous_stop.present?
  end
end