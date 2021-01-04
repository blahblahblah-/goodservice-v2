module Scheduled
  class Transfer < ActiveRecord::Base
    belongs_to :from_stop, class_name: "Stop", foreign_key: "from_stop_internal_id", primary_key: "internal_id"
    belongs_to :to_stop, class_name: "Stop", foreign_key: "to_stop_internal_id", primary_key: "internal_id"
  end
end