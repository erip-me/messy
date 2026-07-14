# ─── Example Templates ────────────────────────────────────────────────────────

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

Template.create!(
  account: acc, environment: tst,
  name: 'Magic Link Login',
  trigger: 'magic_link',
  subject: 'Your sign-in link for {{company}}',
  body: magic_link_body
)

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

Template.create!(
  account: acc, environment: tst,
  name: 'Welcome Email',
  trigger: 'user_welcome',
  subject: 'Welcome to {{company}}, {{name}}!',
  body: welcome_body
)

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

Template.create!(
  account: acc, environment: tst,
  name: 'Order Confirmation',
  trigger: 'order_confirmed',
  subject: 'Order {{order_number}} confirmed ✓',
  body: order_body
)

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

Template.create!(
  account: acc, environment: tst,
  name: 'Invoice',
  trigger: 'invoice_issued',
  subject: 'Invoice {{invoice_number}} from {{company}}',
  body: invoice_body
)

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

Template.create!(
  account: acc, environment: tst,
  name: 'Appointment Reminder',
  trigger: 'appointment_reminder',
  subject: 'Reminder: {{event_title}} on {{event_date}}',
  body: reminder_body
)

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

Template.create!(
  account: acc, environment: tst,
  name: 'Security Alert',
  trigger: 'security_alert',
  subject: 'New sign-in detected on your {{company}} account',
  body: alert_body
)
