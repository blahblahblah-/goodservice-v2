# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2024_02_17_002930) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "bus_transfers", force: :cascade do |t|
    t.string "from_stop_internal_id", null: false
    t.string "bus_route", null: false
    t.integer "min_transfer_time", default: 0, null: false
    t.integer "access_time_from"
    t.integer "access_time_to"
    t.boolean "airport_connection", default: false, null: false
    t.index ["from_stop_internal_id", "bus_route"], name: "index_bus_transfers_on_from_stop_internal_id_and_bus_route", unique: true
    t.index ["from_stop_internal_id"], name: "index_bus_transfers_on_from_stop_internal_id"
  end

  create_table "calendar_exceptions", force: :cascade do |t|
    t.string "schedule_service_id", null: false
    t.date "date", null: false
    t.integer "exception_type", null: false
  end

  create_table "connections", force: :cascade do |t|
    t.string "from_stop_internal_id", null: false
    t.string "name", null: false
    t.string "mode"
    t.integer "min_transfer_time", default: 0, null: false
    t.integer "access_time_from"
    t.integer "access_time_to"
    t.index ["from_stop_internal_id", "name"], name: "index_connections_on_from_stop_internal_id_and_name", unique: true
    t.index ["from_stop_internal_id"], name: "index_connections_on_from_stop_internal_id"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at", precision: 6
    t.datetime "updated_at", precision: 6
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "routes", force: :cascade do |t|
    t.string "internal_id", null: false
    t.string "name", null: false
    t.string "alternate_name"
    t.string "color", null: false
    t.string "text_color"
    t.boolean "visible", default: true, null: false
    t.index ["internal_id"], name: "index_routes_on_internal_id", unique: true
  end

  create_table "schedules", force: :cascade do |t|
    t.string "service_id", null: false
    t.integer "monday", null: false
    t.integer "tuesday", null: false
    t.integer "wednesday", null: false
    t.integer "thursday", null: false
    t.integer "friday", null: false
    t.integer "saturday", null: false
    t.integer "sunday", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.index ["service_id"], name: "index_schedules_on_service_id", unique: true
  end

  create_table "stop_times", force: :cascade do |t|
    t.string "trip_internal_id", null: false
    t.integer "departure_time", null: false
    t.string "stop_internal_id", null: false
    t.integer "stop_sequence", null: false
    t.index ["departure_time"], name: "index_stop_times_on_departure_time"
    t.index ["stop_internal_id", "departure_time"], name: "index_stop_times_on_stop_internal_id_and_departure_time"
    t.index ["trip_internal_id", "departure_time"], name: "index_stop_times_on_trip_internal_id_and_departure_time"
  end

  create_table "stops", force: :cascade do |t|
    t.string "internal_id", null: false
    t.string "stop_name", null: false
    t.string "secondary_name"
    t.decimal "latitude"
    t.decimal "longitude"
    t.index ["internal_id"], name: "index_stops_on_internal_id", unique: true
  end

  create_table "transfers", force: :cascade do |t|
    t.string "from_stop_internal_id", null: false
    t.string "to_stop_internal_id", null: false
    t.integer "min_transfer_time", default: 0, null: false
    t.boolean "interchangeable_platforms", default: false, null: false
    t.integer "access_time_from"
    t.integer "access_time_to"
    t.index ["from_stop_internal_id"], name: "index_transfers_on_from_stop_internal_id"
  end

  create_table "trips", force: :cascade do |t|
    t.string "internal_id", null: false
    t.string "route_internal_id", null: false
    t.string "schedule_service_id", null: false
    t.string "destination", null: false
    t.integer "direction", null: false
    t.index ["internal_id"], name: "index_trips_on_internal_id", unique: true
    t.index ["route_internal_id"], name: "index_trips_on_route_internal_id"
    t.index ["schedule_service_id"], name: "index_trips_on_schedule_service_id"
  end

  add_foreign_key "bus_transfers", "stops", column: "from_stop_internal_id", primary_key: "internal_id"
  add_foreign_key "calendar_exceptions", "schedules", column: "schedule_service_id", primary_key: "service_id"
  add_foreign_key "connections", "stops", column: "from_stop_internal_id", primary_key: "internal_id"
  add_foreign_key "stop_times", "stops", column: "stop_internal_id", primary_key: "internal_id"
  add_foreign_key "stop_times", "trips", column: "trip_internal_id", primary_key: "internal_id"
  add_foreign_key "transfers", "stops", column: "from_stop_internal_id", primary_key: "internal_id"
  add_foreign_key "transfers", "stops", column: "to_stop_internal_id", primary_key: "internal_id"
  add_foreign_key "trips", "routes", column: "route_internal_id", primary_key: "internal_id"
  add_foreign_key "trips", "schedules", column: "schedule_service_id", primary_key: "service_id"
end
