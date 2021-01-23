class MigrateStopTimes < ActiveRecord::Migration[6.1]
  def change
    Scheduled::Stop.where("internal_id like ?", "%N").each do |stop|
      Scheduled::StopTime.where("stop_internal_id = ?", stop.internal_id).update_all(stop_internal_id: stop.internal_id[0..2])
    end
    Scheduled::Stop.where("internal_id like ?", "%S").each do |stop|
      Scheduled::StopTime.where("stop_internal_id = ?", stop.internal_id).update_all(stop_internal_id: stop.internal_id[0..2])
    end
  end
end
