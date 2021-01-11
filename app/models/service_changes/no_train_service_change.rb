class ServiceChanges::NoTrainServiceChange < ServiceChanges::ServiceChange
  def applicable_to_routing?(routing)
    true
  end
end