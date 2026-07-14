namespace :helpdesk do
  desc "Seed fake email tickets for testing. Usage: rails helpdesk:seed[AccountName]"
  task :seed, [:account_name] => :environment do |_t, args|
    account = if args[:account_name].present?
                Account.find_by!(name: args[:account_name])
              else
                Account.order(:id).last!
              end
    env = Environment.where(account: account).first!
    user = User.where(account: account).first!
    puts "Account: #{account.name} (id: #{account.id})"

    # Ensure operator profile exists
    profile = user.operator_profile || OperatorProfile.create!(
      user: user, account: account,
      public_name: user.name, availability: :online,
      auto_assign: true, max_concurrent_chats: 10, sort_order: 0
    )

    # Create a mailbox
    mailbox = Mailbox.find_or_create_by!(account: account, email_address: "support@tuli.com") do |m|
      m.environment = env
      m.name = "Support"
      m.provider = :imap
      m.ticket_prefix = "SUP"
      m.config = { "host" => "imap.gmail.com", "port" => 993, "username" => "support@tuli.com", "password" => "test", "ssl" => true, "folder" => "INBOX" }
      m.auto_assign = true
      m.auto_reply_enabled = true
    end

    puts "Mailbox: #{mailbox.name} (#{mailbox.email_address})"

    tag_names = %w[billing bug feature-request urgent onboarding]
    tags = tag_names.map do |name|
      ConversationTag.find_or_create_by!(account: account, name: name)
    end

    tickets = [
      {
        from: "sarah.johnson@acmecorp.com", name: "Sarah Johnson",
        subject: "Cannot access billing portal after upgrade",
        messages: [
          { from: :customer, content: "Hi,\n\nI recently upgraded my plan to Pro but I still can't access the billing portal. It keeps showing a 403 error when I click on 'Manage Subscription'. I've tried clearing my cache and using a different browser but the issue persists.\n\nCould you please look into this?\n\nThanks,\nSarah", html: "<p>Hi,</p><p>I recently upgraded my plan to Pro but I still can't access the billing portal. It keeps showing a <strong>403 error</strong> when I click on 'Manage Subscription'. I've tried clearing my cache and using a different browser but the issue persists.</p><p>Could you please look into this?</p><p>Thanks,<br>Sarah</p>" },
          { from: :operator, content: "Hi Sarah,\n\nThanks for reaching out. I can see your account was upgraded but the billing permissions haven't propagated yet. I've manually refreshed them on our end.\n\nCould you try logging out and back in? That should fix it.\n\nBest,\nWaseem" },
          { from: :customer, content: "That worked perfectly, thank you so much! Quick turnaround too." },
        ],
        status: :resolved, priority: :normal, tags: ["billing"],
        cc: ["accounting@acmecorp.com"],
        assigned: true, age_hours: 48
      },
      {
        from: "mike.chen@startupxyz.io", name: "Mike Chen",
        subject: "API rate limiting hitting us in production",
        messages: [
          { from: :customer, content: "Hey team,\n\nWe're seeing 429 errors from the Messy API during our peak hours (2-4pm UTC). We're on the Pro plan and the docs say we should have 1000 req/min but we're getting throttled at around 500.\n\nThis is blocking our transactional emails. Can you check if there's a misconfiguration on our account?\n\nMike Chen\nCTO, StartupXYZ", html: "<p>Hey team,</p><p>We're seeing <code>429</code> errors from the Messy API during our peak hours (2-4pm UTC). We're on the Pro plan and the docs say we should have 1000 req/min but we're getting throttled at around 500.</p><p>This is blocking our transactional emails. Can you check if there's a misconfiguration on our account?</p><p>Mike Chen<br>CTO, StartupXYZ</p>" },
        ],
        status: :open, priority: :urgent, tags: ["bug", "urgent"],
        cc: ["devops@startupxyz.io", "mike.chen@startupxyz.io"],
        assigned: true, age_hours: 3
      },
      {
        from: "lisa.park@designstudio.co", name: "Lisa Park",
        subject: "Feature request: Custom email templates with drag-and-drop",
        messages: [
          { from: :customer, content: "Hello!\n\nI love using Messy for our client communications. One thing that would make it even better is a visual drag-and-drop email template builder. Right now we have to write HTML manually which is a bit tedious for our design team.\n\nIs this something you're considering for the roadmap?\n\nBest,\nLisa", html: "<p>Hello!</p><p>I love using Messy for our client communications. One thing that would make it even better is a visual drag-and-drop email template builder. Right now we have to write HTML manually which is a bit tedious for our design team.</p><p>Is this something you're considering for the roadmap?</p><p>Best,<br>Lisa</p>" },
          { from: :operator, content: "Hi Lisa,\n\nThanks for the suggestion! A visual template builder is definitely on our roadmap. We're planning to start working on it in Q3.\n\nI've added your request to our feature tracker so you'll be notified when it ships.\n\nCheers,\nWaseem" },
        ],
        status: :pending, priority: :normal, tags: ["feature-request"],
        cc: [],
        assigned: true, age_hours: 72
      },
      {
        from: "james.wilson@enterprise.com", name: "James Wilson",
        subject: "Onboarding: Need help setting up SSO with Okta",
        messages: [
          { from: :customer, content: "Hi support,\n\nWe just signed up for the Enterprise plan and need to set up SSO with our Okta instance. The docs mention SAML support but I'm not seeing the configuration page in the admin panel.\n\nOur security team needs this configured before we can roll out to the rest of the company. Can someone walk us through the process?\n\nRegards,\nJames Wilson\nIT Director, Enterprise Corp", html: "<p>Hi support,</p><p>We just signed up for the Enterprise plan and need to set up SSO with our Okta instance. The docs mention SAML support but I'm not seeing the configuration page in the admin panel.</p><p>Our security team needs this configured before we can roll out to the rest of the company. Can someone walk us through the process?</p><p>Regards,<br>James Wilson<br>IT Director, Enterprise Corp</p>" },
          { from: :customer, content: "Following up on this - our rollout deadline is next Friday. Any update?" },
        ],
        status: :open, priority: :high, tags: ["onboarding", "urgent"],
        cc: ["security@enterprise.com", "it-admin@enterprise.com"],
        assigned: true, age_hours: 24
      },
      {
        from: "anna.meyer@shopfront.de", name: "Anna Meyer",
        subject: "Order confirmation emails failing since yesterday",
        messages: [
          { from: :customer, content: "Hallo,\n\nSince yesterday around 18:00 CET our order confirmation emails are not going out — they all show as failed in the message log.\n\nOur checkout flow depends on these confirmations so this is quite urgent for us.\n\nDanke,\nAnna", html: "<p>Hallo,</p><p>Since yesterday around 18:00 CET our order confirmation emails are not going out — they all show as failed in the message log.</p><p>Our checkout flow depends on these confirmations so this is quite urgent for us.</p><p>Danke,<br>Anna</p>" },
          { from: :operator, content: "Hi Anna,\n\nI've checked the message log and it looks like your SES sending region started hitting a temporary rate limit yesterday at 17:58 CET. Our system retried 3 times and then marked those sends as failed.\n\nThe limit has cleared now. I've retried the failed messages and they've gone out. You should see the confirmations arriving within the next few minutes.\n\nLet me know if they come through." },
          { from: :customer, content: "Confirmed, the confirmations are flowing again. Thank you for the quick fix and the retry!" },
        ],
        status: :resolved, priority: :urgent, tags: ["bug"],
        cc: ["dev@shopfront.de"],
        assigned: true, age_hours: 18
      },
      {
        from: "david.brown@freelancer.com", name: "David Brown",
        subject: "How to set up email tracking pixels?",
        messages: [
          { from: :customer, content: "Hi there,\n\nI'm trying to track email opens for my campaigns but I can't figure out how to enable tracking pixels. Is this a feature that's available on the free plan?\n\nThanks,\nDavid", html: "<p>Hi there,</p><p>I'm trying to track email opens for my campaigns but I can't figure out how to enable tracking pixels. Is this a feature that's available on the free plan?</p><p>Thanks,<br>David</p>" },
        ],
        status: :open, priority: :normal, tags: [],
        cc: [],
        assigned: false, age_hours: 6
      },
      {
        from: "priya.sharma@fintech.in", name: "Priya Sharma",
        subject: "Compliance: Need data processing agreement signed",
        messages: [
          { from: :customer, content: "Dear Messy team,\n\nAs part of our compliance requirements under Indian data protection laws, we need a signed Data Processing Agreement (DPA) before we can proceed with our integration.\n\nCould you please send us your standard DPA or let us know the process for getting one in place?\n\nRegards,\nPriya Sharma\nCompliance Officer\nFinTech Solutions Pvt Ltd", html: "<p>Dear Messy team,</p><p>As part of our compliance requirements under Indian data protection laws, we need a signed Data Processing Agreement (DPA) before we can proceed with our integration.</p><p>Could you please send us your standard DPA or let us know the process for getting one in place?</p><p>Regards,<br>Priya Sharma<br>Compliance Officer<br>FinTech Solutions Pvt Ltd</p>" },
        ],
        status: :pending, priority: :high, tags: [],
        cc: ["legal@fintech.in"],
        assigned: false, age_hours: 96
      },
      {
        from: "tom.garcia@retailco.com", name: "Tom Garcia",
        subject: "SMS delivery issues to Canadian numbers",
        messages: [
          { from: :customer, content: "Hi,\n\nWe've been having trouble delivering SMS messages to Canadian phone numbers (+1 area codes 204, 226, 236, etc). US numbers work fine.\n\nWe're using Twilio through Messy. Is there a known issue or do we need to register a separate sender ID for Canada?\n\nTom", html: "<p>Hi,</p><p>We've been having trouble delivering SMS messages to Canadian phone numbers (+1 area codes 204, 226, 236, etc). US numbers work fine.</p><p>We're using Twilio through Messy. Is there a known issue or do we need to register a separate sender ID for Canada?</p><p>Tom</p>" },
          { from: :operator, content: "Hi Tom,\n\nCanadian carriers recently started requiring 10DLC registration for A2P messaging. You'll need to register your brand and campaign through Twilio's console.\n\nHere's the process:\n1. Go to Twilio Console > Messaging > Compliance\n2. Register your brand\n3. Create a campaign for your use case\n4. Wait for approval (usually 1-3 business days)\n\nOnce approved, your Canadian deliveries should start working again. Let me know if you need help with the registration." },
        ],
        status: :pending, priority: :normal, tags: [],
        cc: [],
        assigned: true, age_hours: 36
      },
    ]

    tickets.each_with_index do |ticket_data, i|
      customer = Customer.find_or_create_by!(account: account, email: ticket_data[:from]) do |c|
        parts = ticket_data[:name].split(" ", 2)
        c.first_name = parts[0]
        c.last_name = parts[1]
      end

      created_at = ticket_data[:age_hours].hours.ago

      conversation = Conversation.create!(
        account: account,
        environment: env,
        customer: customer,
        visitor_token: "email_seed_#{SecureRandom.hex(8)}",
        visitor_name: ticket_data[:name],
        visitor_email: ticket_data[:from],
        status: ticket_data[:status],
        priority: ticket_data[:priority],
        source: :email,
        subject: ticket_data[:subject],
        ticket_number: mailbox.next_ticket_number!,
        assigned_user_id: ticket_data[:assigned] ? user.id : nil,
        created_at: created_at,
        updated_at: created_at
      )

      if ticket_data[:assigned]
        ConversationAssignment.create!(
          conversation: conversation,
          assigned_to_id: user.id,
          created_at: created_at
        )
      end

      email_thread = EmailThread.create!(
        account: account,
        mailbox: mailbox,
        conversation: conversation,
        ticket_number: conversation.ticket_number,
        from_email: ticket_data[:from],
        from_name: ticket_data[:name],
        subject: ticket_data[:subject],
        cc_list: ticket_data[:cc] || [],
        created_at: created_at
      )

      # Add tags
      ticket_data[:tags].each do |tag_name|
        tag = tags.find { |t| t.name == tag_name }
        conversation.conversation_tags << tag if tag
      end

      # Create messages
      msg_time = created_at
      last_message = nil
      ticket_data[:messages].each_with_index do |msg, j|
        msg_time += (15 + rand(120)).minutes

        is_operator = msg[:from] == :operator
        cm = ConversationMessage.create!(
          conversation: conversation,
          account: account,
          sender_type: is_operator ? "User" : "Customer",
          sender_id: is_operator ? user.id : customer.id,
          message_type: :text,
          content: msg[:content],
          private: false,
          metadata: is_operator ? {} : { "email" => true },
          created_at: msg_time,
          updated_at: msg_time
        )

        # Create email detail for customer messages
        unless is_operator
          message_id = "<#{SecureRandom.hex(16)}@#{ticket_data[:from].split('@').last}>"
          EmailMessageDetail.create!(
            conversation_message: cm,
            message_id_header: message_id,
            from_email: ticket_data[:from],
            from_name: ticket_data[:name],
            to_email: mailbox.email_address,
            cc_list: ticket_data[:cc] || [],
            html_body: msg[:html] || msg[:content],
            text_body: msg[:content],
            provider_uid: "seed_#{SecureRandom.hex(8)}"
          )
        end

        last_message = cm
      end

      # Update conversation timestamps
      if last_message
        conversation.update_columns(
          last_message_at: last_message.created_at,
          last_message_preview: last_message.content.truncate(100),
          resolved_at: conversation.resolved? ? last_message.created_at : nil,
          first_response_at: ticket_data[:messages].any? { |m| m[:from] == :operator } ?
            (created_at + (15 + rand(120)).minutes) : nil
        )
      end

      status_icon = case conversation.status
                    when "open" then "O"
                    when "pending" then "~"
                    when "resolved" then "R"
                    when "closed" then "X"
                    end

      puts "  [#{status_icon}] #{conversation.ticket_number} — #{ticket_data[:subject]} (#{ticket_data[:messages].size} msgs, #{ticket_data[:assigned] ? 'assigned' : 'unassigned'})"
    end

    puts "\nSeeded #{tickets.size} email tickets in mailbox '#{mailbox.name}'"
    puts "Ticket numbers: #{mailbox.next_ticket_number - tickets.size} to #{mailbox.next_ticket_number - 1}"
  end
end
