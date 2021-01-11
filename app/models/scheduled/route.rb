class Scheduled::Route < ActiveRecord::Base
  default_scope { order(name: :asc) }
  scope :visible, -> { where(visible: true)}

  def scheduled?
    StopTime.soon(time_range: 5.minutes).joins(trip: :route).where(trip: {routes: {internal_id: internal_id}}).any?
  end
end