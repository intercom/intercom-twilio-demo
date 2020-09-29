require 'rubygems'
require 'intercom'
require 'twilio-ruby'
require 'sinatra'
require 'nokogiri'

INTERCOM = Intercom::Client.new(
  app_id: ENV['INTERCOM_APP_ID'],
  api_key: ENV['INTERCOM_API_KEY']
)

Twilio.configure do |config|
  config.account_sid = ENV['TWILIO_SID']
  config.auth_token = ENV['TWILIO_AUTH_TOKEN']
end

TWILIO = Twilio::REST::Client.new

post '/incoming_from_twilio' do
  from = params[:From]
  body = params[:Body]

  # Create or update the user
  user = INTERCOM.users.create(
    user_id: from
  )

  # Start a new conversation
  INTERCOM.messages.create(
    from: {
      type: 'user',
      id: user.id
    },
    body: body
  )

  "ok"
end

post '/incoming_from_intercom' do
  request.body.rewind
  intercom_params = JSON.parse(request.body.read)

  # Extract the new message, and convert it to plaintext
  last_message_html = intercom_params['data']['item']['conversation_parts']['conversation_parts'][-1]['body']
  last_message = Nokogiri::HTML(last_message_html).text

  # Load the user who we will SMS
  user = INTERCOM.users.find(id: intercom_params['data']['item']['user']['id'])

  # Send the response to Twilio
  unless last_message.strip.empty?
    TWILIO.messages.create(
      from: ENV['TWILIO_NUMBER'],
      to: user.user_id,
      body: last_message
    )
  end
  "ok"
end
