class OnUpdateCascadeScheduleFKs < ActiveRecord::Migration[6.1]
  def change
    remove_foreign_key :calendar_exceptions, :schedules, column: :schedule_service_id
    remove_foreign_key :trips, :schedules, column: :schedule_service_id
    add_foreign_key :calendar_exceptions, :schedules, column: :schedule_service_id, primary_key: :service_id, on_update: :cascade, on_delete: :cascade
    add_foreign_key :trips, :schedules, column: :schedule_service_id, primary_key: :service_id, on_update: :cascade, on_delete: :cascade
  end
end
