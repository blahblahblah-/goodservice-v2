class AddSecondaryNameToStops < ActiveRecord::Migration[6.1]
  def change
    add_column :stops, :secondary_name, :string
  end
end
