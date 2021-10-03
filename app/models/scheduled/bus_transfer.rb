class Scheduled::BusTransfer < ActiveRecord::Base
  belongs_to :from_stop, class_name: "Stop", foreign_key: "from_stop_internal_id", primary_key: "internal_id"

  def is_sbs?
    bus_route.include?("SBS")
  end
end