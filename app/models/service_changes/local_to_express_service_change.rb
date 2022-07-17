class ServiceChanges::LocalToExpressServiceChange < ServiceChanges::ServiceChange
  CLOSED_STOPS = ENV['CLOSED_STOPS']&.split(',')&.map {|s| s[0..2]} || []

  def not_long_term?
    !long_term?
  end

  def long_term?
    (intermediate_stations - CLOSED_STOPS).empty?
  end
end