class Processed::Trip
  delegate :id, :stops_behind, :timestamp, :upcoming_stop, :time_until_upcoming_stop, :delayed_time, to: :trip

  attr_reader :trip, :progress_until_upcoming_stop,
    :estimated_time_until_upcoming_stop, :estimated_time_behind_next_train, :time_behind_next_train

  def initialize(trip, next_trip, routing)
    @trip = trip
    calculate_time_until_next_trip!(next_trip, routing)
  end

  private

  def calculate_time_until_next_trip!(next_trip, routing)
    until_upcoming_stop, @progress_until_upcoming_stop = self.class.estimate_time_until_upcoming_stop(trip, routing)
    @estimated_time_until_upcoming_stop = until_upcoming_stop / 60

    return unless next_trip

    if stops_behind(next_trip).present?
      @estimated_time_behind_next_train = (estimated_time_until_upcoming_stop +
        trip.stops_behind(next_trip).each_cons(2).map { |a_stop, b_stop|
          RouteProcessor.average_travel_time(a_stop, b_stop, timestamp)
        }.sum -
        self.class.estimate_time_until_upcoming_stop(next_trip, routing).first) / 60
      @time_behind_next_train = (time_until_upcoming_stop +
        trip.stops_behind(next_trip).each_cons(2).map { |a_stop, b_stop|
          RedisStore.supplementary_scheduled_travel_time(a_stop, b_stop)
        }.sum -
        next_trip.time_until_upcoming_stop) / 60
    else
      @estimated_time_behind_next_train = (estimated_time_until_upcoming_stop - self.class.estimate_time_until_upcoming_stop(trip, routing).first) / 60
      @time_behind_next_train = (time_until_upcoming_stop - next_trip.time_until_upcoming_stop) / 60
    end
  end

  def self.estimate_time_until_upcoming_stop(current_trip, routing)
      next_stop = current_trip.upcoming_stop
      i = routing.index(next_stop)
      return current_trip.time_until_upcoming_stop, 0 unless i && i > 0

      previous_stop = routing[i - 1]
      predicted_time_until_next_stop = current_trip.time_until_upcoming_stop
      predicted_time_between_stops = RedisStore.supplementary_scheduled_travel_time(previous_stop, next_stop)
      actual_time_between_stops = RouteProcessor.average_travel_time(previous_stop, next_stop, current_trip.timestamp)

      progress = (predicted_time_until_next_stop / predicted_time_between_stops)
      until_upcoming_stop = progress * actual_time_between_stops

      return until_upcoming_stop, progress
    end
end