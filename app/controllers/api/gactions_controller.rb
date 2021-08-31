class Api::GactionsController < Api::VirtualAssistantController
  def index
    case params["handler"]["name"]
    when "LookupTrainStatus"
      data = route_status_response
    when "LookupTrainTimes"
      data = stop_times_response
    when "LookupDelays"
      data = delays_response
    else
      data = fallback
    end
    render json: data
  end

  def route_status_response
    slot = params["intent"]["params"]["Train"] || params["intent"]["params"]["train"]

    unless slot
      return fallback(next_scene: "TrainStatusPrompt")
    end

    route_id = slot["resolved"]
    output, output_text = route_status_text(route_id)

    {
      session: {
        id: params["session"]["id"],
      },
      prompt: {
        override: false,
        firstSimple: {
          speech: "<speak>#{output}</speak>",
          text: output_text,
        }
      },
      scene: {
        name: "TrainStatus",
        slots: {},
        next: {
          name: "actions.scene.END_CONVERSATION"
        }
      }
    }
  end

  def stop_times_response
    slot = params["intent"]["params"]["Station"] || params["intent"]["params"]["station"]

    unless slot
      unless (stop_ids = [params["user"]["params"]["lastStationQueried"]])
        return fallback(next_scene: "TrainTimesPrompt")
      end
    else
      stop_ids = slot["resolved"].split(',')
    end

    output, output_text = stop_times_text(stop_ids)

    if stop_ids.size == 1
      {
        session: {
          id: params["session"]["id"],
        },
        prompt: {
          override: false,
          firstSimple: {
            speech: "<speak>#{output}</speak>",
            text: output_text,
          }
        },
        scene: {
          name: "TrainStatus",
          slots: {},
          next: {
            name: "actions.scene.END_CONVERSATION"
          }
        },
        user: {
          locale: params["user"]["locale"],
          params: {
            lastStationQueried: stop_ids.first,
          },
        }
      }
    else
      {
        session: {
          id: params["session"]["id"],
        },
        prompt: {
          override: false,
          firstSimple: {
            speech: "<speak>#{output}</speak>",
            text: output_text,
          }
        },
        scene: {
          name: "TrainStatus",
          slots: {
            Station: {
              mode: "REQUIRED",
              status: "INVALID",
              updated: true,
              value: 1
            }
          },
          next: {
            name: "AmbiguousTrainTimesPrompt"
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
        override: false,
        firstSimple: {
          speech: "<speak>#{output}</speak>",
        }
      },
      scene: {
        name: "TrainStatus",
        slots: {},
        next: {
          name: "actions.scene.END_CONVERSATION"
        }
      }
    }
  end

  def fallback(next_scene: "Welcome")
    {
      session: {
        id: params["session"]["id"],
      },
      scene: {
        name: "TrainStatus",
        slots: {},
        next: {
          name: next_scene,
        }
      }
    }
  end
end