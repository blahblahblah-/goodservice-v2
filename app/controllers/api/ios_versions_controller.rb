class Api::IosVersionsController < ApplicationController
  def index
    data = {
      minimum_version: RedisStore.minimum_version,
      disabled_build_versions: RedisStore.disabled_build_versions.map(&:to_i)
    }

    render json: data
  end
end