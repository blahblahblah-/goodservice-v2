class Scheduled::Trip < ActiveRecord::Base
  belongs_to :route, foreign_key: "route_internal_id", primary_key: "internal_id"
  belongs_to :schedule, foreign_key: "schedule_service_id", primary_key: "service_id"
  has_many :stop_times, -> { order("departure_time") }, foreign_key: "trip_internal_id", primary_key: "internal_id"

  DAY_IN_MINUTES = 86400

  def self.soon(current_timestamp, route_id, time_range: 30.minutes)
    current_time = Time.zone.at(current_timestamp)
    from_time = current_time - current_time.beginning_of_day
    to_time = current_time - current_time.beginning_of_day + time_range.to_i
    additional_departure_time_range = from_time..to_time
    additional_filters = route_id ? { route_internal_id: route_id} : {}

    if (current_time + time_range).to_date == current_time.to_date.tomorrow
      next_day_to_time = (current_time - current_time.beginning_of_day + time_range.to_i) % DAY_IN_MINUTES

      additional_departure_time_range = 0..next_day_to_time
    elsif current_time.hour < 4
      twenty_four_hr = current_time - current_time.beginning_of_day + DAY_IN_MINUTES
      time_after_twenty_four_hr = current_time - current_time.beginning_of_day + DAY_IN_MINUTES + time_range.to_i

      additional_departure_time_range = twenty_four_hr..time_after_twenty_four_hr
    end

    includes(:stop_times, :route).where(
      {
        stop_times: {
          departure_time: from_time..to_time,
        },
      }.merge(additional_filters)
    ).or(
      includes(:stop_times, :route).where(
        {
          stop_times: {
            departure_time: additional_departure_time_range,
          }
        }.merge(additional_filters)
      )
    ).joins(:schedule).merge(Scheduled::Schedule.today(date: current_time.to_date))
  end

  def self.soon_grouped(current_timestamp, route_id, time_range: 30.minutes)
    results = soon(current_timestamp, route_id, time_range: time_range)

    if route_id
      results.group_by(&:direction)
    else
      results.group_by(&:route_internal_id).map { |route_id, trips|
        [route_id, trips.group_by(&:direction)]
      }.to_h
    end
  end
end