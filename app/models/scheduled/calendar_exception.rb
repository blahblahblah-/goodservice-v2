module Scheduled
  class CalendarException < ActiveRecord::Base
    belongs_to :schedule, foreign_key: "schedule_service_id", primary_key: "service_id"

    def self.next_weekday
      date = Date.current
      while [0, 6].include?(date.wday) ||
        CalendarException.where(date: date).where("schedule_service_id like ?", "%Sunday%").or(CalendarException.where(date: date).where("schedule_service_id like ?", "%Saturday%")).present?
        date += 1
      end
      date
    end
  end
end