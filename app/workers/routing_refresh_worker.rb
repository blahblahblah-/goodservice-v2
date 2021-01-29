class RoutingRefreshWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'critical'

  def perform
    ServiceChangeAnalyzer.refresh_routings(Time.current.to_i)
  end
end
