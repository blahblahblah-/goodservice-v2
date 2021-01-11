class ServiceChanges::NotScheduledServiceChange < ServiceChanges::ServiceChange
  def applicable_to_routing?(routing)
    true
  end
end