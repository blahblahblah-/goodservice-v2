module Scheduled
  class Trip < ActiveRecord::Base
    belongs_to :route, foreign_key: "route_internal_id", primary_key: "internal_id"
    belongs_to :schedule, foreign_key: "schedule_service_id", primary_key: "service_id"
    has_many :stop_times, foreign_key: "trip_internal_id", primary_key: "internal_id"

    DAY_IN_MINUTES = 86400

    def self.soon(current_timestamp, route_id, time_range: 30.minutes)
      current_time = Time.at(current_timestamp)
      if (current_time + time_range).to_date == current_time.to_date.tomorrow
        from_time = current_time - current_time.beginning_of_day
        to_time = current_time - current_time.beginning_of_day + time_range.to_i
        next_day_to_time = (current_time - current_time.beginning_of_day + time_range.to_i) % DAY_IN_MINUTES

        includes(:stop_times).where(
          route_internal_id: route_id,
          stop_times: {
            departure_time: from_time..to_time
          }
        ).or(
          includes(:stop_times).where(
            route_internal_id: route_id,
            stop_times: {
              departure_time: 0..next_day_to_time
            }
          )
        ).joins(:schedule).merge(Scheduled::Schedule.today(date: current_time.to_date)).group_by(&:direction)
      elsif current_time.hour < 4
        from_time = current_time - current_time.beginning_of_day
        to_time = current_time - current_time.beginning_of_day + time_range.to_i
        twenty_four_hr = current_time - current_time.beginning_of_day + DAY_IN_MINUTES
        time_after_twenty_four_hr = current_time - current_time.beginning_of_day + DAY_IN_MINUTES + time_range.to_i

        includes(:stop_times).where(
          route_internal_id: route_id,
          stop_times: {
            departure_time: from_time..to_time
          }
        ).or(
          includes(:stop_times).where(
            route_internal_id: route_id,
            stop_times: {
              departure_time: twenty_four_hr..time_after_twenty_four_hr
            }
          )
        ).joins(:schedule).merge(Scheduled::Schedule.today(date: current_time.to_date)).group_by(&:direction)
      else
        from_time = current_time - current_time.beginning_of_day
        to_time = current_time - current_time.beginning_of_day + time_range.to_i

        includes(:stop_times).where(
          route_internal_id: route_id,
          stop_times: {
            departure_time: from_time..to_time
          }
        ).joins(:schedule).merge(Scheduled::Schedule.today(date: current_time.to_date)).group_by(&:direction)
      end
    end
  end
end