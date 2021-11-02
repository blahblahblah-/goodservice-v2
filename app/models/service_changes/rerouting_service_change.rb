class ServiceChanges::ReroutingServiceChange < ServiceChanges::ServiceChange
  def applicable_to_routing?(routing)
    if begin_of_route?
      destinations.include?(routing.last)
    else
      routing.include?(first_station)
    end
  end
end