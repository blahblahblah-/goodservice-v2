require "uri"
require "net/http"

class OauthController < ApplicationController

  SLACK_OAUTH_URI = "https://slack.com/api/oauth.access"

  def index
    code = params[:code]

    post_params = {
      client_id: ENV["SLACK_CLIENT_ID"],
      client_secret: ENV["SLACK_CLIENT_SECRET"],
      code: code
    }
    data = Net::HTTP.post_form(URI.parse(SLACK_OAUTH_URI), post_params)

    redirect_to ENV["SLACK_REDIRECT_URI"], allow_other_host: true
  end

  def slack_install
    redirect_to ENV["SLACK_DIRECT_INSTALL_URI"], allow_other_host: true
  end
end
