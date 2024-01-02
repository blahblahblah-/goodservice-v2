class UpdateFsAlternateName < ActiveRecord::Migration[6.1]
  def change
    route = Scheduled::Route.find_by!(internal_id: 'FS')
    route.alternate_name = 'Franklin Av Shuttle'
    route.save!
  end
end
