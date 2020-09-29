require 'rubygems'
require 'intercom'
require 'twilio-ruby'
require 'sinatra'
require 'nokogiri'


INTERCOM = Intercom::Client.new(token: ENV['INTERCOM_TOKEN'])

Twilio.configure do |config|
  config.account_sid = ENV['TWILIO_SID']
  config.auth_token = ENV['TWILIO_AUTH_TOKEN']
end

TWILIO = Twilio::REST::Client.new

#Tag ID that you want to associate to people that come in through a SMS so that you dont send sms's to every person in intercom
TAGID = ENV['INTERCOM_TAG'],


post '/incoming_from_twilio' do
  from = params[:From]
  body = params[:Body]


# Search for contacts by email
users = INTERCOM.contacts.search(
  "query": {
    "field": 'phone',
    "operator": '=',
    "value": from
  }
)
user= users.first
unless user
  # Create or update the user
  user = INTERCOM.contacts.create(phone: from, role: "lead")

end

 tag = INTERCOM.tags.find(id:TAGID)
 user.add_tag(id: TAGID)
  # Start a new conversation
conversations = INTERCOM.conversations.find_all(intercom_user_id: user.id, type:'user')
conversation = conversations.first
#If there is a past conversation then reply to it otherwise create a new conversation
if conversation
 INTERCOM.conversations.reply_to_last(intercom_user_id: user.id, type: 'user', message_type: 'comment', body: body)
  else
  INTERCOM.messages.create({
    from: {
      type: 'user',
      id: user.id
    },
    body: body
  })
end
  "ok"
end


post '/incoming_from_intercom' do
  request.body.rewind
  intercom_params = JSON.parse(request.body.read)

  # Extract the new message, and convert it to plaintext
  last_message_html = intercom_params['data']['item']['conversation_parts']['conversation_parts'][-1]['body']
  last_message = Nokogiri::HTML(last_message_html).text
	found = false
  # Load the user who we will SMS
  user = INTERCOM.contacts.find(id: intercom_params['data']['item']['user']['id'])
  unless user.phone.strip.empty?
  # See if the user containts the tag to specifify if you should send the text to them or not
	tags = user.tags.each {|t| if t.id == TAGID
	found = true 
	end}
	
	print tags
	if found == true
	  # Send the response to Twilio
	  unless last_message.strip.empty?
		TWILIO.messages.create(
		  from: ENV['TWILIO_NUMBER'],
		  to: user.phone,
		  body: last_message
		)
	  end
 
  end
  end
   "ok"
end
