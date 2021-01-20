class Scheduled::Stop < ActiveRecord::Base
  belongs_to :parent_stop, class_name: "Stop", foreign_key: "parent_stop_id", primary_key: "internal_id", optional: true
  has_many :stop_times, foreign_key: "stop_internal_id", primary_key: "internal_id"
end