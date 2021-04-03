class Processed::Trip
  delegate :id, :route_id, :stops_behind, :timestamp, :direction, :upcoming_stop, :upcoming_stops, :time_until_upcoming_stop,
  :effective_delayed_time, :delayed_time, :delayed?,
  :upcoming_stop_arrival_time, :destination, :stops, :stop_ids, :schedule_discrepancy, :past_stops, to: :trip

  attr_reader :trip, :previous_stop_arrival_time, :previous_stop,
    :estimated_upcoming_stop_arrival_time, :estimated_time_behind_next_train, :time_behind_next_train, :estimated_time_until_destination

  def initialize(trip, next_trip, routing)
    @trip = trip

    if trip.previous_stop
      @previous_stop = trip.previous_stop
      @previous_stop_arrival_time = trip.previous_stop_arrival_time
    else
      determine_previous_stop_info!(routing)
    end
    calculate_time_until_next_trip!(next_trip, routing)
  end

  private

  def determine_previous_stop_info!(routing)
    @previous_stop, @previous_stop_arrival_time = self.class.determine_previous_stop_and_arrival_time(trip)
  end

  def calculate_time_until_next_trip!(next_trip, routing)
    if previous_stop_arrival_time
      @estimated_upcoming_stop_arrival_time = previous_stop_arrival_time + RouteProcessor.average_travel_time(previous_stop, upcoming_stop, timestamp)
    else
      @estimated_upcoming_stop_arrival_time = timestamp + self.class.extrapolate_time_until_upcoming_stop(trip, routing, timestamp)
    end

    estimated_time_until_upcoming_stop = estimated_upcoming_stop_arrival_time - timestamp

    unless next_trip
      if routing.last == destination
        @estimated_time_until_destination = estimated_time_until_upcoming_stop +
          upcoming_stops[1, upcoming_stops.length - 1].each_cons(2).map { |a_stop, b_stop|
            RouteProcessor.average_travel_time(a_stop, b_stop, timestamp) || RedisStore.supplemented_scheduled_travel_time(a_stop, b_stop) || (stops[b_stop] - stops[a_stop])
          }.sum
      end
      return
    end

    next_trip_previous_stop, next_trip_previous_stop_time = self.class.determine_previous_stop_and_arrival_time(next_trip)
    if next_trip_previous_stop_time
      next_trip_upcoming_stop = next_trip.upcoming_stop
      estimated_time_for_next_trip_until_its_upcoming_stop = [(next_trip_previous_stop_time + RouteProcessor.average_travel_time(next_trip_previous_stop, next_trip_upcoming_stop, timestamp)) - timestamp, 0].max || next_trip.time_until_upcoming_stop(time_ref: timestamp)
    else
      estimated_time_for_next_trip_until_its_upcoming_stop = self.class.extrapolate_time_until_upcoming_stop(next_trip, routing, timestamp)
    end

    if stops_behind(next_trip).present?
      @estimated_time_behind_next_train = [estimated_time_until_upcoming_stop +
        trip.stops_behind(next_trip).each_cons(2).map { |a_stop, b_stop|
          RouteProcessor.average_travel_time(a_stop, b_stop, timestamp) || RedisStore.supplemented_scheduled_travel_time(a_stop, b_stop) || (stops[b_stop] - stops[a_stop])
        }.sum -
        estimated_time_for_next_trip_until_its_upcoming_stop, 0].max
      @time_behind_next_train = [time_until_upcoming_stop +
        trip.stops_behind(next_trip).each_cons(2).map { |a_stop, b_stop|
          stops[b_stop] - stops[a_stop]
        }.sum -
        next_trip.time_until_upcoming_stop(time_ref: timestamp), 0].max
    else
      @estimated_time_behind_next_train = [estimated_time_until_upcoming_stop - estimated_time_for_next_trip_until_its_upcoming_stop, 0].max
      @time_behind_next_train = [time_until_upcoming_stop - next_trip.time_until_upcoming_stop(time_ref: timestamp), 0].max
    end
  end

  def self.determine_previous_stop_and_arrival_time(current_trip)
    return current_trip.past_stops&.keys&.last, current_trip.past_stops&.values&.last
  end

  def self.extrapolate_time_until_upcoming_stop(current_trip, routing, time_ref)
    next_stop = current_trip.upcoming_stop
    i = routing.index(next_stop)
    return current_trip.time_until_upcoming_stop(time_ref: time_ref) unless i && i > 0

    previous_stop = routing[i - 1]
    predicted_time_until_next_stop = current_trip.time_until_upcoming_stop(time_ref: time_ref)
    predicted_time_between_stops = RedisStore.supplemented_scheduled_travel_time(previous_stop, next_stop) || current_trip.stops[previous_stop] && (current_trip.stops[next_stop] - current_trip.stops[previous_stop]) || 120
    actual_time_between_stops = RouteProcessor.average_travel_time(previous_stop, next_stop, current_trip.timestamp)

    progress = (predicted_time_until_next_stop / predicted_time_between_stops)
    until_upcoming_stop = progress * actual_time_between_stops

    until_upcoming_stop
  end
end