class AddLatitudeAndLongitudeToStops < ActiveRecord::Migration[6.1]
  def change
    add_column :stops, :latitude, :decimal
    add_column :stops, :longitude, :decimal
  end
end
