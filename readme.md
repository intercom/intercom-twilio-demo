---
title: Integrating Intercom with Twilio
date: 2015-10-05 15:00 +0000
author: bob
tags:
---

Intercom's powerful [Conversations API](https://doc.intercom.io/api/#conversations) and [Webhooks](https://doc.intercom.io/api/#webhooks-and-notifications) makes it a breeze to build support and engagement workflows with other channels such as SMS.

# SMS in 2015

SMS (or "texts") have an extremely low barrier to entry, and yet are reported as one of the most [engaging channels for quick communication](http://thenextweb.com/future-of-communications/2015/02/09/sms-vs-push-vs-email/). Customers frequently ask us how our [Support](https://www.intercom.io/team-inbox) product can be used alongside a webservice like [Twilio](http://twilio.com/) to apply support over SMS.

# A simple workflow

Let's imagine a simple series of actions we want to neatly support:

* Customer sends in an SMS to our helpline number
* A user is automatically created in Intercom, and the phone number is stored
* A new conversation is created in Intercom
* Admin replies to that conversation get sent to the user over SMS

Using Twilio's webhooks, we can write a handler to accomplish the first 3 steps via the Intercom API:

```ruby
# Handle incoming SMS from Twilio, using a Sinatra handler:
post '/incoming_from_twilio' do
  from = params[:From]
  body = params[:Body]

  # Create or update the user, setting user_id = phone_number
  user = INTERCOM.users.create(user_id: from)

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
```

Now we'll suddenly start tracking these SMS users as Intercom users, and start logging their conversations in Intercom.

# Handling Admin Replies

Once one of our teammates responds to the SMS via Intercom, we need to channel that response back to the end-user via Twilio. We can subscribe to the `Reply from a Teammate` and `Conversation assigned to Teammate` topics using [Intercom's webhooks](http://docs.intercom.io/integrations/webhooks), and provide another handler that does the reverse process of turning Intercom replies into SMS messages:

```ruby
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
```

This constitutes a quick way to begin supporting your users over SMS. All of this code is available on [GitHub](https://github.com/intercom/intercom-twilio-demo). Please reach out if you have any questions or problems when integrating Intercom with your chosen support workflow.
