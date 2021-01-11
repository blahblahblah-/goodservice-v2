class ServiceChanges::TruncatedServiceChange < ServiceChanges::ServiceChange
  def applicable_to_routing?(routing)
    if begin_of_route?
      routing.last == destination
    else
      routing.last == first_station
    end
  end
end