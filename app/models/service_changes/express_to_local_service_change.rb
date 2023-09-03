class ServiceChanges::ExpressToLocalServiceChange < ServiceChanges::ServiceChange
  def convert_to_rerouting
    ServiceChanges::ReroutingServiceChange.new(
      self.direction, self.stations_affected, self.origin, self.routing, self.long_term_override
    )
  end
end