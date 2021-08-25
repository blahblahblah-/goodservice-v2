class Api::AlexaController < Api::VirtualAssistantController
  def index
    verify_timestamp
    verify_header
    if params["alexa"]["request"]["type"] == "IntentRequest"
      case params["alexa"]["request"]["intent"]["name"]
      when "LookupTrainTimes"
        data = stop_times_response
      when "LookupDelays"
        data = delays_response
      when "LookupTrainStatus"
        data = route_status_response
      when "AMAZON.CancelIntent", "AMAZON.NavigateHomeIntent", "AMAZON.StopIntent"
        data = quit_response
      else
        data = help_response
      end
    else
      data = help_response
    end

    render json: data
  rescue => e
    p e.message
    p e.backtrace.join("\n")
    render nothing: true, status: :bad_request
  end

  private

  def verify_timestamp
    timestamp = DateTime.iso8601(params["alexa"]["request"]["timestamp"])
    day_diff = (timestamp - DateTime.current)
    seconds_diff = (day_diff * 24 * 60 * 60).to_i.abs
    if seconds_diff > TIMESTAMP_TOLERANCE_IN_SECONDS
      raise "Error invalid timestamp"
    end
  end

  def verify_header
    verify_url
    verify_cert
  end

  def verify_url
    uri = parsed_cert_uri

    if uri.scheme != "https"
      raise "URI protocol #{uri.scheme} is not https"
    end

    if uri.host.upcase != "s3.amazonaws.com".upcase
      raise "URI host #{uri.host} is not s3.amazonaws.com"
    end

    if uri.port != 443
      raise "URI port #{uri.port} is not 443"
    end

    if uri.path[0..9] != "/echo.api/"
      raise "URI path #{uri.path} does not start with /echo.api/"
    end
  end

  def verify_cert
    response = HTTParty.get(request.headers["SignatureCertChainUrl"])
    raise "Invalid cert response code" unless response.code == 200
    cert = OpenSSL::X509::Certificate.new(response.body)
    current_time = Time.current

    if cert.not_before > current_time || cert.not_after < current_time
      raise "Certificate is outdated for #{cert.not_before} to #{cert.not_after}"
    end

    if !cert.subject.to_a.flatten.include?("echo-api.amazon.com")
      raise "Invalid Subject Alternative Names #{cert.subject.to_a.flatten}"
    end

    signature = Base64.decode64(request.headers["Signature"])
    if !cert.public_key.verify(OpenSSL::Digest::SHA1.new, signature, request.body.read)
      raise "Signature does not match request hash"
    end
  end

  def parsed_cert_uri
    uri_str = request.headers["SignatureCertChainUrl"]
    URI.parse(uri_str)
  end

  def stop_times_response
    full_user_id = params["alexa"]["session"]["user"] && params["alexa"]["session"]["user"]["userId"]
    user_id = full_user_id && full_user_id.split(".").last

    if !params["alexa"]["request"]["intent"]["slots"]["station"]["resolutions"]
      if user_id
        stop_id = RedisStore.alexa_most_recent_stop(user_id)
        if stop_id
          text, _ = upcoming_arrival_times_response(stop_id, user_id: user_id)
          {
            version: "1.0",
            response: {
              outputSpeech: {
                type: "SSML",
                text: "<speak>#{text}</speak>",
              }
            }
          }
        else
          {
            version: "1.0",
            response: {
              outputSpeech: {
                type: "PlainText",
                text: "Please specify which station you would like to lookup upcoming train arrival times. For example, you can say: ask good service, when are the next trains arriving at bedford avenue?"
              }
            }
          }
        end
      else
        {
          version: "1.0",
          response: {
            outputSpeech: {
              type: "PlainText",
              text: "Please specify which station you would like to lookup upcoming train arrival times. For example, you can say: ask good service, when are the next trains arriving at bedford avenue?"
            }
          }
        }
      end
    else
      stop_resolution_code = params["alexa"]["request"]["intent"]["slots"]["station"]["resolutions"]["resolutionsPerAuthority"].first["status"]["code"]

      if stop_resolution_code == "ER_SUCCESS_NO_MATCH"
        value = params["alexa"]["request"]["intent"]["slots"]["station"]["value"]
        RedisStore.add_alexa_stop_query_miss(value)
        {
          version: "1.0",
          response: {
            outputSpeech: {
              type: "PlainText",
              text: "Sorry, there are no stations named #{value}. Please try again."
            }
          }
        }
      else
        stop_ids = params["alexa"]["request"]["intent"]["slots"]["station"]["resolutions"]["resolutionsPerAuthority"].first["values"].first["value"]["id"].split(",")
        text = stop_times_text(stop_ids, user_id: user_id)
        timestamp = Time.current.to_i
        {
          version: "1.0",
          response: {
            outputSpeech: {
              type: "SSML",
              ssml: "<speak>#{text}</speak>",
            }
          }
        }
      end
    end
  end

  def delays_response
    {
      version: "1.0",
      response: {
        outputSpeech: {
          type: "PlainText",
          text: delays_text
        }
      }
    }
  end

  def route_status_response
    if !params["alexa"]["request"]["intent"]["slots"]["train"]["resolutions"]
      output = "Please specify which train you would like to lookup the status for. For example, you can say: ask good service, what's the status of the A train?"
    else
      train_resolution_code = params["alexa"]["request"]["intent"]["slots"]["train"]["resolutions"]["resolutionsPerAuthority"].first["status"]["code"]

      if train_resolution_code == "ER_SUCCESS_NO_MATCH"
        value = params["alexa"]["request"]["intent"]["slots"]["train"]["value"]
        output = "Sorry, there are no trains named #{value}. Please try again."
      else
        route_id = params["alexa"]["request"]["intent"]["slots"]["train"]["resolutions"]["resolutionsPerAuthority"].first["values"].first["value"]["id"]
        output, _ = route_status_text(route_id)
      end
    end


    {
      version: "1.0",
      response: {
        outputSpeech: {
          type: "SSML",
          ssml: "<speak>#{output}</speak>"
        }
      }
    }
  end

  def quit_response
    {
      version: "1.0",
      response: {
        shouldEndSession: true,
      }
    }
  end

  def help_response
    {
      version: "1.0",
      response: {
        outputSpeech: {
          type: "PlainText",
          text: "You can use good service to check the status of a new york city subway train, or to look up upcoming departure times for a particular station. "\
            "For example, you can say: Ask good service, what is the status of the A train? Or, ask good service, when are the next trains arriving at Bedford Avenue? "\
            "Or, ask good service, what trains are delayed?"
        }
      }
    }
  end
end