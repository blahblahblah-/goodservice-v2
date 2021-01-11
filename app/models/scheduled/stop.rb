class Scheduled::Stop < ActiveRecord::Base
  belongs_to :parent_stop, class_name: "Stop", foreign_key: "parent_stop_id", primary_key: "internal_id", optional: true
  has_many :stop_times, foreign_key: "stop_internal_id", primary_key: "internal_id"

  def current_headways
    times = stop_times.soon.map(&:departure_time)
    times << Time.current - Time.current.beginning_of_day if times.size == 1
    times.sort.each_cons(2).map { |a,b| (b - a) / 60 }
  end

  def current_headways_for_route(route_internal_id)
    times = stop_times.soon.joins(trip: :route).where(trip: {routes: {internal_id: route_internal_id}}).map(&:departure_time)
    times << Time.current - Time.current.beginning_of_day if times.size == 1
    times.sort.each_cons(2).map { |a,b| (b - a) / 60 }
  end
end