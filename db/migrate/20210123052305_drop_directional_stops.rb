class DropDirectionalStops < ActiveRecord::Migration[6.1]
  def change
    Scheduled::Stop.where("internal_id like ?", "%N").destroy_all
    Scheduled::Stop.where("internal_id like ?", "%S").destroy_all
  end
end
