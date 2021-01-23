class RemoveH19Station < ActiveRecord::Migration[6.1]
  def change
    # H19 is an internal station for Broad Channel
    Scheduled::Stop.find_by(internal_id: 'H19')&.destroy
    Scheduled::Stop.find_by(internal_id: 'H19N')&.destroy
    Scheduled::Stop.find_by(internal_id: 'H19S')&.destroy
  end
end
