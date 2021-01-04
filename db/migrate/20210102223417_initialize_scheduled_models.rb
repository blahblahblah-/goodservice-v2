class InitializeScheduledModels < ActiveRecord::Migration[6.1]
  def change
    create_table :routes do |t|
      t.string :internal_id, null: false
      t.string :name, null: false
      t.string :alternate_name
      t.string :color, null: false
      t.string :text_color
      t.boolean :visible, null: false, default: true
    end

    add_index :routes, :internal_id, unique: true

    create_table :schedules do |t|
      t.string :service_id, null: false
      t.integer :monday, null: false
      t.integer :tuesday, null: false
      t.integer :wednesday, null: false
      t.integer :thursday, null: false
      t.integer :friday, null: false
      t.integer :saturday, null: false
      t.integer :sunday, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
    end

    add_index :schedules, :service_id, unique: true

    create_table :calendar_exceptions do |t|
      t.string :schedule_service_id, null: false
      t.date :date, null: false
      t.integer :exception_type, null: false
    end

    add_foreign_key :calendar_exceptions, :schedules, column: :schedule_service_id, primary_key: :service_id

    create_table :stops do |t|
      t.string :internal_id, null: false
      t.string :stop_name, null: false
      t.string :parent_stop_id
    end

    add_index :stops, :internal_id, unique: true

    create_table :trips do |t|
      t.string :internal_id, null: false
      t.string :route_internal_id, null: false
      t.string :schedule_service_id, null: false
      t.string :destination, null: false
      t.integer :direction, null: false
    end

    add_foreign_key :trips, :routes, column: :route_internal_id, primary_key: :internal_id
    add_foreign_key :trips, :schedules, column: :schedule_service_id, primary_key: :service_id
    add_index :trips, :internal_id, unique: true

    create_table :stop_times do |t|
      t.string :trip_internal_id, null: false
      t.integer :departure_time, null: false
      t.string :stop_internal_id, null: false
      t.integer :stop_sequence, null: false
    end

    add_foreign_key :stop_times, :trips, column: :trip_internal_id, primary_key: :internal_id
    add_foreign_key :stop_times, :stops, column: :stop_internal_id, primary_key: :internal_id
    add_index :stop_times, [:stop_internal_id, :departure_time]
    add_index :stop_times, [:trip_internal_id, :departure_time]

    create_table :transfers do |t|
      t.string :from_stop_internal_id, null: false
      t.string :to_stop_internal_id, null: false
      t.integer :min_transfer_time, null: false, default: 0
      t.boolean :interchangeable_platforms, null: false, default: false
    end

    add_foreign_key :transfers, :stops, column: :from_stop_internal_id, primary_key: :internal_id
    add_foreign_key :transfers, :stops, column: :to_stop_internal_id, primary_key: :internal_id
    add_index :transfers, :from_stop_internal_id
  end
end
