class FixSirColor < ActiveRecord::Migration[7.1]
  def change
    route = Scheduled::Route.find_by!(internal_id: "SI")
    route.color = "0039a6"
    route.save!
  end
end
