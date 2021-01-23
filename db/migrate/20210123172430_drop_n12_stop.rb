class DropN12Stop < ActiveRecord::Migration[6.1]
  def change
    # N12 is an internal station for S.B. Coney Island
    Scheduled::Stop.find_by(internal_id: 'N12')&.destroy
    Scheduled::Stop.find_by(internal_id: 'N12N')&.destroy
    Scheduled::Stop.find_by(internal_id: 'N12S')&.destroy
  end
end
