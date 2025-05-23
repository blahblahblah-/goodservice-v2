class Processed::Trip
  DELAY_THRESHOLD = 5.minutes.to_i
  delegate :id, :interval, :route_id, :stops_behind, :timestamp, :direction, :upcoming_stop, :time_until_upcoming_stop,
  :is_assigned, :is_phantom?,
  :upcoming_stop_arrival_time, :destination, :stops, :stop_ids, :tracks, :schedule_discrepancy, :past_stops, to: :trip

  attr_reader :trip, :previous_stop_arrival_time, :previous_stop, :calculated_upcoming_stop_arrival_time,
    :effective_calculated_upcoming_stop_arrival_time,
    :estimated_time_behind_next_train, :time_behind_next_train, :estimated_time_until_destination

  def initialize(trip, next_trip, routing, feed_timestamp)
    @trip = trip

    if trip.previous_stop
      @previous_stop = trip.previous_stop
      @previous_stop_arrival_time = trip.previous_stop_arrival_time
    else
      determine_previous_stop_info!(routing)
    end
    calculate_time_until_next_trip!(next_trip, routing, feed_timestamp)
  end

  def delayed_time
    [Time.current.to_i - calculated_upcoming_stop_arrival_time.to_i, 0].max
  end

  def effective_delayed_time
    [[schedule_discrepancy, delayed_time].min, 0].max
  end

  def delayed?
    effective_delayed_time >= DELAY_THRESHOLD
  end

  def upcoming_stops(time_ref: timestamp)
    if delayed?
      stops.map(&:first) - past_stops.keys
    end
    stops.select { |_, v| v > time_ref }.map(&:first) - past_stops.keys
  end

  def estimated_upcoming_stop_arrival_time
    if delayed?
      [effective_calculated_upcoming_stop_arrival_time, timestamp + 60].max + compensated_time
    end
    effective_calculated_upcoming_stop_arrival_time + compensated_time
  end

  private

  def determine_previous_stop_info!(routing)
    @previous_stop, @previous_stop_arrival_time = self.class.determine_previous_stop_and_arrival_time(trip)
  end

  def calculate_time_until_next_trip!(next_trip, routing, feed_timestamp)
    if previous_stop_arrival_time
      @calculated_upcoming_stop_arrival_time = previous_stop_arrival_time + RouteProcessor.average_travel_time(previous_stop, upcoming_stop)
    else
      @calculated_upcoming_stop_arrival_time = timestamp + self.class.extrapolate_time_until_upcoming_stop(trip, routing, timestamp)
    end

    @effective_calculated_upcoming_stop_arrival_time = calculated_upcoming_stop_arrival_time
    @effective_calculated_upcoming_stop_arrival_time = feed_timestamp if calculated_upcoming_stop_arrival_time < feed_timestamp

    estimated_time_until_upcoming_stop = effective_calculated_upcoming_stop_arrival_time - timestamp

    unless next_trip
      if routing.last == destination
        @estimated_time_until_destination = estimated_time_until_upcoming_stop +
          upcoming_stops[1, upcoming_stops.length - 1].each_cons(2).map { |a_stop, b_stop|
            RouteProcessor.average_travel_time(a_stop, b_stop) || RedisStore.supplemented_scheduled_travel_time(a_stop, b_stop) || (stops[b_stop] - stops[a_stop])
          }.sum
      end
      return
    end

    next_trip_previous_stop, next_trip_previous_stop_time = self.class.determine_previous_stop_and_arrival_time(next_trip)
    if next_trip_previous_stop_time
      next_trip_upcoming_stop = next_trip.upcoming_stop
      estimated_time_for_next_trip_until_its_upcoming_stop = [(next_trip_previous_stop_time + RouteProcessor.average_travel_time(next_trip_previous_stop, next_trip_upcoming_stop)) - timestamp, 0].max || next_trip.time_until_upcoming_stop(time_ref: timestamp)
    else
      estimated_time_for_next_trip_until_its_upcoming_stop = self.class.extrapolate_time_until_upcoming_stop(next_trip, routing, timestamp)
    end

    if stops_behind(next_trip).present?
      @estimated_time_behind_next_train = [estimated_time_until_upcoming_stop +
        trip.stops_behind(next_trip).each_cons(2).map { |a_stop, b_stop|
          RouteProcessor.average_travel_time(a_stop, b_stop) || RedisStore.supplemented_scheduled_travel_time(a_stop, b_stop) || (stops[b_stop] - stops[a_stop])
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

  def compensated_time
    return -30 if FeedRetrieverSpawningWorkerBase.feed_id_for(route_id) == ""
    0
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
    actual_time_between_stops = RouteProcessor.average_travel_time(previous_stop, next_stop)

    progress = (predicted_time_until_next_stop / predicted_time_between_stops)
    until_upcoming_stop = progress * actual_time_between_stops

    until_upcoming_stop
  end
end