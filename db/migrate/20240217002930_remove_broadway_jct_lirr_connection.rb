class RemoveBroadwayJctLirrConnection < ActiveRecord::Migration[6.1]
  def change
    Scheduled::Connection.find_by(from_stop_internal_id: "A51", name: "LIRR")&.destroy
  end
end
