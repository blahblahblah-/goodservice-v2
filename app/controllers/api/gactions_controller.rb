class Api::GactionsController < Api::VirtualAssistantController
  def index
    case params["handler"]["name"]
    when "LookupTrainStatus"
      data = route_status_response
    end
    render json: data
  end

  def route_status_response
    slot = params["intent"]["params"]["Train"] || params["intent"]["params"]["train"]
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
      "scene": {
        "name": "TrainStatus",
        "slots": {},
        "next": {
          "name": "actions.scene.END_CONVERSATION"
        }
      }
    }
  end
end