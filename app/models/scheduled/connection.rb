class Scheduled::Connection < ActiveRecord::Base
  belongs_to :from_stop, class_name: "Stop", foreign_key: "from_stop_internal_id", primary_key: "internal_id"
end