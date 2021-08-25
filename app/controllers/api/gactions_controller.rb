class Api::GactionsController < Api::VirtualAssistantController
  def index
    case params["handler"]["name"]
    when "LookupTrainStatus"
      data = route_status_response
    when "LookupTrainTimes"
      data = stop_times_response
    when "LookupDelays"
      data = delays_response
    when "actions.intent.HEALTH_CHECK"
      data = {}
    end
    render json: data
  end

  def route_status_response
    slot = params["intent"]["params"]["Train"] || params["intent"]["params"]["train"]

    if !slot
      return {
        session: {
          id: params["session"]["id"],
        },
        scene: {
          "name": "TrainStatus",
          "slots": {},
          "next": {
            "name": "Welcome"
          }
        }
      }
    end

    route_id = slot["resolved"]
    output, output_text = route_status_text(route_id)

    {
      session: {
        id: params["session"]["id"],
      },
      prompt: {
        "override": false,
        "firstSimple": {
          "speech": "<speak>#{output}</speak>",
          "text": output_text,
        }
      },
      scene: {
        "name": "TrainStatus",
        "slots": {},
        "next": {
          "name": "actions.scene.END_CONVERSATION"
        }
      }
    }
  end

  def stop_times_response
    slot = params["intent"]["params"]["Station"] || params["intent"]["params"]["station"]
    stop_ids = slot["resolved"].split(',')
    output, output_text = stop_times_text(stop_ids)

    if stop_ids.size == 1
      {
        session: {
          id: params["session"]["id"],
        },
        prompt: {
          "override": false,
          "firstSimple": {
            "speech": "<speak>#{output}</speak>",
            "text": output_text,
          }
        },
        scene: {
          "name": "TrainStatus",
          "slots": {},
          "next": {
            "name": "actions.scene.END_CONVERSATION"
          }
        }
      }
    else
      {
        session: {
          id: params["session"]["id"],
        },
        prompt: {
          "override": false,
          "firstSimple": {
            "speech": "<speak>#{output}</speak>",
            "text": output_text,
          }
        },
        scene: {
          "name": "TrainStatus",
          "slots": {
            "Station": {
              "mode": "REQUIRED",
              "status": "INVALID",
              "updated": true,
              "value": 1
            }
          },
          "next": {
            "name": "AmbiguousTrainTimesPrompt"
          }
        }
      }
    end
  end

  def delays_response
    output = delays_text

    {
      session: {
        id: params["session"]["id"],
      },
      prompt: {
        "override": false,
        "firstSimple": {
          "speech": "<speak>#{output}</speak>",
        }
      },
      scene: {
        "name": "TrainStatus",
        "slots": {},
        "next": {
          "name": "actions.scene.END_CONVERSATION"
        }
      }
    }
  end
end