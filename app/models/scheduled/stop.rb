class Scheduled::Stop < ActiveRecord::Base
  has_many :stop_times, foreign_key: "stop_internal_id", primary_key: "internal_id"
end