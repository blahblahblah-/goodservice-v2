class LongTermServiceChangeRegularRouting
  attr_accessor :route_id, :direction, :first_departure, :last_run_times, :is_weekday, :is_saturday, :is_sunday

  def initialize(route_id, direction, first_departure, last_run_times, is_weekday = true, is_saturday = true, is_sunday = true)
    self.route_id = route_id
    self.direction = direction
    self.first_departure = convert_time_to_timestamp(first_departure)
    self.last_run_times = last_run_times.to_h { |k, v| [k, convert_time_to_timestamp(v)] }
    self.is_weekday = is_weekday
    self.is_saturday = is_saturday
    self.is_sunday = is_sunday
  end

  def self.all_times(route_id, direction, routing)
    LongTermServiceChangeRegularRouting.new(route_id, direction, nil, routing.to_h { |s| [s, nil] })
  end

  def is_all_times?
    first_departure.nil?
  end

  def is_effective_until_end_of_day?
    last_run_times.values.all? { |t| t.nil? }
  end

  def routing
    last_run_times.keys
  end

  def get_applicable_routing(timestamp, current_day_of_week, prev_day_of_week)
    todays_routing = get_day_routing(timestamp, current_day_of_week)

    return [todays_routing].compact if is_effective_until_end_of_day?

    [
      todays_routing,
      get_day_routing(timestamp + 1.day.to_i, prev_day_of_week)
    ].uniq.compact
  end

  private

  def convert_time_to_timestamp(time)
    return nil unless time
    array = time.split(':').map(&:to_i)
    array[0] * 3600 + array[1] * 60 + array[2]
  end

  def get_day_routing(timestamp, day_of_week)
    return nil unless is_day_valid?(day_of_week)
    return nil unless is_all_times? || timestamp + 30.minutes.to_i >= first_departure

    last_run_times.filter { |_, v| v.nil? || timestamp <= v }.map { |k, _| k }.presence
  end

  def is_day_valid?(day_of_week)
    return true if is_all_times?
    case day_of_week
    when "Saturday"
      return false unless is_saturday
    when "Sunday"
      return false unless is_sunday
    else
      return false unless is_weekday
    end

    true
  end
end