class Api::VirtualAssistantController < ApplicationController
  skip_before_action :verify_authenticity_token

  PRONOUNCIATION_MAPPING = {
    "houston" => "ˈhaʊstən",
    "nostrand" => "ˈnoʊstrənd",
    "dyckman" => "daɪkmɪn",
    "schermerhorn" => "ʃɜrmərhərn",
    "kosciuszko" => "ˌkɒʒiˈʊʃkoʊ",
    "tremont" => "tɹimɑnt",
    "dyre" => "ˈdaɪɚ",
    "via" => "ˈviːə",
    "evers" => "ˈɛvərz",
  }
  TIMESTAMP_TOLERANCE_IN_SECONDS = 150

  private

  def route_status_text(route_id)
    route = Scheduled::Route.find_by!(internal_id: route_id)
    route_name = route.alternate_name && Scheduled::Stop.normalized_partial_name(route.alternate_name) || "#{route_id} train"
    route_name = "Staten Island Railway" if route_name == "SI train"
    route_name.gsub!(/X/, ' Express')
    scheduled = Scheduled::Trip.soon(Time.current.to_i, route_id).present?
    route_data_encoded = RedisStore.route_status(route_id)
    route_data = route_data_encoded ? JSON.parse(route_data_encoded) : {}
    if !route_data['timestamp'] || route_data['timestamp'] <= (Time.current - 5.minutes).to_i
      route_data = {}
    end

    status = route_data['status'] || (scheduled ? 'No Service' : 'Not Scheduled')
    strs = ["The current status of the #{route_name} is #{status}."]

    if route_data.present?
      summaries = route_data['service_change_summaries'].flat_map { |_, summary| summary}.compact + route_data['service_summaries'].map { |_, summary| summary }.compact
      summaries.each do |summary|
        if route_name != "#{route_id} train"
          strs << summary.gsub("to/from", "to and from").gsub(/\//, ' ').gsub(/<#{route_id}>/, route_name).gsub(/<(.*?)>/, '\1').gsub(/\(\((.*?)\)\)/) do |stop_name|
            Scheduled::Stop.normalized_partial_name($1)
          end
        else
          strs << summary.gsub("to/from", "to and from").gsub(/\//, ' ').gsub(/<(.*?)>/, '\1').gsub(/\(\((.*?)\)\)/) do |stop_name|
            Scheduled::Stop.normalized_partial_name($1)
          end
        end
      end
    end

    output = strs.join(" ")
    PRONOUNCIATION_MAPPING.each do |k, v|
      output.gsub!(/\b#{k}\b/, "<phoneme alphabet=\"ipa\" ph=\"#{v}\">#{k}</phoneme>")
    end

    return output, (["#{route_name} status: #{status}."] + summaries).join("\n\n").gsub(/<|>/, '').gsub(/\(\(|\)\)/, '').gsub(/\s\-\s/, '–')
  end
end