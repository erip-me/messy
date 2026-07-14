# frozen_string_literal: true

# Seeds RICH, FAKE, screenshot-ready demo data for the "Messy" platform.
#
#   bin/rails demo:seed
#
# Re-runnable: it truncates every application table first, then rebuilds
# everything. Brand = fictional "Lumen Labs". Contains ZERO real credentials
# and ZERO real data — every secret here is an obvious demo placeholder.
namespace :demo do
  desc "Wipe local dev DB and seed rich, fake, screenshot-ready demo data"
  task seed: :environment do
    unless Rails.env.development?
      abort "Refusing to run demo:seed outside development (RAILS_ENV=#{Rails.env}). Aborting."
    end

    srand(20260630) # deterministic-ish output across runs

    # ──────────────────────────────────────────────────────────────────────
    # HTML email template bodies (copied from db/seeds.rb)
    # ──────────────────────────────────────────────────────────────────────
    magic_link_body = <<~'HTML'
      <!DOCTYPE html>
      <html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
      <body style="margin:0;padding:0;background:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
        <table width="100%" cellpadding="0" cellspacing="0" style="padding:48px 16px">
          <tr><td align="center">
            <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08)">
              <tr><td style="background:#0f0f1a;padding:32px 40px;text-align:center">
                <span style="color:#ffffff;font-size:22px;font-weight:700;letter-spacing:.5px">{{company}}</span>
              </td></tr>
              <tr><td style="padding:40px">
                <h1 style="margin:0 0 8px;font-size:24px;color:#0f0f1a">Sign in to your account</h1>
                <p style="margin:0 0 32px;color:#6b7280;font-size:15px;line-height:1.6">Hi {{name}}, click the button below to sign in. This link expires in 15 minutes.</p>
                <table cellpadding="0" cellspacing="0"><tr><td style="background:#0f0f1a;border-radius:8px">
                  <a href="{{magic_link}}" style="display:inline-block;padding:14px 32px;color:#ffffff;font-size:15px;font-weight:600;text-decoration:none">Sign in →</a>
                </td></tr></table>
                <p style="margin:32px 0 0;color:#9ca3af;font-size:13px">If you didn't request this, you can safely ignore this email.</p>
              </td></tr>
              <tr><td style="padding:24px 40px;border-top:1px solid #f3f4f6;text-align:center">
                <p style="margin:0;color:#9ca3af;font-size:12px">© {{year}} {{company}}. All rights reserved.</p>
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body></html>
    HTML

    welcome_body = <<~'HTML'
      <!DOCTYPE html>
      <html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
      <body style="margin:0;padding:0;background:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
        <table width="100%" cellpadding="0" cellspacing="0" style="padding:48px 16px">
          <tr><td align="center">
            <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08)">
              <tr><td style="background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);padding:40px;text-align:center">
                <p style="margin:0 0 12px;font-size:40px">🎉</p>
                <h1 style="margin:0;color:#ffffff;font-size:26px;font-weight:700">Welcome aboard, {{name}}!</h1>
              </td></tr>
              <tr><td style="padding:40px">
                <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.7">We're thrilled to have you join <strong>{{company}}</strong>. Your account is ready and you can start exploring right away.</p>
                <table cellpadding="0" cellspacing="0" style="width:100%;margin:24px 0">
                  <tr><td style="padding:16px;background:#f9fafb;border-radius:8px;border-left:4px solid #667eea">
                    <p style="margin:0 0 4px;font-size:13px;color:#6b7280;font-weight:600;text-transform:uppercase;letter-spacing:.5px">Your account</p>
                    <p style="margin:0;font-size:15px;color:#0f0f1a;font-weight:500">{{email}}</p>
                  </td></tr>
                </table>
                <table cellpadding="0" cellspacing="0"><tr><td style="background:#667eea;border-radius:8px">
                  <a href="{{dashboard_url}}" style="display:inline-block;padding:14px 32px;color:#ffffff;font-size:15px;font-weight:600;text-decoration:none">Go to dashboard →</a>
                </td></tr></table>
              </td></tr>
              <tr><td style="padding:24px 40px;border-top:1px solid #f3f4f6;text-align:center">
                <p style="margin:0;color:#9ca3af;font-size:12px">© {{year}} {{company}}. All rights reserved.</p>
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body></html>
    HTML

    order_body = <<~'HTML'
      <!DOCTYPE html>
      <html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
      <body style="margin:0;padding:0;background:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
        <table width="100%" cellpadding="0" cellspacing="0" style="padding:48px 16px">
          <tr><td align="center">
            <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08)">
              <tr><td style="background:#0f0f1a;padding:32px 40px;text-align:center">
                <span style="color:#ffffff;font-size:22px;font-weight:700">{{company}}</span>
              </td></tr>
              <tr><td style="padding:40px">
                <p style="margin:0 0 4px;color:#10b981;font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:1px">✓ Confirmed</p>
                <h1 style="margin:0 0 8px;font-size:24px;color:#0f0f1a">Order {{order_number}}</h1>
                <p style="margin:0 0 32px;color:#6b7280;font-size:15px">Hi {{name}}, your order has been confirmed and is being processed.</p>
                <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #e5e7eb;border-radius:8px;overflow:hidden;margin-bottom:24px">
                  <tr style="background:#f9fafb">
                    <td style="padding:12px 16px;font-size:12px;color:#6b7280;font-weight:600;text-transform:uppercase;letter-spacing:.5px">Item</td>
                    <td style="padding:12px 16px;font-size:12px;color:#6b7280;font-weight:600;text-transform:uppercase;letter-spacing:.5px;text-align:right">Amount</td>
                  </tr>
                  <tr>
                    <td style="padding:16px;border-top:1px solid #e5e7eb;color:#374151;font-size:14px">{{item_name}}</td>
                    <td style="padding:16px;border-top:1px solid #e5e7eb;color:#374151;font-size:14px;text-align:right;font-weight:600">{{item_price}}</td>
                  </tr>
                  <tr style="background:#f9fafb">
                    <td style="padding:12px 16px;font-size:14px;font-weight:700;color:#0f0f1a">Total</td>
                    <td style="padding:12px 16px;font-size:14px;font-weight:700;color:#0f0f1a;text-align:right">{{total}}</td>
                  </tr>
                </table>
                <p style="margin:0;color:#9ca3af;font-size:13px">Expected delivery: <strong style="color:#374151">{{delivery_date}}</strong></p>
              </td></tr>
              <tr><td style="padding:24px 40px;border-top:1px solid #f3f4f6;text-align:center">
                <p style="margin:0;color:#9ca3af;font-size:12px">© {{year}} {{company}}. All rights reserved.</p>
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body></html>
    HTML

    invoice_body = <<~'HTML'
      <!DOCTYPE html>
      <html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
      <body style="margin:0;padding:0;background:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
        <table width="100%" cellpadding="0" cellspacing="0" style="padding:48px 16px">
          <tr><td align="center">
            <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08)">
              <tr><td style="padding:40px">
                <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px">
                  <tr>
                    <td><span style="font-size:20px;font-weight:800;color:#0f0f1a">{{company}}</span></td>
                    <td align="right">
                      <span style="font-size:12px;color:#6b7280;font-weight:600;text-transform:uppercase;letter-spacing:.5px">Invoice</span><br>
                      <span style="font-size:15px;font-weight:700;color:#0f0f1a">{{invoice_number}}</span>
                    </td>
                  </tr>
                </table>
                <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px">
                  <tr>
                    <td style="width:50%;vertical-align:top">
                      <p style="margin:0 0 4px;font-size:11px;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;font-weight:600">Bill to</p>
                      <p style="margin:0;font-size:14px;color:#374151;font-weight:600">{{name}}</p>
                      <p style="margin:0;font-size:13px;color:#6b7280">{{email}}</p>
                    </td>
                    <td style="width:50%;vertical-align:top;text-align:right">
                      <p style="margin:0 0 4px;font-size:11px;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;font-weight:600">Date</p>
                      <p style="margin:0;font-size:14px;color:#374151">{{invoice_date}}</p>
                      <p style="margin:4px 0 0;font-size:11px;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;font-weight:600">Due</p>
                      <p style="margin:0;font-size:14px;color:#374151">{{due_date}}</p>
                    </td>
                  </tr>
                </table>
                <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #e5e7eb;border-radius:8px;overflow:hidden;margin-bottom:16px">
                  <tr style="background:#f9fafb">
                    <td style="padding:10px 16px;font-size:11px;color:#6b7280;font-weight:600;text-transform:uppercase;letter-spacing:.5px">Description</td>
                    <td style="padding:10px 16px;font-size:11px;color:#6b7280;font-weight:600;text-transform:uppercase;letter-spacing:.5px;text-align:right">Amount</td>
                  </tr>
                  <tr>
                    <td style="padding:14px 16px;border-top:1px solid #e5e7eb;font-size:14px;color:#374151">{{description}}</td>
                    <td style="padding:14px 16px;border-top:1px solid #e5e7eb;font-size:14px;color:#374151;text-align:right">{{amount}}</td>
                  </tr>
                  <tr style="background:#0f0f1a">
                    <td style="padding:14px 16px;font-size:14px;font-weight:700;color:#ffffff">Total due</td>
                    <td style="padding:14px 16px;font-size:18px;font-weight:800;color:#ffffff;text-align:right">{{total}}</td>
                  </tr>
                </table>
                <p style="margin:24px 0 0;color:#9ca3af;font-size:13px;text-align:center">Thank you for your business.</p>
              </td></tr>
              <tr><td style="padding:24px 40px;border-top:1px solid #f3f4f6;text-align:center">
                <p style="margin:0;color:#9ca3af;font-size:12px">© {{year}} {{company}}. All rights reserved.</p>
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body></html>
    HTML

    reminder_body = <<~'HTML'
      <!DOCTYPE html>
      <html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
      <body style="margin:0;padding:0;background:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
        <table width="100%" cellpadding="0" cellspacing="0" style="padding:48px 16px">
          <tr><td align="center">
            <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08)">
              <tr><td style="background:#f59e0b;padding:32px 40px;text-align:center">
                <p style="margin:0 0 8px;font-size:32px">🗓️</p>
                <h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:700">Reminder: {{event_title}}</h1>
              </td></tr>
              <tr><td style="padding:40px">
                <p style="margin:0 0 24px;color:#374151;font-size:15px;line-height:1.7">Hi {{name}}, this is a friendly reminder about your upcoming appointment.</p>
                <table width="100%" cellpadding="0" cellspacing="0" style="background:#fffbeb;border:1px solid #fde68a;border-radius:8px;margin-bottom:28px">
                  <tr><td style="padding:20px 24px">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding:6px 0;font-size:13px;color:#92400e;font-weight:600;width:100px">📅 Date</td>
                        <td style="padding:6px 0;font-size:14px;color:#374151;font-weight:500">{{event_date}}</td>
                      </tr>
                      <tr>
                        <td style="padding:6px 0;font-size:13px;color:#92400e;font-weight:600">⏰ Time</td>
                        <td style="padding:6px 0;font-size:14px;color:#374151;font-weight:500">{{event_time}}</td>
                      </tr>
                      <tr>
                        <td style="padding:6px 0;font-size:13px;color:#92400e;font-weight:600">📍 Location</td>
                        <td style="padding:6px 0;font-size:14px;color:#374151;font-weight:500">{{location}}</td>
                      </tr>
                    </table>
                  </td></tr>
                </table>
                <p style="margin:0;color:#6b7280;font-size:13px">Need to reschedule? <a href="{{reschedule_url}}" style="color:#f59e0b;font-weight:600">Click here</a>.</p>
              </td></tr>
              <tr><td style="padding:24px 40px;border-top:1px solid #f3f4f6;text-align:center">
                <p style="margin:0;color:#9ca3af;font-size:12px">© {{year}} {{company}}. All rights reserved.</p>
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body></html>
    HTML

    alert_body = <<~'HTML'
      <!DOCTYPE html>
      <html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
      <body style="margin:0;padding:0;background:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
        <table width="100%" cellpadding="0" cellspacing="0" style="padding:48px 16px">
          <tr><td align="center">
            <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08)">
              <tr><td style="background:#dc2626;padding:28px 40px;text-align:center">
                <p style="margin:0 0 6px;font-size:28px">⚠️</p>
                <h1 style="margin:0;color:#ffffff;font-size:20px;font-weight:700">Security Alert</h1>
              </td></tr>
              <tr><td style="padding:40px">
                <p style="margin:0 0 20px;color:#374151;font-size:15px;line-height:1.7">Hi {{name}}, we detected a new sign-in to your account from an unrecognised device.</p>
                <table width="100%" cellpadding="0" cellspacing="0" style="background:#fef2f2;border:1px solid #fecaca;border-radius:8px;margin-bottom:28px">
                  <tr><td style="padding:20px 24px">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding:5px 0;font-size:13px;color:#991b1b;font-weight:600;width:120px">Device</td>
                        <td style="padding:5px 0;font-size:14px;color:#374151">{{device}}</td>
                      </tr>
                      <tr>
                        <td style="padding:5px 0;font-size:13px;color:#991b1b;font-weight:600">Location</td>
                        <td style="padding:5px 0;font-size:14px;color:#374151">{{location}}</td>
                      </tr>
                      <tr>
                        <td style="padding:5px 0;font-size:13px;color:#991b1b;font-weight:600">Time</td>
                        <td style="padding:5px 0;font-size:14px;color:#374151">{{time}}</td>
                      </tr>
                    </table>
                  </td></tr>
                </table>
                <p style="margin:0 0 20px;color:#374151;font-size:14px;line-height:1.6">If this was you, no action is needed. If you don't recognise this activity, secure your account immediately.</p>
                <table cellpadding="0" cellspacing="0"><tr><td style="background:#dc2626;border-radius:8px">
                  <a href="{{secure_url}}" style="display:inline-block;padding:14px 28px;color:#ffffff;font-size:14px;font-weight:600;text-decoration:none">Secure my account →</a>
                </td></tr></table>
              </td></tr>
              <tr><td style="padding:24px 40px;border-top:1px solid #f3f4f6;text-align:center">
                <p style="margin:0;color:#9ca3af;font-size:12px">© {{year}} {{company}}. All rights reserved.</p>
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body></html>
    HTML

    # Fill {{placeholders}} with believable demo values so screenshots look real.
    fill = lambda do |html, overrides = {}|
      defaults = {
        "company" => "Lumen Labs", "year" => "2026",
        "name" => "there", "first_name" => "there", "email" => "customer@example.com",
        "magic_link" => "https://app.lumenlabs.io/auth/verify?token=demo-token",
        "dashboard_url" => "https://app.lumenlabs.io/dashboard",
        "order_number" => "#LM-48217", "item_name" => "Lumen Pro — Annual",
        "item_price" => "$240.00", "total" => "$240.00",
        "delivery_date" => "Jul 7, 2026", "invoice_number" => "INV-2026-0192",
        "invoice_date" => "Jun 28, 2026", "due_date" => "Jul 12, 2026",
        "description" => "Lumen Pro subscription (1 seat)", "amount" => "$240.00",
        "event_title" => "Onboarding call", "event_date" => "Jul 2, 2026",
        "event_time" => "10:30 AM PT", "location" => "Google Meet",
        "reschedule_url" => "https://app.lumenlabs.io/appointments/reschedule",
        "device" => "Chrome on macOS", "time" => "Jun 30, 2026 09:14 PT",
        "secure_url" => "https://app.lumenlabs.io/security"
      }.merge(overrides)
      html.gsub(/\{\{\s*([\w.]+)\s*\}\}/) { defaults[Regexp.last_match(1)] || "" }
    end

    ActiveRecord::Base.logger = nil
    ActionCable.server.config.logger = Logger.new(IO::NULL) if defined?(ActionCable)

    # ──────────────────────────────────────────────────────────────────────
    # 1. WIPE
    # ──────────────────────────────────────────────────────────────────────
    conn = ActiveRecord::Base.connection
    protected_tables = %w[schema_migrations ar_internal_metadata]
    tables = conn.tables - protected_tables
    quoted = tables.map { |t| conn.quote_table_name(t) }.join(", ")
    conn.execute("TRUNCATE #{quoted} RESTART IDENTITY CASCADE")
    puts "Wiped #{tables.size} tables."

    # ──────────────────────────────────────────────────────────────────────
    # 2. ACCOUNT + USERS
    # ──────────────────────────────────────────────────────────────────────
    account = Account.create!(
      name: "Lumen Labs",
      plan: "pro",
      status: "active",
      chat_enabled: true,
      tracking_domain: "track.lumenlabs.io",
      message_retention_days: 90,
      onboarding_completed_at: 40.days.ago,
      onboarding_step: 5,
      trial_ends_at: 30.days.from_now
    )

    maya = User.create!(
      account: account, name: "Maya Chen", email: "maya@lumenlabs.io",
      role: :admin, email_verified: true, last_login_at: 2.hours.ago
    )

    operators_data = [
      { name: "Diego Alvarez", email: "diego@lumenlabs.io", role: :admin, avail: :online },
      { name: "Priya Nair",    email: "priya@lumenlabs.io", role: :member, avail: :online },
      { name: "Tom Becker",    email: "tom@lumenlabs.io",   role: :member, avail: :away },
      { name: "Sofia Rossi",   email: "sofia@lumenlabs.io", role: :member, avail: :offline }
    ]
    operators = operators_data.map do |d|
      User.create!(
        account: account, name: d[:name], email: d[:email],
        role: d[:role], email_verified: true,
        last_login_at: rand(1..6).days.ago
      )
    end
    team = [maya] + operators

    # Operator profiles
    profiles_spec = [
      { u: maya, avail: :online, bio: "Founder & head of support" },
      { u: operators[0], avail: :online,  bio: "Support engineer, billing & API" },
      { u: operators[1], avail: :online,  bio: "Onboarding specialist" },
      { u: operators[2], avail: :away,    bio: "Deliverability & integrations" },
      { u: operators[3], avail: :offline, bio: "Weekend on-call" }
    ]
    profiles_spec.each_with_index do |p, i|
      OperatorProfile.create!(
        user: p[:u], account: account, public_name: p[:u].name.split.first,
        bio: p[:bio], availability: p[:avail], auto_assign: p[:avail] != :offline,
        max_concurrent_chats: 10, sort_order: i,
        last_heartbeat_at: p[:avail] == :online ? 10.seconds.ago : 2.hours.ago
      )
    end
    puts "Users: #{User.count}, operator profiles: #{OperatorProfile.count}"

    # ──────────────────────────────────────────────────────────────────────
    # 3. ENVIRONMENTS
    # ──────────────────────────────────────────────────────────────────────
    production = Environment.create!(
      account: account, name: "Production", tag: "prod",
      api_key: "mk_live_demo_#{SecureRandom.hex(12)}",
      allow_email: true, allow_sms: true, allow_whatsapp: true,
      allow_mobile_push: true, allow_web_push: true
    )
    staging = Environment.create!(
      account: account, name: "Staging", tag: "staging",
      api_key: "mk_test_demo_#{SecureRandom.hex(12)}",
      allow_email: true, allow_sms: true, allow_whatsapp: false,
      allow_mobile_push: false, allow_web_push: false
    )
    development = Environment.create!(
      account: account, name: "Development", tag: "dev",
      api_key: "mk_dev_demo_#{SecureRandom.hex(12)}",
      allow_email: true, allow_sms: false, allow_whatsapp: false,
      allow_mobile_push: false, allow_web_push: false
    )
    puts "Environments: #{Environment.count}"

    # ──────────────────────────────────────────────────────────────────────
    # 4. SENDING IDENTITIES
    # ──────────────────────────────────────────────────────────────────────
    SendingIdentity.create!(account: account, from_name: "Lumen Labs", from_email: "hello@lumenlabs.io", is_default: true)
    SendingIdentity.create!(account: account, from_name: "Lumen Support", from_email: "support@lumenlabs.io")
    SendingIdentity.create!(account: account, from_name: "Lumen Billing", from_email: "billing@lumenlabs.io")
    default_identity = account.default_sending_identity

    # ──────────────────────────────────────────────────────────────────────
    # 5. INTEGRATIONS (all FAKE credentials)
    # ──────────────────────────────────────────────────────────────────────
    ses = SesIntegration.create!(
      account: account, environment: production, active: true,
      config: {
        "access_key_id" => "AKIADEMOEXAMPLE0001",
        "secret_access_key" => "demo-secret-not-real-ses-0001",
        "region" => "us-east-1",
        "source" => "Lumen Labs <hello@lumenlabs.io>",
        "configuration_set" => "lumen-tracking"
      }
    )
    SmtpIntegration.create!(
      account: account, environment: nil, active: true,
      config: {
        "smtp_server" => "smtp.demo-mailer.example", "port" => 587,
        "username" => "demo-smtp-user", "password" => "demo-password-not-real",
        "from" => "Lumen Labs <hello@lumenlabs.io>"
      }
    )
    twilio = TwilioIntegration.create!(
      account: account, environment: production, active: true,
      config: {
        "sid" => "ACdemo0000000000000000000000000001",
        "token" => "demo-token-not-real-twilio",
        "from" => "+15005550006"
      }
    )
    whatsapp = WhatsappIntegration.create!(
      account: account, environment: nil, active: true,
      config: {
        "phone_id" => "100000000000001",
        "token" => "demo-token-not-real-whatsapp",
        "business_account_id" => "200000000000002",
        "webhook_verify_token" => "demo-verify-token",
        "app_secret" => "demo-app-secret-not-real"
      }
    )
    fcm = FcmIntegration.create!(
      account: account, environment: nil, active: true,
      config: {
        "project_id" => "lumen-labs-demo",
        "service_account_json" => '{"type":"service_account","project_id":"lumen-labs-demo","private_key":"demo-not-real","client_email":"demo@lumen-labs-demo.iam.gserviceaccount.example"}'
      }
    )
    web_push = WebPushIntegration.create!(
      account: account, environment: production, active: true,
      config: {
        "vapid_public_key" => "BDemoPublicKeyNotReal0000000000000000000000000000000000000000000000000000000000000000000",
        "vapid_private_key" => "demo-vapid-private-not-real",
        "vapid_subject" => "mailto:hello@lumenlabs.io"
      }
    )
    puts "Integrations: #{Integration.count}"

    # ──────────────────────────────────────────────────────────────────────
    # 6. DELIVERY RULES
    # ──────────────────────────────────────────────────────────────────────
    rules_spec = [
      { type: "EmailRule", name: "Allow Lumen staff",   condition: "@lumenlabs.io",  outcome: :allow },
      { type: "EmailRule", name: "Block competitor",    condition: "@competitor.com", outcome: :deny },
      { type: "EmailRule", name: "Redirect test inbox", condition: "@example.com",   outcome: :redirect, redirect_to: "qa@lumenlabs.io" },
      { type: "SmsRule",   name: "Allow US numbers",    condition: "+1",             outcome: :allow },
      { type: "SmsRule",   name: "Block premium-rate",  condition: "+99",            outcome: :deny },
      { type: "WhatsappRule", name: "Allow UK numbers", condition: "+44",            outcome: :allow }
    ]
    rules_spec.each do |r|
      Rule.create!(
        account: account, environment: production, type: r[:type],
        name: r[:name], condition: r[:condition], outcome: r[:outcome],
        redirect_to: r[:redirect_to], active: true, scope: :any
      )
    end
    puts "Rules: #{Rule.count}"

    # ──────────────────────────────────────────────────────────────────────
    # 7. FOLDERS + LAYOUTS + TEMPLATES
    # ──────────────────────────────────────────────────────────────────────
    transactional_folder = Folder.create!(account: account, environment: production, name: "Transactional")
    lifecycle_folder = Folder.create!(account: account, environment: production, name: "Lifecycle")

    base_layout = Layout.create!(
      account: account, environment: production, name: "Branded Base",
      body: <<~'HTML'
        <!DOCTYPE html>
        <html><body style="margin:0;background:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
          <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:24px">
            <table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;overflow:hidden">
              <tr><td style="background:#0f0f1a;padding:20px;text-align:center;color:#fff;font-weight:700">Lumen Labs</td></tr>
              <tr><td style="padding:32px">{{ content }}</td></tr>
              <tr><td style="padding:16px;text-align:center;color:#9ca3af;font-size:12px">© 2026 Lumen Labs</td></tr>
            </table>
          </td></tr></table>
        </body></html>
      HTML
    )
    Layout.create!(
      account: account, environment: production, name: "Plain",
      body: "<div style=\"font-family:sans-serif;padding:24px\">{{ content }}</div>"
    )

    email_templates_spec = [
      { name: "Magic Link Login",     trigger: "magic_link",          subject: "Your sign-in link for {{company}}",        body: magic_link_body, folder: transactional_folder },
      { name: "Welcome Email",        trigger: "user_welcome",        subject: "Welcome to {{company}}, {{name}}!",        body: welcome_body,    folder: lifecycle_folder },
      { name: "Order Confirmation",   trigger: "order_confirmed",     subject: "Order {{order_number}} confirmed ✓",       body: order_body,      folder: transactional_folder },
      { name: "Invoice",              trigger: "invoice_issued",      subject: "Invoice {{invoice_number}} from {{company}}", body: invoice_body,  folder: transactional_folder },
      { name: "Appointment Reminder", trigger: "appointment_reminder", subject: "Reminder: {{event_title}} on {{event_date}}", body: reminder_body, folder: lifecycle_folder },
      { name: "Security Alert",       trigger: "security_alert",      subject: "New sign-in detected on your {{company}} account", body: alert_body, folder: transactional_folder }
    ]
    email_templates = email_templates_spec.map do |t|
      Template.create!(
        account: account, environment: production, channel: "email", body_format: "html",
        name: t[:name], trigger: t[:trigger], subject: t[:subject], body: t[:body],
        folder: t[:folder], layout: base_layout
      )
    end

    sms_templates = [
      { name: "SMS — OTP code", trigger: "sms_otp", body: "Your {{company}} code is {{code}}. It expires in 10 minutes." },
      { name: "SMS — Order shipped", trigger: "sms_order_shipped", body: "{{name}}, your order {{order_number}} has shipped! Track it: {{tracking_url}}" }
    ].map do |t|
      Template.create!(
        account: account, environment: production, channel: "sms", body_format: "markdown",
        name: t[:name], trigger: t[:trigger], body: t[:body], folder: transactional_folder
      )
    end

    whatsapp_template = Template.create!(
      account: account, environment: production, channel: "whatsapp", body_format: "markdown",
      name: "WhatsApp — Appointment", trigger: "wa_appointment", folder: lifecycle_folder,
      body: "Hi {{name}}, reminder for your appointment on {{event_date}} at {{event_time}}. Reply RESCHEDULE to change it."
    )
    puts "Folders: #{Folder.count}, Layouts: #{Layout.count}, Templates: #{Template.count}"

    # ──────────────────────────────────────────────────────────────────────
    # 8. CUSTOMERS
    # ──────────────────────────────────────────────────────────────────────
    first_names = %w[Olivia Liam Emma Noah Ava Ethan Sophia Mason Isabella Lucas Mia Logan Amelia
                     Harper Elijah Charlotte James Evelyn Benjamin Abigail Henry Emily Alexander Ella
                     Sebastian Scarlett Jack Grace Owen Chloe Daniel Victoria Matthew Aria Samuel Layla
                     David Penelope Joseph Riley Carter Nora Wyatt Hazel Julian Aurora Leo Naomi Adrian Stella]
    last_names = %w[Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez Hernandez
                    Lopez Gonzalez Wilson Anderson Thomas Taylor Moore Jackson Martin Lee Perez Thompson
                    White Harris Sanchez Clark Ramirez Lewis Robinson Walker Young Allen King Wright Scott
                    Torres Nguyen Hill Flores Green Adams Nelson Baker Hall Rivera Campbell Mitchell Carter]
    domains = %w[gmail.com outlook.com yahoo.com icloud.com acme.io northstar.co brightwave.com
                 proton.me hey.com fastmail.com]
    countries = %w[US US US GB DE FR NL ES IE IT CA AU SE]
    eu_countries = %w[DE FR NL ES IE IT]
    plans = %w[free free free pro pro enterprise]

    customers = []
    48.times do |i|
      fn = first_names[i % first_names.size]
      ln = last_names[(i * 7) % last_names.size]
      domain = domains[i % domains.size]
      email = "#{fn.downcase}.#{ln.downcase}#{i}@#{domain}"
      country = countries[i % countries.size]
      plan = plans[i % plans.size]
      cc = country == "GB" ? "+44" : (country == "US" || country == "CA" ? "+1" : "+1")
      phone = "#{cc}#{rand(2000000000..9999999999)}"
      signup = rand(5..240).days.ago
      mrr = case plan when "enterprise" then [499, 999, 1499].sample when "pro" then [49, 99, 149].sample else 0 end
      engaged_30d = rand < 0.45
      newsletter = rand < 0.7

      customers << Customer.create!(
        account: account, email: email, first_name: fn, last_name: ln,
        phone: phone, country: country,
        city: nil,
        browser: %w[Chrome Safari Firefox Edge].sample,
        os: %w[macOS Windows iOS Android Linux].sample,
        custom_attributes: {
          "plan" => plan, "country" => country, "mrr" => mrr,
          "signup_date" => signup.to_date.iso8601,
          "newsletter" => newsletter.to_s,
          "engaged_30d" => engaged_30d.to_s
        },
        created_at: signup, updated_at: signup
      )
    end

    # Spread last_seen / last_engaged; mark some unsubscribed. update_columns to
    # skip callbacks/validation so values stick exactly.
    customers.each_with_index do |c, i|
      seen = rand(0..40).days.ago - rand(0..23).hours
      engaged = c.custom_attributes["engaged_30d"] == "true" ? rand(0..29).days.ago : rand(31..120).days.ago
      c.update_columns(last_seen_at: seen, last_engaged_at: engaged)
    end
    # ~5 unsubscribed (channel and/or category)
    customers[3].update_columns(unsubscribed_channels: { "email" => 10.days.ago.iso8601 })
    customers[9].update_columns(unsubscribed_categories: { "marketing" => 6.days.ago.iso8601 })
    customers[14].update_columns(unsubscribed_channels: { "sms" => 4.days.ago.iso8601 })
    customers[21].update_columns(
      unsubscribed_channels: { "email" => 2.days.ago.iso8601 },
      unsubscribed_categories: { "marketing" => 2.days.ago.iso8601 }
    )
    customers[30].update_columns(unsubscribed_categories: { "marketing" => 20.days.ago.iso8601 })
    puts "Customers: #{Customer.count}"

    # Customer activities (a few per customer for the activity feed)
    activity_types = %w[identify page_view email_opened email_clicked feature_used]
    customers.first(30).each do |c|
      rand(1..4).times do
        CustomerActivity.create!(
          account: account, customer: c, environment: production,
          activity_type: activity_types.sample,
          properties: { "source" => "demo" },
          created_at: rand(1..20).days.ago
        )
      end
    end

    # ──────────────────────────────────────────────────────────────────────
    # 9. SEGMENTS (materialized via SegmentEvaluator)
    # ──────────────────────────────────────────────────────────────────────
    segments_spec = [
      {
        name: "Pro & Enterprise", description: "Paying customers on Pro or Enterprise plans",
        conditions: { "operator" => "or", "conditions" => [
          { "attribute" => "custom.plan", "operator" => "equals", "value" => "pro" },
          { "attribute" => "custom.plan", "operator" => "equals", "value" => "enterprise" }
        ] }
      },
      {
        name: "EU contacts", description: "Contacts based in the European Union",
        conditions: { "operator" => "or", "conditions" => eu_countries.map { |cc|
          { "attribute" => "custom.country", "operator" => "equals", "value" => cc }
        } }
      },
      {
        name: "Trial — no purchase", description: "Free-plan users who haven't upgraded",
        conditions: { "operator" => "and", "conditions" => [
          { "attribute" => "custom.plan", "operator" => "equals", "value" => "free" }
        ] }
      },
      {
        name: "Engaged last 30 days", description: "Opened or clicked in the last 30 days",
        conditions: { "operator" => "and", "conditions" => [
          { "attribute" => "custom.engaged_30d", "operator" => "equals", "value" => "true" }
        ] }
      },
      {
        name: "Newsletter subscribers", description: "Opted in to the product newsletter",
        conditions: { "operator" => "and", "conditions" => [
          { "attribute" => "custom.newsletter", "operator" => "equals", "value" => "true" }
        ] }
      }
    ]
    segments = segments_spec.map do |s|
      seg = Segment.create!(account: account, name: s[:name], description: s[:description], conditions: s[:conditions])
      members = SegmentEvaluator.new(account.customers, s[:conditions]).evaluate.to_a
      members.each do |cust|
        SegmentMembership.create!(
          account: account, segment: seg, customer: cust,
          entered_at: rand(1..40).days.ago
        )
      end
      seg.update_columns(customer_count: members.size)
      seg
    end
    segments_by_name = segments.index_by(&:name)
    puts "Segments: #{Segment.count}, memberships: #{SegmentMembership.count}"

    # ──────────────────────────────────────────────────────────────────────
    # 10. TRANSACTIONAL MESSAGES (+ deliveries, opens, clicks)
    # ──────────────────────────────────────────────────────────────────────
    email_customers = customers.select { |c| c.email.present? }
    phone_customers = customers.select { |c| c.phone.present? }

    # status weighting — "sent" is what the dashboard counts as delivered success,
    # so it dominates (≈90% success rate) with a believable tail of failures/pending.
    status_pool = (["sent"] * 90) + (["delivered"] * 3) + (["failed"] * 3) +
                  (["rejected"] * 1) + (["pending"] * 2) + (["suppressed"] * 1)

    email_template_by_trigger = email_templates.index_by(&:trigger)
    click_urls = [
      "https://app.lumenlabs.io/dashboard",
      "https://app.lumenlabs.io/orders",
      "https://lumenlabs.io/pricing",
      "https://docs.lumenlabs.io/getting-started",
      "https://app.lumenlabs.io/settings/billing"
    ]

    message_count = 0
    deliveries_count = 0
    opens_count = 0
    clicks_count = 0

    build_email = lambda do |cust, template|
      subj = fill.call(template.subject, "name" => cust.first_name, "email" => cust.email)
      body = fill.call(template.body, "name" => cust.first_name, "email" => cust.email)
      [subj, body]
    end

    120.times do |i|
      channel = %w[email email email email sms sms whatsapp push web_push][i % 9]
      status = status_pool.sample
      created = rand(0..13).days.ago - rand(0..23).hours - rand(0..59).minutes

      case channel
      when "email"
        cust = email_customers.sample
        template = email_templates.sample
        subj, body = build_email.call(cust, template)
        msg = EmailMessage.new(
          account: account, environment: production, template: template,
          trigger: template.trigger, to: cust.email, subject: subj, body: body,
          status: status, sending_identity: default_identity,
          sent_at: %w[sent delivered].include?(status) ? created + 30.seconds : nil
        )
        msg.created_at = created
        msg.save!
        integration = ses
      when "sms"
        cust = phone_customers.sample
        tmpl = sms_templates.sample
        body = fill.call(tmpl.body, "name" => cust.first_name, "code" => rand(100000..999999).to_s,
                         "order_number" => "#LM-#{rand(10000..99999)}", "tracking_url" => "https://lmn.sh/t/#{SecureRandom.hex(3)}")
        msg = SmsMessage.new(
          account: account, environment: production, template: tmpl, trigger: tmpl.trigger,
          to: cust.phone, body: body, status: status,
          sent_at: %w[sent delivered].include?(status) ? created + 5.seconds : nil
        )
        msg.created_at = created
        msg.save!
        integration = twilio
      when "whatsapp"
        cust = phone_customers.sample
        body = fill.call(whatsapp_template.body, "name" => cust.first_name,
                         "event_date" => "Jul 4", "event_time" => "2:00 PM")
        msg = WhatsappMessage.new(
          account: account, environment: production, template: whatsapp_template,
          trigger: whatsapp_template.trigger, to: cust.phone, body: body, status: status,
          sent_at: %w[sent delivered].include?(status) ? created + 5.seconds : nil
        )
        msg.created_at = created
        msg.save!
        integration = whatsapp
      when "push"
        cust = email_customers.sample
        msg = MobilePushMessage.new(
          account: account, environment: production, to: cust.email,
          subject: "New activity on your account", body: "You have a new update from Lumen Labs.",
          status: status, trigger: "push_update",
          sent_at: %w[sent delivered].include?(status) ? created + 2.seconds : nil
        )
        msg.created_at = created
        msg.save!
        integration = fcm
      else # web_push
        cust = email_customers.sample
        msg = WebPushMessage.new(
          account: account, environment: production, to: cust.email,
          subject: "Lumen Labs", body: "Your weekly summary is ready.",
          status: status, trigger: "web_push_summary",
          sent_at: %w[sent delivered].include?(status) ? created + 2.seconds : nil
        )
        msg.created_at = created
        msg.save!
        integration = web_push
      end
      message_count += 1

      # Delivery record for everything that reached a provider
      if %w[sent delivered failed].include?(status)
        Delivery.create!(
          account: account, message: msg, integration: integration,
          recipient: msg.to, status: status,
          started_at: created, completed_at: created + 20.seconds,
          provider_message_id: status == "failed" ? nil : "demo-#{SecureRandom.hex(10)}",
          error: status == "failed" ? "Provider rejected recipient (demo)" : nil,
          created_at: created, updated_at: created
        )
        deliveries_count += 1
      end

      # Opens + clicks for a good portion of successfully delivered messages
      if %w[sent delivered].include?(status) && rand < 0.62
        n_opens = rand(1..3)
        first_open = created + rand(2..120).minutes
        n_opens.times do |k|
          Open.create!(
            account: account, message: msg, opened_at: first_open + (k * rand(5..90)).minutes,
            ip_address: "203.0.113.#{rand(2..254)}",
            user_agent: "Mozilla/5.0 (#{%w[Macintosh Windows iPhone Android].sample})",
            created_at: first_open
          )
          opens_count += 1
        end
        msg.update_columns(open_count: n_opens, first_opened_at: first_open)

        if channel == "email" && rand < 0.45
          first_click = first_open + rand(1..30).minutes
          Click.create!(
            account: account, message: msg, url: click_urls.sample,
            clicked_at: first_click, ip_address: "203.0.113.#{rand(2..254)}",
            user_agent: "Mozilla/5.0", referer: "https://mail.google.com/",
            created_at: first_click
          )
          clicks_count += 1
          msg.update_columns(click_count: 1, first_clicked_at: first_click)
        end
      end
    end
    puts "Messages: #{message_count}, Deliveries: #{deliveries_count}, Opens: #{opens_count}, Clicks: #{clicks_count}"

    # ──────────────────────────────────────────────────────────────────────
    # 11. CAMPAIGNS (+ deliveries, opens, clicks)
    # ──────────────────────────────────────────────────────────────────────
    campaigns_spec = [
      { name: "April Product Update", channel: "email", status: "sent", segment: "Newsletter subscribers", days_ago: 12, subject: "What's new in Lumen Labs — April" },
      { name: "Win-back — dormant trials", channel: "email", status: "sent", segment: "Trial — no purchase", days_ago: 9, subject: "We miss you — here's 20% off Pro" },
      { name: "Enterprise webinar invite", channel: "email", status: "sent", segment: "Pro & Enterprise", days_ago: 6, subject: "You're invited: scaling messaging at scale" },
      { name: "Black Friday Preview", channel: "email", status: "sending", segment: "Newsletter subscribers", days_ago: 0, subject: "Early access: Black Friday deals inside" },
      { name: "EU compliance update", channel: "email", status: "draft", segment: "EU contacts", days_ago: nil, subject: "Important: changes to data processing" },
      { name: "SMS flash sale", channel: "sms", status: "sent", segment: "Engaged last 30 days", days_ago: 4, subject: nil }
    ]

    campaigns_spec.each do |c|
      seg = segments_by_name[c[:segment]]
      sent_at = c[:days_ago] ? c[:days_ago].days.ago : nil
      campaign = Campaign.create!(
        account: account, environment: production, segment: seg,
        name: c[:name], channel: c[:channel], status: "draft",
        subject: c[:subject], from_email: "hello@lumenlabs.io",
        content: "<p>Hi {{first_name}}, #{c[:name]} — read more on our site.</p>",
        sending_identity: default_identity,
        template: c[:channel] == "email" ? email_templates.sample : nil,
        created_at: (c[:days_ago] || 0).days.ago - 1.day
      )

      members = seg.segment_memberships.active.includes(:customer).map(&:customer).compact
      members = members.first(rand(18..30))

      if c[:status] == "draft"
        campaign.update_columns(status: "draft", recipient_count: members.size)
        next
      end

      members.each_with_index do |cust, idx|
        # For "sending" leave a chunk pending; others mostly sent
        delivery_status =
          if c[:status] == "sending"
            idx < (members.size * 0.6) ? "sent" : "pending"
          else
            r = rand
            r < 0.88 ? "sent" : (r < 0.95 ? "failed" : "rejected")
          end

        opened = delivery_status == "sent" && rand < 0.45 # ~45% open
        clicked = opened && rand < 0.22                   # ~10% overall click
        d_sent_at = %w[sent].include?(delivery_status) ? (sent_at || Time.current) + idx.minutes : nil

        cd = CampaignDelivery.create!(
          campaign: campaign, account: account, customer: cust,
          email: cust.email, channel: c[:channel], status: delivery_status,
          tracking_token: SecureRandom.hex(16),
          sent_at: d_sent_at,
          opened_at: opened ? (d_sent_at || Time.current) + rand(10..600).minutes : nil,
          open_count: opened ? rand(1..4) : 0,
          click_count: clicked ? rand(1..2) : 0,
          error_message: delivery_status == "failed" ? "Hard bounce (demo)" : nil,
          created_at: campaign.created_at
        )
      end

      # Set campaign status explicitly. For "sent" campaigns, force sent (no pending).
      if c[:status] == "sending"
        campaign.update_columns(status: "sending", recipient_count: members.size, sent_at: sent_at)
      else
        campaign.update_columns(status: "sent", recipient_count: members.size, sent_at: sent_at)
      end
    end
    puts "Campaigns: #{Campaign.count}, CampaignDeliveries: #{CampaignDelivery.count}"

    # ──────────────────────────────────────────────────────────────────────
    # 12. DRIP CAMPAIGNS (+ steps, enrollments, executions)
    # ──────────────────────────────────────────────────────────────────────
    drips_spec = [
      {
        name: "Trial onboarding", status: "active", segment: "Trial — no purchase",
        steps: [
          { channel: "email", delay: 0, template: email_template_by_trigger["user_welcome"], conditions: {} },
          { channel: "email", delay: 2, template: email_template_by_trigger["appointment_reminder"], conditions: {} },
          { channel: "sms",   delay: 4, template: sms_templates.first, conditions: { "operator" => "and", "conditions" => [{ "attribute" => "custom.plan", "operator" => "equals", "value" => "free" }] } },
          { channel: "email", delay: 7, template: email_template_by_trigger["invoice_issued"], conditions: {} }
        ],
        enroll: 12
      },
      {
        name: "Win-back dormant", status: "paused", segment: "Engaged last 30 days",
        steps: [
          { channel: "email", delay: 0, template: email_template_by_trigger["order_confirmed"], conditions: {} },
          { channel: "email", delay: 3, template: email_template_by_trigger["security_alert"], conditions: {} },
          { channel: "email", delay: 6, template: email_template_by_trigger["user_welcome"], conditions: {} }
        ],
        enroll: 6
      },
      {
        name: "Enterprise nurture", status: "draft", segment: "Pro & Enterprise",
        steps: [
          { channel: "email", delay: 0, template: email_template_by_trigger["user_welcome"], conditions: {} },
          { channel: "email", delay: 5, template: email_template_by_trigger["appointment_reminder"], conditions: {} },
          { channel: "email", delay: 10, template: email_template_by_trigger["invoice_issued"], conditions: {} }
        ],
        enroll: 0
      }
    ]

    drips_spec.each do |d|
      seg = segments_by_name[d[:segment]]
      drip = DripCampaign.create!(
        account: account, environment: production, segment: seg,
        name: d[:name], status: d[:status],
        sending_identity: default_identity,
        enroll_existing_on_start: true
      )
      steps = d[:steps].each_with_index.map do |s, idx|
        DripStep.create!(
          drip_campaign: drip, account: account, template: s[:template],
          position: idx + 1, channel: s[:channel], delay_days: s[:delay],
          conditions: s[:conditions], on_fail: "skip"
        )
      end

      next if d[:enroll].zero?

      members = seg.segment_memberships.active.includes(:customer).map(&:customer).compact.first(d[:enroll])
      members.each_with_index do |cust, idx|
        position = rand(0..steps.size)
        completed = position >= steps.size
        entered = rand(2..20).days.ago
        enrollment = DripEnrollment.create!(
          drip_campaign: drip, account: account, customer: cust,
          status: completed ? "completed" : "active",
          current_position: position,
          anchor_at: entered, entered_at: entered,
          next_run_at: completed ? nil : (entered + rand(1..5).days),
          completed_at: completed ? entered + steps.size.days : nil
        )
        # Executions for steps already passed
        steps.first(position).each do |step|
          sched = entered + step.delay_days.days
          DripStepExecution.create!(
            drip_enrollment: enrollment, drip_step: step, account: account,
            status: "sent", scheduled_for: sched, evaluated_at: sched, sent_at: sched
          )
        end
      end
    end
    puts "DripCampaigns: #{DripCampaign.count}, Steps: #{DripStep.count}, Enrollments: #{DripEnrollment.count}, Executions: #{DripStepExecution.count}"

    # ──────────────────────────────────────────────────────────────────────
    # 13. CONVERSATION TAGS + CANNED RESPONSES + MAILBOX
    # ──────────────────────────────────────────────────────────────────────
    tag_names = %w[billing bug feature-request onboarding urgent vip]
    tags = tag_names.each_with_index.map do |name, i|
      ConversationTag.create!(account: account, name: name, sort_order: i, is_quick_reply: i < 3)
    end
    tags_by_name = tags.index_by(&:name)

    canned = [
      { shortcut: "/thanks", title: "Thank you", content: "Thanks for reaching out! We really appreciate you taking the time to let us know." },
      { shortcut: "/refund", title: "Refund processed", content: "I've processed your refund — it should appear on your statement within 5-10 business days." },
      { shortcut: "/escalate", title: "Escalating", content: "I'm escalating this to our engineering team and will update you as soon as I hear back." },
      { shortcut: "/hours", title: "Support hours", content: "Our support team is available Mon-Fri, 9am-6pm PT. We'll get back to you as soon as we can!" },
      { shortcut: "/docs", title: "Docs link", content: "You can find a step-by-step guide in our docs: https://docs.lumenlabs.io" }
    ]
    canned.each { |c| CannedResponse.create!(account: account, created_by: maya, shortcut: c[:shortcut], title: c[:title], content: c[:content]) }

    mailbox = Mailbox.create!(
      account: account, environment: production, name: "Support",
      email_address: "support@lumenlabs.io", provider: :imap, ticket_prefix: "SUP",
      config: { "host" => "imap.demo-mail.example", "port" => 993, "username" => "support@lumenlabs.io", "password" => "demo-not-real", "ssl" => true, "folder" => "INBOX" },
      auto_assign: true, auto_reply_enabled: true
    )

    # ──────────────────────────────────────────────────────────────────────
    # 14. EMAIL TICKETS (conversations, source: email)
    # ──────────────────────────────────────────────────────────────────────
    email_tickets = [
      {
        from: "sarah.johnson@acme.io", name: "Sarah Johnson",
        subject: "Cannot access billing portal after upgrade",
        messages: [
          { from: :customer, content: "Hi, I upgraded to Pro but I still can't access the billing portal — it returns a 403. I've cleared my cache and tried another browser. Could you look into this?", html: "<p>Hi, I upgraded to Pro but I still can't access the billing portal — it returns a <strong>403</strong>. I've cleared my cache and tried another browser. Could you look into this?</p>" },
          { from: :operator, content: "Hi Sarah, your billing permissions hadn't propagated. I've refreshed them — could you log out and back in?" },
          { from: :customer, content: "That worked, thank you!" }
        ],
        status: :resolved, priority: :normal, tags: ["billing"], cc: ["finance@acme.io"], assigned_to: 0, age_hours: 48
      },
      {
        from: "mike.chen@northstar.co", name: "Mike Chen",
        subject: "API rate limiting hitting us in production",
        messages: [
          { from: :customer, content: "We're seeing 429s from the Messy API at peak (2-4pm UTC). On Pro we expect 1000 req/min but we're throttled at ~500. This blocks our transactional email.", html: "<p>We're seeing <code>429</code>s from the API at peak. On Pro we expect 1000 req/min but we're throttled at ~500.</p>" }
        ],
        status: :open, priority: :urgent, tags: ["bug", "urgent"], cc: ["devops@northstar.co"], assigned_to: 1, age_hours: 3
      },
      {
        from: "lisa.park@brightwave.com", name: "Lisa Park",
        subject: "Feature request: drag-and-drop email builder",
        messages: [
          { from: :customer, content: "Love Messy! A visual drag-and-drop template builder would be amazing — writing HTML by hand is tedious for our design team. Is it on the roadmap?", html: "<p>Love Messy! A visual drag-and-drop template builder would be amazing. Is it on the roadmap?</p>" },
          { from: :operator, content: "Hi Lisa, a visual builder is on our roadmap for Q3. I've added your request to the tracker so you'll be notified when it ships." }
        ],
        status: :pending, priority: :normal, tags: ["feature-request"], cc: [], assigned_to: 2, age_hours: 72
      },
      {
        from: "james.wilson@acme.io", name: "James Wilson",
        subject: "Onboarding: SSO setup with Okta",
        messages: [
          { from: :customer, content: "We're on Enterprise and need SSO with Okta. The docs mention SAML but I can't find the config page. Our rollout deadline is Friday.", html: "<p>We're on Enterprise and need SSO with Okta. I can't find the SAML config page. Deadline is Friday.</p>" },
          { from: :customer, content: "Following up — any update on this?" }
        ],
        status: :open, priority: :high, tags: ["onboarding", "urgent", "vip"], cc: ["security@acme.io"], assigned_to: 1, age_hours: 24
      },
      {
        from: "anna.meyer@brightwave.com", name: "Anna Meyer",
        subject: "Order confirmation emails bouncing since yesterday",
        messages: [
          { from: :customer, content: "Since ~18:00 CET yesterday our order confirmation emails stopped going out — they're all showing as failed in the message log. Order confirmations depend on it — urgent.", html: "<p>Since ~18:00 CET yesterday our order confirmation emails stopped going out. Urgent.</p>" },
          { from: :operator, content: "Hi Anna, your SES sending region was hitting a temporary rate limit starting 17:58 CET so those sends failed after 3 retries. It's cleared now — I've retried the failed messages and they've gone out." },
          { from: :customer, content: "Confirmed, the confirmations are flowing again. Thank you!" }
        ],
        status: :resolved, priority: :urgent, tags: ["bug"], cc: ["dev@brightwave.com"], assigned_to: 0, age_hours: 18
      },
      {
        from: "david.brown@gmail.com", name: "David Brown",
        subject: "How do I set up email open tracking?",
        messages: [
          { from: :customer, content: "I'm trying to track email opens for my campaigns but can't find how to enable tracking pixels. Is this available on the free plan?", html: "<p>How do I enable open tracking? Is it on the free plan?</p>" }
        ],
        status: :open, priority: :normal, tags: [], cc: [], assigned_to: nil, age_hours: 6
      }
    ]

    email_tickets.each do |t|
      cust = customers.find { |c| c.email == t[:from] } ||
             Customer.create!(account: account, email: t[:from], first_name: t[:name].split.first, last_name: t[:name].split.last)
      created = t[:age_hours].hours.ago
      assignee = t[:assigned_to] ? team[t[:assigned_to]] : nil

      conv = Conversation.create!(
        account: account, environment: production, customer: cust,
        visitor_token: "email_#{SecureRandom.hex(8)}", visitor_name: t[:name], visitor_email: t[:from],
        status: t[:status], priority: t[:priority], source: :email, subject: t[:subject],
        ticket_number: mailbox.next_ticket_number!, assigned_user_id: assignee&.id,
        created_at: created, updated_at: created
      )
      ConversationAssignment.create!(conversation: conv, assigned_to_id: assignee.id, assigned_by_id: maya.id, created_at: created) if assignee

      EmailThread.create!(
        account: account, mailbox: mailbox, conversation: conv, ticket_number: conv.ticket_number,
        from_email: t[:from], from_name: t[:name], subject: t[:subject], cc_list: t[:cc], created_at: created
      )
      t[:tags].each { |tn| conv.conversation_tags << tags_by_name[tn] if tags_by_name[tn] }

      msg_time = created
      t[:messages].each do |m|
        msg_time += (15 + rand(120)).minutes
        is_op = m[:from] == :operator
        cm = ConversationMessage.create!(
          conversation: conv, account: account,
          sender_type: is_op ? "User" : "Customer",
          sender_id: is_op ? (assignee || maya).id : cust.id,
          message_type: :text, content: m[:content], private: false,
          metadata: is_op ? {} : { "email" => true },
          created_at: msg_time, updated_at: msg_time
        )
        unless is_op
          EmailMessageDetail.create!(
            conversation_message: cm,
            message_id_header: "<#{SecureRandom.hex(12)}@#{t[:from].split('@').last}>",
            from_email: t[:from], from_name: t[:name], to_email: mailbox.email_address,
            cc_list: t[:cc], html_body: m[:html] || m[:content], text_body: m[:content],
            provider_uid: "demo_#{SecureRandom.hex(6)}"
          )
        end
      end
      conv.update_columns(
        resolved_at: conv.resolved? ? msg_time : nil,
        updated_at: msg_time
      )
    end

    # ──────────────────────────────────────────────────────────────────────
    # 15. WIDGET CHATS (conversations, source: widget)
    # ──────────────────────────────────────────────────────────────────────
    widget_chats = [
      {
        cust_idx: 2, name: "Olivia Smith", country: "US", browser: "Chrome", page: "https://lumenlabs.io/pricing",
        status: :open, priority: :normal, tags: ["billing"], assigned_to: 1,
        messages: [
          { from: :customer, content: "Hi! Quick question — does the Pro plan include WhatsApp messaging?" },
          { from: :operator, content: "Hey Olivia! Yes, Pro includes WhatsApp, SMS, email, and push. Want me to walk you through setup?" },
          { from: :customer, content: "That would be great, thanks!" }
        ]
      },
      {
        cust_idx: 5, name: "Ethan Davis", country: "GB", browser: "Safari", page: "https://app.lumenlabs.io/dashboard",
        status: :pending, priority: :high, tags: ["bug"], assigned_to: 2,
        messages: [
          { from: :customer, content: "My dashboard charts are showing 'no data' even though I sent messages today." },
          { from: :operator, content: "Thanks for flagging — that can happen if the timezone is misconfigured. What timezone is your account set to?" }
        ]
      },
      {
        cust_idx: 8, name: "Mia Garcia", country: "DE", browser: "Firefox", page: "https://lumenlabs.io/",
        status: :resolved, priority: :normal, tags: ["onboarding"], assigned_to: 0,
        messages: [
          { from: :customer, content: "How do I add my team members?" },
          { from: :operator, content: "Go to Settings → Team and click Invite. They'll get a magic-link email to join." },
          { from: :customer, content: "Perfect, found it. Thanks!" }
        ]
      },
      {
        cust_idx: 11, name: "Noah Wilson", country: "US", browser: "Edge", page: "https://app.lumenlabs.io/campaigns",
        status: :open, priority: :urgent, tags: ["urgent", "vip"], assigned_to: 1,
        messages: [
          { from: :customer, content: "Our campaign send is stuck at 'sending' for 2 hours. We have a launch in 30 minutes!" },
          { from: :operator, content: "On it — checking your queue now. Hang tight." }
        ]
      },
      {
        cust_idx: 16, name: "Sophia Lee", country: "NL", browser: "Chrome", page: "https://lumenlabs.io/integrations",
        status: :snoozed, priority: :normal, tags: ["feature-request"], assigned_to: nil,
        messages: [
          { from: :customer, content: "Do you have a Zapier integration planned?" }
        ]
      },
      {
        cust_idx: 19, name: "Liam Martinez", country: "CA", browser: "Safari", page: "https://app.lumenlabs.io/contacts",
        status: :open, priority: :normal, tags: [], assigned_to: nil,
        messages: [
          { from: :customer, content: "Can I import contacts from a CSV?" },
          { from: :operator, content: "Absolutely! Contacts → Import → upload your CSV and map the columns." }
        ]
      }
    ]

    widget_chats.each do |w|
      cust = customers[w[:cust_idx]]
      created = rand(1..96).hours.ago
      assignee = w[:assigned_to] ? team[w[:assigned_to]] : nil
      conv = Conversation.create!(
        account: account, environment: production, customer: cust,
        visitor_token: "widget_#{SecureRandom.hex(8)}",
        visitor_name: w[:name], visitor_email: cust.email,
        status: w[:status], priority: w[:priority], source: :widget,
        assigned_user_id: assignee&.id,
        visitor_page_url: w[:page], visitor_page_title: "Lumen Labs",
        visitor_user_agent: "Mozilla/5.0 (#{w[:browser]})",
        visitor_ip: "198.51.100.#{rand(2..254)}", visitor_country: w[:country],
        visitor_last_seen_at: created + rand(1..30).minutes,
        snoozed_until: w[:status] == :snoozed ? 1.day.from_now : nil,
        created_at: created, updated_at: created
      )
      ConversationAssignment.create!(conversation: conv, assigned_to_id: assignee.id, assigned_by_id: maya.id, created_at: created) if assignee
      w[:tags].each { |tn| conv.conversation_tags << tags_by_name[tn] if tags_by_name[tn] }

      msg_time = created
      w[:messages].each do |m|
        msg_time += rand(2..40).minutes
        is_op = m[:from] == :operator
        ConversationMessage.create!(
          conversation: conv, account: account,
          sender_type: is_op ? "User" : "Customer",
          sender_id: is_op ? (assignee || maya).id : cust.id,
          message_type: :text, content: m[:content], private: false,
          created_at: msg_time, updated_at: msg_time
        )
      end
      conv.update_columns(resolved_at: conv.resolved? ? msg_time : nil, updated_at: msg_time)
    end
    # Make sure the founder's inbox is populated (so the default "assigned to me" view isn't empty)
    Conversation.where(status: %w[open pending snoozed]).update_all(assigned_user_id: maya.id)

    puts "Conversations: #{Conversation.count}, ConversationMessages: #{ConversationMessage.count}, Tags: #{ConversationTag.count}, Canned: #{CannedResponse.count}"

    # ──────────────────────────────────────────────────────────────────────
    # 16. CHAT WIDGET SETTINGS
    # ──────────────────────────────────────────────────────────────────────
    ChatWidgetSettings.create!(
      account: account, enabled: true,
      primary_color: "#3B82F6", title: "Chat with Lumen Labs",
      greeting_message: "Hi there! 👋 Questions about Lumen Labs? We're here to help.",
      offline_message: "We're offline right now. Leave a message and we'll reply by email.",
      show_operator_avatars: true, show_operator_count: true,
      business_hours_enabled: true, timezone: "America/Los_Angeles",
      business_hours: { "mon" => { "start" => "09:00", "end" => "18:00" }, "tue" => { "start" => "09:00", "end" => "18:00" },
                        "wed" => { "start" => "09:00", "end" => "18:00" }, "thu" => { "start" => "09:00", "end" => "18:00" },
                        "fri" => { "start" => "09:00", "end" => "17:00" } },
      allowed_domains: ["lumenlabs.io", "app.lumenlabs.io", "*.lumenlabs.io"]
    )

    # ──────────────────────────────────────────────────────────────────────
    # 17b. SOCIAL PUBLISHING (Meta credential, regions, a planned month)
    # ──────────────────────────────────────────────────────────────────────
    # Meta credential — FAKE system-user token. The publishing target (Page / IG)
    # lives on each region, not here. Demo creatives are tracked repo assets in
    # lib/tasks/demo_assets/socials, so re-seeding never touches the network.
    meta_social = MetaSocialIntegration.create!(
      account: account, environment: production, active: true,
      config: {
        "access_token" => "EAADemoSystemUserTokenNotReal000000000000",
        "app_secret" => "demo-app-secret-not-real",
        "label" => "Lumen Labs — Meta Business"
      }
    )

    socials_dir = Rails.root.join("lib/tasks/demo_assets/socials")
    attach_demo = lambda do |attachment, filename|
      attachment.attach(io: File.open(socials_dir.join(filename)), filename: filename, content_type: "image/png")
    end

    hashtag_pool = %w[#saas #developers #devtools #messaging #api #emailmarketing
                      #startup #buildinpublic #customerexperience #deliverability]

    region_us = SocialRegion.create!(
      account: account, environment: production, integration: meta_social,
      name: "United States", timezone: "America/Los_Angeles", post_hour: 9,
      countries: %w[US], active: true, hashtags: hashtag_pool,
      page_id: "1027384756610293", page_name: "Lumen Labs",
      ig_business_account_id: "17841400000000001", ig_username: "lumenlabs",
      ad_account_id: "1234567890", post_to_facebook: true, post_to_instagram: true
    )
    SocialRegion.create!(
      account: account, environment: production, integration: meta_social,
      name: "United Kingdom", timezone: "Europe/London", post_hour: 10,
      countries: %w[GB], active: true, hashtags: hashtag_pool,
      page_id: "1027384756699871", page_name: "Lumen Labs UK",
      ig_business_account_id: "17841400000000002", ig_username: "lumenlabs.uk",
      ad_account_id: "1234567891", post_to_facebook: true, post_to_instagram: false
    )

    # Creative pool — copy + the 4:5 feed render for each. Reel (9:16) and the
    # 3-slide carousel are separate specs.
    creatives = [
      { key: :one_api, headline: "One API. Every channel.",
        body: "Email, SMS, WhatsApp and push behind a single request. Ship messaging without the integration sprawl.\n\n#api #developers",
        cta_label: "Read the docs", cta_url: "https://lumenlabs.io/docs", feed: "feed_one_api.png" },
      { key: :inbox, headline: "Meet the Shared Inbox",
        body: "Chat and email tickets in one queue — assign, tag, and reply with saved responses.\n\n#customerexperience #saas",
        cta_label: "See it live", cta_url: "https://lumenlabs.io/inbox", feed: "feed_shared_inbox.png" },
      { key: :stat, headline: "99.98% delivered",
        body: "40M+ messages last month, and almost every one landed. Deliverability you can trust.\n\n#deliverability #messaging",
        cta_label: "How we do it", cta_url: "https://lumenlabs.io/deliverability", feed: "feed_delivery_stat.png" },
      { key: :team, headline: "The people behind Lumen",
        body: "A small team obsessed with making developer messaging effortless. We're hiring.\n\n#startup #buildinpublic",
        cta_label: "Join us", cta_url: "https://lumenlabs.io/careers", feed: "feed_team.png" },
      { key: :tips, headline: "3 ways to cut email bounces",
        body: "Verify your lists, use double opt-in, and watch your sender reputation. Your inbox placement will thank you.\n\n#emailmarketing #deliverability",
        cta_label: "Get the guide", cta_url: "https://lumenlabs.io/guides/bounces", feed: "feed_bounce_tips.png" },
      { key: :webinar, headline: "Live: Scaling Messaging",
        body: "Join us Jul 18 at 5PM PT for a hands-on session on scaling to millions of sends.\n\n#devtools #webinar",
        cta_label: "Save your seat", cta_url: "https://lumenlabs.io/live", feed: "feed_webinar.png" }
    ]
    creatives_by_key = creatives.index_by { |c| c[:key] }
    reel_spec = { headline: "5 deliverability tips",
                  body: "Quick wins to keep your email out of spam. Save this one.\n\n#deliverability #emailmarketing",
                  cta_label: "Watch", cta_url: "https://lumenlabs.io/reels", reel: "reel_5_tips.png" }
    carousel_spec = { headline: "How a message finds its channel",
                      body: "From one API call to delivered-and-tracked, in three steps. Swipe →\n\n#api #developers",
                      cta_label: "Try it free", cta_url: "https://lumenlabs.io/signup",
                      carousel: %w[carousel_1_request.png carousel_2_routing.png carousel_3_delivered.png] }

    build_alt = lambda do |post, spec, position|
      alt = post.social_alternatives.create!(
        source: :generated, position: position,
        headline: spec[:headline], body: spec[:body],
        cta_label: spec[:cta_label], cta_url: spec[:cta_url]
      )
      attach_demo.call(alt.feed_media, spec[:feed]) if spec[:feed]
      attach_demo.call(alt.reel_media, spec[:reel]) if spec[:reel]
      Array(spec[:carousel]).each { |f| attach_demo.call(alt.carousel_media, f) }
      alt
    end

    log_delivery = lambda do |post, slot_sym, at, channels|
      channels.each do |ch|
        SocialPostDelivery.create!(
          social_post: post, integration: meta_social, account: account,
          slot: slot_sym, channel: ch, status: :posted,
          provider_post_id: "demo_#{ch}_#{SecureRandom.hex(7)}", posted_at: at
        )
      end
    end

    today = region_us.local_today
    posted_ch = %i[facebook instagram] # region_us posts to both

    # A month around today: past days posted (green), today/near-future ready
    # (amber), later days still pending with multiple candidate creatives
    # (multi-thumb cells), plus one failed and one skipped day for realism.
    day_plan = [
      { off: -6, kind: :posted, spec: :stat },
      { off: -5, kind: :posted_carousel },
      { off: -4, kind: :posted, spec: :inbox },
      { off: -3, kind: :posted_reel },
      { off: -2, kind: :failed, spec: :webinar },
      { off: -1, kind: :posted, spec: :team },
      { off: 0,  kind: :ready,  spec: :one_api },
      { off: 1,  kind: :pending, specs: %i[tips inbox team] },
      { off: 2,  kind: :ready,  spec: :stat },
      { off: 3,  kind: :ready_carousel },
      { off: 4,  kind: :pending, specs: %i[one_api webinar] },
      { off: 5,  kind: :ready,  spec: :tips },
      { off: 6,  kind: :pending, specs: %i[inbox stat team] },
      { off: 7,  kind: :ready,  spec: :webinar },
      { off: 8,  kind: :pending, specs: %i[one_api tips] },
      { off: 9,  kind: :ready,  spec: :team },
      { off: 11, kind: :ready,  spec: :stat },
      { off: 13, kind: :pending, specs: %i[webinar inbox] },
      { off: 15, kind: :ready,  spec: :inbox },
      { off: 17, kind: :pending, specs: %i[stat team] },
      { off: 19, kind: :ready,  spec: :one_api },
      { off: 20, kind: :pending, specs: %i[tips webinar inbox] }
    ]

    social_posted = 0
    day_plan.each do |plan|
      date = today + plan[:off]
      next unless date.month == today.month && date.year == today.year # keep within the default month view

      post = region_us.social_posts.create!(post_date: date)
      at = date.to_time.change(hour: region_us.post_hour)

      case plan[:kind]
      when :posted
        alt = build_alt.call(post, creatives_by_key[plan[:spec]], 0)
        post.update!(feed_alternative: alt, status: :posted)
        log_delivery.call(post, :feed, at, posted_ch); social_posted += 1
      when :posted_carousel
        alt = build_alt.call(post, carousel_spec, 0)
        post.update!(carousel_alternative: alt, status: :posted)
        log_delivery.call(post, :carousel, at, posted_ch); social_posted += 1
      when :posted_reel
        alt = build_alt.call(post, reel_spec, 0)
        post.update!(reel_alternative: alt, status: :posted)
        log_delivery.call(post, :reel, at, posted_ch); social_posted += 1
      when :failed
        alt = build_alt.call(post, creatives_by_key[plan[:spec]], 0)
        post.update!(feed_alternative: alt, status: :failed, publish_error: "Instagram Graph API: media fetch timed out (demo)")
        log_delivery.call(post, :feed, at, %i[facebook]) # FB landed
        SocialPostDelivery.create!(social_post: post, integration: meta_social, account: account,
                                   slot: :feed, channel: :instagram, status: :failed,
                                   error_message: "media fetch timed out (demo)")
      when :skipped
        build_alt.call(post, creatives_by_key[plan[:spec]], 0)
        post.update!(status: :skipped)
      when :ready
        alt = build_alt.call(post, creatives_by_key[plan[:spec]], 0)
        post.update!(feed_alternative: alt, status: :ready)
      when :ready_carousel
        alt = build_alt.call(post, carousel_spec, 0)
        post.update!(carousel_alternative: alt, status: :ready)
      when :pending
        plan[:specs].each_with_index { |k, j| build_alt.call(post, creatives_by_key[k], j) }
      end
    end
    puts "SocialRegions: #{SocialRegion.count}, SocialPosts: #{SocialPost.count}, " \
         "SocialAlternatives: #{SocialAlternative.count}, posted days: #{social_posted}"

    # ──────────────────────────────────────────────────────────────────────
    # 18. MCP SERVER — agent connections + usage log
    # ──────────────────────────────────────────────────────────────────────
    McpSetting.create!(account: account, enabled: true)

    mcp_client = lambda do |name|
      McpClient.create!(
        name: name,
        client_id: "mcp_client_demo_#{name.downcase.gsub(/\W+/, '_')}",
        redirect_uris: ["https://#{name.downcase.gsub(/\W+/, '')}.example/callback"],
        token_endpoint_auth_method: "none",
        grant_types: %w[authorization_code refresh_token]
      )
    end
    claude_client  = mcp_client.call("Claude")
    chatgpt_client = mcp_client.call("ChatGPT")
    cursor_client  = mcp_client.call("Cursor")

    mcp_grant = lambda do |user:, env:, client:, scopes:, last_used:, revoked: false|
      g = McpGrant.create!(
        account: account, user: user, environment: env, mcp_client: client,
        scopes: scopes, last_used_at: last_used, revoked_at: revoked ? 3.days.ago : nil
      )
      unless revoked
        McpToken.issue!(grant: g, kind: :access)
        McpToken.issue!(grant: g, kind: :refresh)
      end
      g
    end

    priya = operators[1] # a member — used to show a limited-scope connection + a rejected admin tool
    g_claude  = mcp_grant.call(user: maya,  env: production, client: claude_client,
                               scopes: %w[messaging audience campaigns analytics templates], last_used: 7.minutes.ago)
    g_chatgpt = mcp_grant.call(user: maya,  env: production, client: chatgpt_client,
                               scopes: %w[messaging segments analytics], last_used: 2.hours.ago)
    g_cursor  = mcp_grant.call(user: priya, env: staging, client: cursor_client,
                               scopes: %w[messaging templates automations], last_used: 1.day.ago)
    mcp_grant.call(user: priya, env: production, client: claude_client,
                   scopes: %w[messaging], last_used: 9.days.ago, revoked: true)

    mcp_log_rows = [
      [g_claude,  maya,  "dashboard_stats",     :ok,       200, 84,  4.minutes.ago,  nil],
      [g_claude,  maya,  "list_campaigns",      :ok,       200, 132, 6.minutes.ago,  nil],
      [g_claude,  maya,  "send_message",        :ok,       201, 210, 11.minutes.ago, nil],
      [g_claude,  maya,  "identify_customer",   :ok,       200, 96,  14.minutes.ago, nil],
      [g_chatgpt, maya,  "preview_segment",     :ok,       200, 173, 38.minutes.ago, nil],
      [g_chatgpt, maya,  "list_messages",       :ok,       200, 61,  52.minutes.ago, nil],
      [g_chatgpt, maya,  "send_message",        :error,    422, 188, 70.minutes.ago, "Email channel is set to block by default"],
      [g_claude,  maya,  "create_template",     :ok,       201, 145, 2.hours.ago,    nil],
      [g_cursor,  priya, "list_templates",      :ok,       200, 58,  3.hours.ago,    nil],
      [g_cursor,  priya, "update_template",     :ok,       200, 121, 4.hours.ago,    nil],
      [g_cursor,  priya, "list_users",          :rejected, nil, 0,   5.hours.ago,    "This connection is not authorized for tool: list_users"],
      [g_claude,  maya,  "campaign_deliveries", :ok,       200, 240, 6.hours.ago,    nil],
      [g_chatgpt, maya,  "segment_attributes",  :ok,       200, 47,  8.hours.ago,    nil],
      [g_claude,  maya,  "dashboard_stats",     :ok,       200, 79,  1.day.ago,      nil]
    ]
    mcp_log_rows.each do |grant, user, tool, status, http, ms, at, err|
      McpRequestLog.create!(
        account: account, mcp_grant: grant, user: user, environment_id: grant.environment_id,
        tool_name: tool, jsonrpc_method: "tools/call", arguments: {},
        status: status, http_status: http, duration_ms: ms, error_message: err, created_at: at
      )
    end
    puts "MCP: grants #{McpGrant.count}, logs #{McpRequestLog.count}"

    # ──────────────────────────────────────────────────────────────────────
    # 19. SUMMARY
    # ──────────────────────────────────────────────────────────────────────
    maya.generate_magic_link_token!

    puts "\n" + ("=" * 60)
    puts "DEMO SEED COMPLETE — Lumen Labs"
    puts "=" * 60
    summary = {
      "Account"             => Account.count,
      "User"                => User.count,
      "Environment"         => Environment.count,
      "Integration"         => Integration.count,
      "Rule"                => Rule.count,
      "Template"            => Template.count,
      "Customer"            => Customer.count,
      "Segment"             => Segment.count,
      "SegmentMembership"   => SegmentMembership.count,
      "Campaign"            => Campaign.count,
      "CampaignDelivery"    => CampaignDelivery.count,
      "DripCampaign"        => DripCampaign.count,
      "DripEnrollment"      => DripEnrollment.count,
      "DripStepExecution"   => DripStepExecution.count,
      "Message"             => Message.count,
      "Delivery"            => Delivery.count,
      "Open"                => Open.count,
      "Click"               => Click.count,
      "Conversation"        => Conversation.count,
      "ConversationMessage" => ConversationMessage.count,
      "SocialRegion"        => SocialRegion.count,
      "SocialPost"          => SocialPost.count,
      "SocialAlternative"   => SocialAlternative.count,
      "McpGrant"            => McpGrant.count,
      "McpRequestLog"       => McpRequestLog.count
    }
    summary.each { |k, v| puts format("  %-22s %d", k, v) }
    puts "=" * 60
    login = User.find_by(email: "maya@lumenlabs.io")
    puts "Demo login: #{login.email} (verified: #{login.email_verified}, role: #{login.role})"
    puts "Magic-link token generated: #{login.magic_link_token.present? ? 'yes' : 'no'} (valid: #{login.magic_link_token_valid?})"
    puts "=" * 60
  end
end
