class Scheduled::StopTime < ActiveRecord::Base
  belongs_to :trip, foreign_key: "trip_internal_id", primary_key: "internal_id"
  belongs_to :stop, foreign_key: "stop_internal_id", primary_key: "internal_id"

  DAY_IN_MINUTES = 86400
  BUFFER = 10800

  def self.rounded_time
    Time.current.change(sec: 0)
  end

  def self.not_past(current_time: rounded_time)
    if (current_time + BUFFER).to_date == current_time.to_date.tomorrow
      where("departure_time > ? or (? - departure_time > ?)",
        current_time - current_time.beginning_of_day,
        current_time - current_time.beginning_of_day,
        BUFFER,
      )
    elsif current_time.hour < 4
      where("(departure_time < ? and departure_time > ?) or (departure_time >= ? and departure_time - ? > ?)",
        DAY_IN_MINUTES - BUFFER,
        current_time - current_time.beginning_of_day,
        DAY_IN_MINUTES,
        DAY_IN_MINUTES,
        current_time - current_time.beginning_of_day
      )
    else
      where("departure_time > ?", current_time - current_time.beginning_of_day)
    end
  end
end