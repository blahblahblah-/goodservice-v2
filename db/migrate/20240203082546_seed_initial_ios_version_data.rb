class SeedInitialIosVersionData < ActiveRecord::Migration[6.1]
  def change
    RedisStore.update_minimum_version("0.1")
    RedisStore.add_disabled_build_version(4)
  end
end
