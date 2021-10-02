class AddAccessTimeForTransfers < ActiveRecord::Migration[6.1]
  def change
    add_column :transfers, :access_time_from, :integer
    add_column :transfers, :access_time_to, :integer
  end
end
