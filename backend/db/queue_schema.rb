# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_07_08_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "plan", default: "trial", null: false
    t.datetime "trial_ends_at"
    t.string "payment_status"
    t.string "status", default: "pending_verification", null: false
    t.datetime "onboarding_completed_at"
    t.integer "onboarding_step", default: 0, null: false
    t.string "tracking_domain"
    t.boolean "chat_enabled", default: false
    t.integer "next_ticket_number", default: 1, null: false
    t.integer "message_retention_days", default: 180, null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.datetime "subscription_current_period_end"
    t.boolean "subscription_cancel_at_period_end", default: false, null: false
    t.index ["stripe_customer_id"], name: "index_accounts_on_stripe_customer_id", unique: true
    t.index ["stripe_subscription_id"], name: "index_accounts_on_stripe_subscription_id", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "campaign_deliveries", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "account_id", null: false
    t.bigint "customer_id"
    t.string "email", null: false
    t.string "status", default: "pending"
    t.string "tracking_token", null: false
    t.datetime "sent_at"
    t.datetime "opened_at"
    t.integer "open_count", default: 0
    t.integer "click_count", default: 0
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "channel", default: "email"
    t.index ["account_id"], name: "index_campaign_deliveries_on_account_id"
    t.index ["campaign_id", "status"], name: "index_campaign_deliveries_on_campaign_id_and_status"
    t.index ["campaign_id"], name: "index_campaign_deliveries_on_campaign_id"
    t.index ["customer_id"], name: "index_campaign_deliveries_on_customer_id"
    t.index ["tracking_token"], name: "index_campaign_deliveries_on_tracking_token", unique: true
  end

  create_table "campaigns", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "segment_id"
    t.string "name", null: false
    t.string "subject"
    t.string "from_email"
    t.text "content"
    t.string "status", default: "draft"
    t.integer "recipient_count", default: 0
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "channel", default: "email", null: false
    t.bigint "template_id"
    t.bigint "environment_id"
    t.bigint "sending_identity_id"
    t.index ["account_id", "status"], name: "index_campaigns_on_account_id_and_status"
    t.index ["account_id"], name: "index_campaigns_on_account_id"
    t.index ["environment_id"], name: "index_campaigns_on_environment_id"
    t.index ["segment_id"], name: "index_campaigns_on_segment_id"
    t.index ["sending_identity_id"], name: "index_campaigns_on_sending_identity_id"
    t.index ["template_id"], name: "index_campaigns_on_template_id"
  end

  create_table "canned_responses", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "shortcut", null: false
    t.string "title", null: false
    t.text "content", null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "shortcut"], name: "index_canned_responses_on_account_id_and_shortcut", unique: true
    t.index ["account_id"], name: "index_canned_responses_on_account_id"
    t.index ["created_by_id"], name: "index_canned_responses_on_created_by_id"
  end

  create_table "chat_widget_settings", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "enabled", default: true, null: false
    t.string "primary_color", default: "#3B86E4"
    t.string "secondary_color", default: "#ffffff"
    t.string "text_color", default: "#ffffff"
    t.string "position", default: "bottom-right"
    t.text "greeting_message", default: "Hi there! How can we help?"
    t.text "offline_message", default: "We are currently offline. Leave a message and we'll get back to you."
    t.boolean "require_email_before_chat", default: false
    t.boolean "show_operator_avatars", default: true
    t.boolean "show_operator_count", default: true
    t.boolean "business_hours_enabled", default: false
    t.jsonb "business_hours", default: {}
    t.string "timezone", default: "UTC"
    t.integer "auto_close_hours", default: 24
    t.jsonb "welcome_triggers", default: []
    t.jsonb "allowed_domains", default: ["*"]
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "widget_key"
    t.string "title", default: "Chat with us"
    t.string "button_color", default: "#1e1e1e"
    t.string "button_text_color", default: "#ffffff"
    t.string "header_color"
    t.string "send_button_color"
    t.string "send_button_text_color"
    t.string "header_text_color"
    t.string "identity_verification_secret"
    t.index ["account_id"], name: "index_chat_widget_settings_on_account_id", unique: true
    t.index ["widget_key"], name: "index_chat_widget_settings_on_widget_key", unique: true
  end

  create_table "clicks", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "account_id", null: false
    t.text "url", null: false
    t.datetime "clicked_at", null: false
    t.string "ip_address"
    t.text "user_agent"
    t.string "referer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_clicks_on_account_id"
    t.index ["clicked_at"], name: "index_clicks_on_clicked_at"
    t.index ["message_id", "clicked_at"], name: "index_clicks_on_message_id_and_clicked_at"
    t.index ["message_id"], name: "index_clicks_on_message_id"
  end

  create_table "conversation_assignments", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "assigned_by_id"
    t.bigint "assigned_to_id", null: false
    t.datetime "created_at", null: false
    t.index ["assigned_by_id"], name: "index_conversation_assignments_on_assigned_by_id"
    t.index ["assigned_to_id"], name: "index_conversation_assignments_on_assigned_to_id"
    t.index ["conversation_id", "created_at"], name: "idx_on_conversation_id_created_at_d0b54980e6"
    t.index ["conversation_id"], name: "index_conversation_assignments_on_conversation_id"
  end

  create_table "conversation_messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "account_id", null: false
    t.string "sender_type", null: false
    t.bigint "sender_id"
    t.integer "message_type", default: 0, null: false
    t.text "content"
    t.boolean "private", default: false, null: false
    t.jsonb "metadata", default: {}
    t.boolean "read_by_visitor", default: false
    t.boolean "read_by_operator", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_conversation_messages_on_account_id"
    t.index ["conversation_id", "created_at"], name: "index_conversation_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_conversation_messages_on_conversation_id"
    t.index ["sender_type", "sender_id"], name: "index_conversation_messages_on_sender_type_and_sender_id"
  end

  create_table "conversation_read_cursors", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "reader_type", null: false
    t.bigint "reader_id"
    t.bigint "last_read_message_id"
    t.datetime "last_read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "reader_type", "reader_id"], name: "idx_conv_read_cursors_unique", unique: true
    t.index ["conversation_id"], name: "index_conversation_read_cursors_on_conversation_id"
    t.index ["last_read_message_id"], name: "index_conversation_read_cursors_on_last_read_message_id"
  end

  create_table "conversation_taggings", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "conversation_tag_id", null: false
    t.datetime "created_at", null: false
    t.index ["conversation_id", "conversation_tag_id"], name: "idx_conv_taggings_unique", unique: true
    t.index ["conversation_id"], name: "index_conversation_taggings_on_conversation_id"
    t.index ["conversation_tag_id"], name: "index_conversation_taggings_on_conversation_tag_id"
  end

  create_table "conversation_tags", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.boolean "is_quick_reply", default: false
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_conversation_tags_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_conversation_tags_on_account_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "environment_id", null: false
    t.bigint "customer_id"
    t.string "visitor_token", null: false
    t.string "visitor_name"
    t.string "visitor_email"
    t.bigint "assigned_user_id"
    t.integer "status", default: 0, null: false
    t.integer "priority", default: 0
    t.string "subject"
    t.integer "source", default: 0
    t.datetime "last_message_at"
    t.string "last_message_preview"
    t.datetime "last_operator_reply_at"
    t.datetime "visitor_last_seen_at"
    t.datetime "snoozed_until"
    t.datetime "first_response_at"
    t.datetime "resolved_at"
    t.integer "rating"
    t.text "rating_comment"
    t.string "visitor_page_url"
    t.string "visitor_page_title"
    t.text "visitor_user_agent"
    t.string "visitor_ip"
    t.string "visitor_country"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ticket_number"
    t.index ["account_id", "assigned_user_id", "status"], name: "idx_on_account_id_assigned_user_id_status_86c77f1854"
    t.index ["account_id", "last_message_at"], name: "index_conversations_on_account_id_and_last_message_at", order: { last_message_at: :desc }
    t.index ["account_id", "source"], name: "index_conversations_on_account_id_and_source"
    t.index ["account_id", "status"], name: "index_conversations_on_account_id_and_status"
    t.index ["account_id", "ticket_number"], name: "index_conversations_on_account_id_and_ticket_number", unique: true, where: "(ticket_number IS NOT NULL)"
    t.index ["account_id"], name: "index_conversations_on_account_id"
    t.index ["assigned_user_id"], name: "index_conversations_on_assigned_user_id"
    t.index ["customer_id"], name: "index_conversations_on_customer_id"
    t.index ["environment_id"], name: "index_conversations_on_environment_id"
    t.index ["snoozed_until"], name: "index_conversations_on_snoozed_until", where: "(snoozed_until IS NOT NULL)"
    t.index ["visitor_token", "account_id"], name: "index_conversations_on_visitor_token_and_account_id"
  end

  create_table "csv_imports", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.text "csv_content"
    t.jsonb "field_mapping", default: {}
    t.string "dedup_strategy", default: "skip"
    t.string "status", default: "pending"
    t.integer "total_rows", default: 0
    t.integer "processed_rows", default: 0
    t.integer "success_count", default: 0
    t.integer "failed_count", default: 0
    t.jsonb "row_errors", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_csv_imports_on_account_id_and_status"
    t.index ["account_id"], name: "index_csv_imports_on_account_id"
    t.index ["user_id"], name: "index_csv_imports_on_user_id"
  end

  create_table "customer_activities", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "environment_id"
    t.string "activity_type", default: "identify", null: false
    t.jsonb "properties", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_customer_activities_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_customer_activities_on_account_id"
    t.index ["customer_id"], name: "index_customer_activities_on_customer_id"
    t.index ["environment_id"], name: "index_customer_activities_on_environment_id"
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.jsonb "custom_attributes", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_seen_at"
    t.jsonb "unsubscribed_channels", default: {}
    t.integer "email_score"
    t.datetime "email_score_checked_at"
    t.datetime "last_engaged_at"
    t.string "anonymous_token"
    t.string "phone"
    t.string "browser"
    t.string "os"
    t.string "country"
    t.string "city"
    t.string "current_page_url"
    t.string "current_page_title"
    t.boolean "online", default: false
    t.jsonb "unsubscribed_categories", default: {}
    t.index ["account_id", "anonymous_token"], name: "idx_customers_anonymous_token_unique", unique: true, where: "(anonymous_token IS NOT NULL)"
    t.index ["account_id", "email"], name: "index_customers_on_account_id_and_email", unique: true
    t.index ["account_id"], name: "index_customers_on_account_id"
    t.index ["email"], name: "index_customers_on_email"
  end

  create_table "deliveries", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "integration_id", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recipient"
    t.bigint "account_id", null: false
    t.string "provider_message_id"
    t.string "status"
    t.index ["account_id"], name: "index_deliveries_on_account_id"
    t.index ["integration_id"], name: "index_deliveries_on_integration_id"
    t.index ["message_id"], name: "index_deliveries_on_message_id"
    t.index ["provider_message_id"], name: "index_deliveries_on_provider_message_id", unique: true, where: "(provider_message_id IS NOT NULL)"
  end

  create_table "device_tokens", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "customer_id", null: false
    t.string "token", null: false
    t.integer "platform", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "device_id"
    t.string "app_id"
    t.string "device_name"
    t.datetime "last_used_at"
    t.index ["account_id", "app_id"], name: "index_device_tokens_on_account_id_and_app_id", where: "(app_id IS NOT NULL)"
    t.index ["account_id", "device_id"], name: "index_device_tokens_on_account_id_and_device_id", where: "(device_id IS NOT NULL)"
    t.index ["account_id"], name: "index_device_tokens_on_account_id"
    t.index ["customer_id", "active"], name: "index_device_tokens_on_customer_id_and_active"
    t.index ["customer_id"], name: "index_device_tokens_on_customer_id"
    t.index ["token"], name: "index_device_tokens_on_token", unique: true
  end

  create_table "drip_campaigns", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "environment_id"
    t.bigint "segment_id", null: false
    t.string "name", null: false
    t.string "status", default: "draft", null: false
    t.boolean "allow_reentry", default: false, null: false
    t.boolean "exit_on_segment_leave", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "enroll_existing_on_start", default: true, null: false
    t.bigint "sending_identity_id"
    t.index ["account_id", "status"], name: "index_drip_campaigns_on_account_id_and_status"
    t.index ["environment_id"], name: "index_drip_campaigns_on_environment_id"
    t.index ["segment_id"], name: "index_drip_campaigns_on_segment_id"
    t.index ["sending_identity_id"], name: "index_drip_campaigns_on_sending_identity_id"
  end

  create_table "drip_enrollments", force: :cascade do |t|
    t.bigint "drip_campaign_id", null: false
    t.bigint "account_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "segment_membership_id"
    t.string "status", default: "active", null: false
    t.integer "current_position", default: 0, null: false
    t.datetime "anchor_at"
    t.datetime "next_run_at"
    t.datetime "entered_at"
    t.datetime "completed_at"
    t.datetime "exited_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_drip_enrollments_on_account_id_and_status"
    t.index ["customer_id"], name: "index_drip_enrollments_on_customer_id"
    t.index ["drip_campaign_id", "customer_id"], name: "index_drip_enrollments_on_drip_campaign_id_and_customer_id"
    t.index ["next_run_at"], name: "index_drip_enrollments_on_next_run_at"
    t.index ["segment_membership_id"], name: "index_drip_enrollments_on_segment_membership_id"
  end

  create_table "drip_step_executions", force: :cascade do |t|
    t.bigint "drip_enrollment_id", null: false
    t.bigint "drip_step_id", null: false
    t.bigint "account_id", null: false
    t.bigint "message_id"
    t.string "status", null: false
    t.string "skip_reason"
    t.datetime "scheduled_for"
    t.datetime "evaluated_at"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_drip_step_executions_on_account_id"
    t.index ["drip_enrollment_id", "drip_step_id"], name: "index_drip_step_executions_on_enrollment_and_step", unique: true
    t.index ["drip_enrollment_id"], name: "index_drip_step_executions_on_drip_enrollment_id"
    t.index ["drip_step_id"], name: "index_drip_step_executions_on_drip_step_id"
    t.index ["message_id"], name: "index_drip_step_executions_on_message_id"
  end

  create_table "drip_steps", force: :cascade do |t|
    t.bigint "drip_campaign_id", null: false
    t.bigint "account_id", null: false
    t.bigint "template_id"
    t.integer "position", null: false
    t.string "channel", default: "email", null: false
    t.integer "delay_days", default: 0, null: false
    t.jsonb "conditions", default: {}
    t.string "on_fail", default: "skip", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_drip_steps_on_account_id"
    t.index ["drip_campaign_id", "position"], name: "index_drip_steps_on_drip_campaign_id_and_position", unique: true
    t.index ["template_id"], name: "index_drip_steps_on_template_id"
  end

  create_table "email_message_details", force: :cascade do |t|
    t.bigint "conversation_message_id", null: false
    t.string "message_id_header"
    t.string "in_reply_to_header"
    t.string "from_email"
    t.string "from_name"
    t.string "to_email"
    t.jsonb "cc_list", default: []
    t.jsonb "bcc_list", default: []
    t.text "html_body"
    t.text "text_body"
    t.jsonb "raw_headers", default: {}
    t.string "provider_uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_message_id"], name: "index_email_message_details_on_conversation_message_id", unique: true
    t.index ["message_id_header"], name: "index_email_message_details_on_message_id_header"
    t.index ["provider_uid"], name: "index_email_message_details_on_provider_uid"
  end

  create_table "email_threads", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "mailbox_id", null: false
    t.bigint "conversation_id", null: false
    t.string "ticket_number", null: false
    t.string "from_email", null: false
    t.string "from_name"
    t.string "subject"
    t.string "in_reply_to"
    t.text "references_header"
    t.jsonb "cc_list", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "ticket_number"], name: "index_email_threads_on_account_id_and_ticket_number", unique: true
    t.index ["account_id"], name: "index_email_threads_on_account_id"
    t.index ["conversation_id"], name: "index_email_threads_on_conversation_id", unique: true
    t.index ["in_reply_to"], name: "index_email_threads_on_in_reply_to"
    t.index ["mailbox_id"], name: "index_email_threads_on_mailbox_id"
  end

  create_table "environments", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name"
    t.string "api_key", null: false
    t.boolean "allow_email", default: false, null: false
    t.boolean "allow_sms", default: false, null: false
    t.boolean "allow_whatsapp", default: false, null: false
    t.boolean "allow_mobile_push", default: false, null: false
    t.boolean "allow_web_push", default: false, null: false
    t.boolean "is_deleted", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "tag"
    t.string "whatsapp_phone_id"
    t.string "whatsapp_token"
    t.bigint "notification_email_integration_id"
    t.bigint "campaign_email_integration_id"
    t.index ["account_id"], name: "index_environments_on_account_id"
    t.index ["api_key"], name: "index_environments_on_api_key", unique: true
    t.index ["campaign_email_integration_id"], name: "index_environments_on_campaign_email_integration_id"
    t.index ["notification_email_integration_id"], name: "index_environments_on_notification_email_integration_id"
  end

  create_table "folders", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "environment_id", null: false
    t.bigint "parent_folder_id"
    t.string "name", null: false
    t.boolean "is_deleted", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "environment_id"], name: "index_folders_on_account_id_and_environment_id"
    t.index ["account_id"], name: "index_folders_on_account_id"
    t.index ["environment_id"], name: "index_folders_on_environment_id"
    t.index ["parent_folder_id"], name: "index_folders_on_parent_folder_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "type"
    t.string "vendor"
    t.integer "kind", default: 0, null: false
    t.jsonb "config", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "environment_id"
    t.boolean "active", default: true, null: false
    t.index ["account_id", "kind", "active"], name: "index_integrations_on_account_id_and_kind_and_active"
    t.index ["account_id"], name: "index_integrations_on_account_id"
    t.index ["environment_id"], name: "index_integrations_on_environment_id"
  end

  create_table "layouts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "environment_id", null: false
    t.string "name", null: false
    t.text "body", null: false
    t.boolean "is_deleted", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "transformers", default: {}
    t.index ["account_id"], name: "index_layouts_on_account_id"
    t.index ["environment_id", "name"], name: "index_layouts_on_environment_id_and_name", unique: true
    t.index ["environment_id"], name: "index_layouts_on_environment_id"
  end

  create_table "mailboxes", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "environment_id", null: false
    t.string "name", null: false
    t.string "email_address", null: false
    t.integer "provider", default: 0, null: false
    t.jsonb "config", default: {}
    t.boolean "active", default: true, null: false
    t.datetime "last_synced_at"
    t.jsonb "sync_state", default: {}
    t.string "ticket_prefix", default: ""
    t.integer "next_ticket_number", default: 1001, null: false
    t.boolean "auto_assign", default: true, null: false
    t.boolean "auto_reply_enabled", default: true, null: false
    t.text "auto_reply_template"
    t.integer "auto_close_days"
    t.jsonb "notification_events", default: {"ticket_closed" => true, "ticket_created" => true, "ticket_assigned" => true, "ticket_reopened" => true, "ticket_note_added" => false, "ticket_reply_from_operator" => true}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email_address"], name: "index_mailboxes_on_account_id_and_email_address", unique: true
    t.index ["account_id"], name: "index_mailboxes_on_account_id"
    t.index ["environment_id"], name: "index_mailboxes_on_environment_id"
  end

  create_table "mcp_authorization_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.bigint "mcp_grant_id", null: false
    t.string "redirect_uri", null: false
    t.string "code_challenge", null: false
    t.string "code_challenge_method", default: "S256", null: false
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code_digest"], name: "index_mcp_authorization_codes_on_code_digest", unique: true
    t.index ["mcp_grant_id"], name: "index_mcp_authorization_codes_on_mcp_grant_id"
  end

  create_table "mcp_clients", force: :cascade do |t|
    t.string "client_id", null: false
    t.string "client_secret_digest"
    t.string "name"
    t.jsonb "redirect_uris", default: [], null: false
    t.jsonb "grant_types", default: ["authorization_code", "refresh_token"], null: false
    t.string "token_endpoint_auth_method", default: "none", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_mcp_clients_on_client_id", unique: true
  end

  create_table "mcp_grants", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.bigint "environment_id", null: false
    t.bigint "mcp_client_id", null: false
    t.jsonb "scopes", default: [], null: false
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_mcp_grants_on_account_id"
    t.index ["user_id", "mcp_client_id", "environment_id"], name: "idx_on_user_id_mcp_client_id_environment_id_386d861aa2"
    t.index ["user_id"], name: "index_mcp_grants_on_user_id"
  end

  create_table "mcp_request_logs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "mcp_grant_id"
    t.bigint "user_id"
    t.bigint "environment_id"
    t.string "tool_name"
    t.string "jsonrpc_method"
    t.jsonb "arguments", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.integer "http_status"
    t.integer "duration_ms"
    t.string "error_message"
    t.datetime "created_at", null: false
    t.index ["account_id", "created_at"], name: "index_mcp_request_logs_on_account_id_and_created_at"
    t.index ["mcp_grant_id"], name: "index_mcp_request_logs_on_mcp_grant_id"
  end

  create_table "mcp_settings", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_mcp_settings_on_account_id", unique: true
  end

  create_table "mcp_tokens", force: :cascade do |t|
    t.bigint "mcp_grant_id", null: false
    t.integer "kind", default: 0, null: false
    t.string "token_digest", null: false
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mcp_grant_id", "kind"], name: "index_mcp_tokens_on_mcp_grant_id_and_kind"
    t.index ["token_digest"], name: "index_mcp_tokens_on_token_digest", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "environment_id", null: false
    t.bigint "template_id"
    t.string "type", null: false
    t.string "trigger"
    t.string "to", null: false
    t.string "cc"
    t.string "bcc"
    t.string "subject"
    t.text "body", null: false
    t.jsonb "tags", default: [], null: false
    t.integer "scope", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "sent_at"
    t.boolean "is_deleted", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "tracking_token"
    t.string "tracking_salt"
    t.integer "open_count", default: 0, null: false
    t.datetime "first_opened_at"
    t.bigint "parent_message_id"
    t.string "language"
    t.bigint "drip_campaign_id"
    t.bigint "drip_step_id"
    t.bigint "sending_identity_id"
    t.integer "click_count", default: 0, null: false
    t.datetime "first_clicked_at"
    t.index ["account_id", "created_at"], name: "index_messages_on_account_id_and_created_at", order: { created_at: :desc }
    t.index ["account_id"], name: "index_messages_on_account_id"
    t.index ["drip_campaign_id"], name: "index_messages_on_drip_campaign_id"
    t.index ["drip_step_id"], name: "index_messages_on_drip_step_id"
    t.index ["environment_id", "created_at"], name: "index_messages_on_environment_id_and_created_at", order: { created_at: :desc }
    t.index ["environment_id"], name: "index_messages_on_environment_id"
    t.index ["parent_message_id"], name: "index_messages_on_parent_message_id"
    t.index ["sending_identity_id"], name: "index_messages_on_sending_identity_id"
    t.index ["template_id"], name: "index_messages_on_template_id"
    t.index ["tracking_token"], name: "index_messages_on_tracking_token", unique: true
    t.index ["type"], name: "index_messages_on_type"
  end

  create_table "opens", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.datetime "opened_at", null: false
    t.string "ip_address"
    t.text "user_agent"
    t.string "referer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.index ["account_id"], name: "index_opens_on_account_id"
    t.index ["message_id", "opened_at"], name: "index_opens_on_message_id_and_opened_at"
    t.index ["message_id"], name: "index_opens_on_message_id"
    t.index ["opened_at"], name: "index_opens_on_opened_at"
  end

  create_table "operator_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "account_id", null: false
    t.string "public_name", null: false
    t.text "bio"
    t.integer "availability", default: 0, null: false
    t.boolean "auto_assign", default: true
    t.integer "max_concurrent_chats", default: 10
    t.datetime "last_heartbeat_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sort_order", default: 0, null: false
    t.index ["account_id", "availability"], name: "index_operator_profiles_on_account_id_and_availability"
    t.index ["account_id"], name: "index_operator_profiles_on_account_id"
    t.index ["user_id"], name: "index_operator_profiles_on_user_id", unique: true
  end

  create_table "page_visits", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "customer_id"
    t.string "visitor_token", null: false
    t.string "url", null: false
    t.string "title"
    t.datetime "visited_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "visitor_token", "visited_at"], name: "idx_page_visits_token_time"
    t.index ["customer_id", "visited_at"], name: "index_page_visits_on_customer_id_and_visited_at"
  end

  create_table "rules", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "environment_id", null: false
    t.string "type", null: false
    t.string "condition", null: false
    t.jsonb "tags", default: [], null: false
    t.integer "scope", default: 0, null: false
    t.integer "outcome", default: 0, null: false
    t.boolean "is_deleted", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.string "name", default: "", null: false
    t.string "redirect_to"
    t.index ["account_id"], name: "index_rules_on_account_id"
    t.index ["environment_id"], name: "index_rules_on_environment_id"
    t.index ["type"], name: "index_rules_on_type"
  end

  create_table "segment_memberships", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "segment_id", null: false
    t.bigint "customer_id", null: false
    t.datetime "entered_at", null: false
    t.datetime "exited_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_segment_memberships_on_account_id"
    t.index ["customer_id"], name: "index_segment_memberships_on_customer_id"
    t.index ["segment_id", "customer_id", "exited_at"], name: "idx_on_segment_id_customer_id_exited_at_2e12a5cc34"
  end

  create_table "segments", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.text "description"
    t.jsonb "conditions", default: {"operator" => "and", "conditions" => []}
    t.integer "customer_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cleanup_status"
    t.integer "cleanup_progress", default: 0
    t.integer "cleanup_total", default: 0
    t.jsonb "cleanup_stats"
    t.datetime "cleanup_started_at"
    t.datetime "cleanup_completed_at"
    t.index ["account_id"], name: "index_segments_on_account_id"
  end

  create_table "sending_identities", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "from_name"
    t.string "from_email", null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_sending_identities_on_account_id"
    t.index ["account_id"], name: "index_sending_identities_one_default_per_account", unique: true, where: "is_default"
  end

  create_table "social_alternatives", force: :cascade do |t|
    t.bigint "social_post_id", null: false
    t.string "headline"
    t.text "body"
    t.string "cta_label"
    t.string "cta_url"
    t.integer "position", default: 0, null: false
    t.integer "source", default: 0, null: false
    t.string "meta_campaign_id"
    t.string "meta_adset_id"
    t.string "meta_ad_id"
    t.string "meta_creative_id"
    t.string "meta_form_id"
    t.string "meta_image_hash"
    t.decimal "meta_budget", precision: 10, scale: 2
    t.datetime "drafted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meta_ad_id"], name: "index_social_alternatives_on_meta_ad_id"
    t.index ["social_post_id"], name: "index_social_alternatives_on_social_post_id"
  end

  create_table "social_channels", force: :cascade do |t|
    t.bigint "social_region_id", null: false
    t.bigint "integration_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_id"], name: "index_social_channels_on_integration_id"
    t.index ["social_region_id", "integration_id"], name: "index_social_channels_on_social_region_id_and_integration_id", unique: true
    t.index ["social_region_id"], name: "index_social_channels_on_social_region_id"
  end

  create_table "social_post_deliveries", force: :cascade do |t|
    t.bigint "social_post_id", null: false
    t.bigint "integration_id", null: false
    t.bigint "account_id", null: false
    t.integer "slot", null: false
    t.integer "channel", null: false
    t.integer "status", default: 0, null: false
    t.string "provider_post_id"
    t.text "error_message"
    t.datetime "posted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_social_post_deliveries_on_account_id_and_status"
    t.index ["account_id"], name: "index_social_post_deliveries_on_account_id"
    t.index ["integration_id"], name: "index_social_post_deliveries_on_integration_id"
    t.index ["social_post_id", "integration_id", "slot", "channel"], name: "idx_social_deliveries_target"
    t.index ["social_post_id"], name: "index_social_post_deliveries_on_social_post_id"
  end

  create_table "social_posts", force: :cascade do |t|
    t.bigint "social_region_id", null: false
    t.date "post_date", null: false
    t.integer "status", default: 0, null: false
    t.bigint "feed_alternative_id"
    t.bigint "reel_alternative_id"
    t.text "publish_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "post_hour"
    t.bigint "carousel_alternative_id"
    t.index ["carousel_alternative_id"], name: "index_social_posts_on_carousel_alternative_id"
    t.index ["feed_alternative_id"], name: "index_social_posts_on_feed_alternative_id"
    t.index ["reel_alternative_id"], name: "index_social_posts_on_reel_alternative_id"
    t.index ["social_region_id", "post_date"], name: "index_social_posts_on_social_region_id_and_post_date", unique: true
    t.index ["social_region_id"], name: "index_social_posts_on_social_region_id"
  end

  create_table "social_regions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "environment_id"
    t.string "name", null: false
    t.string "timezone", default: "UTC", null: false
    t.integer "post_hour", default: 9, null: false
    t.jsonb "countries", default: [], null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "integration_id"
    t.string "page_id"
    t.string "page_name"
    t.string "ig_business_account_id"
    t.string "ig_username"
    t.string "ad_account_id"
    t.boolean "post_to_facebook", default: true, null: false
    t.boolean "post_to_instagram", default: true, null: false
    t.jsonb "hashtags", default: [], null: false
    t.bigint "linkedin_integration_id"
    t.string "linkedin_org_id"
    t.string "linkedin_org_name"
    t.boolean "post_to_linkedin", default: true, null: false
    t.string "ig_page_id"
    t.index ["account_id", "name"], name: "index_social_regions_on_account_id_and_name"
    t.index ["account_id"], name: "index_social_regions_on_account_id"
    t.index ["environment_id"], name: "index_social_regions_on_environment_id"
    t.index ["integration_id"], name: "index_social_regions_on_integration_id"
    t.index ["linkedin_integration_id"], name: "index_social_regions_on_linkedin_integration_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "templates", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "environment_id", null: false
    t.string "name", null: false
    t.string "trigger"
    t.string "subject"
    t.text "body", null: false
    t.boolean "is_deleted", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "folder_id"
    t.bigint "layout_id"
    t.string "preview"
    t.string "channel", default: "email", null: false
    t.string "body_format", default: "html", null: false
    t.index ["account_id"], name: "index_templates_on_account_id"
    t.index ["environment_id", "trigger", "channel"], name: "index_templates_on_env_trigger_channel", unique: true
    t.index ["folder_id"], name: "index_templates_on_folder_id"
    t.index ["layout_id"], name: "index_templates_on_layout_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "magic_link_token"
    t.datetime "magic_link_token_expires_at"
    t.boolean "is_super_admin", default: false, null: false
    t.boolean "email_verified", default: false, null: false
    t.integer "role", default: 0, null: false
    t.boolean "mcp_enabled", default: true, null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["magic_link_token"], name: "index_users_on_magic_link_token"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "campaign_deliveries", "accounts"
  add_foreign_key "campaign_deliveries", "campaigns"
  add_foreign_key "campaign_deliveries", "customers"
  add_foreign_key "campaigns", "accounts"
  add_foreign_key "campaigns", "environments"
  add_foreign_key "campaigns", "segments"
  add_foreign_key "campaigns", "templates"
  add_foreign_key "canned_responses", "accounts"
  add_foreign_key "canned_responses", "users", column: "created_by_id"
  add_foreign_key "chat_widget_settings", "accounts"
  add_foreign_key "clicks", "accounts"
  add_foreign_key "clicks", "messages"
  add_foreign_key "conversation_assignments", "conversations"
  add_foreign_key "conversation_assignments", "users", column: "assigned_by_id"
  add_foreign_key "conversation_assignments", "users", column: "assigned_to_id"
  add_foreign_key "conversation_messages", "accounts"
  add_foreign_key "conversation_messages", "conversations"
  add_foreign_key "conversation_read_cursors", "conversation_messages", column: "last_read_message_id"
  add_foreign_key "conversation_read_cursors", "conversations"
  add_foreign_key "conversation_taggings", "conversation_tags"
  add_foreign_key "conversation_taggings", "conversations"
  add_foreign_key "conversation_tags", "accounts"
  add_foreign_key "conversations", "accounts"
  add_foreign_key "conversations", "customers"
  add_foreign_key "conversations", "environments"
  add_foreign_key "conversations", "users", column: "assigned_user_id"
  add_foreign_key "csv_imports", "accounts"
  add_foreign_key "csv_imports", "users"
  add_foreign_key "customer_activities", "accounts"
  add_foreign_key "customer_activities", "customers"
  add_foreign_key "customer_activities", "environments"
  add_foreign_key "customers", "accounts"
  add_foreign_key "deliveries", "accounts"
  add_foreign_key "deliveries", "integrations"
  add_foreign_key "deliveries", "messages"
  add_foreign_key "device_tokens", "accounts"
  add_foreign_key "device_tokens", "customers"
  add_foreign_key "email_message_details", "conversation_messages"
  add_foreign_key "email_threads", "accounts"
  add_foreign_key "email_threads", "conversations"
  add_foreign_key "email_threads", "mailboxes"
  add_foreign_key "environments", "accounts"
  add_foreign_key "environments", "integrations", column: "campaign_email_integration_id"
  add_foreign_key "environments", "integrations", column: "notification_email_integration_id"
  add_foreign_key "folders", "accounts"
  add_foreign_key "folders", "environments"
  add_foreign_key "folders", "folders", column: "parent_folder_id"
  add_foreign_key "integrations", "accounts"
  add_foreign_key "integrations", "environments"
  add_foreign_key "layouts", "accounts"
  add_foreign_key "layouts", "environments"
  add_foreign_key "mailboxes", "accounts"
  add_foreign_key "mailboxes", "environments"
  add_foreign_key "mcp_authorization_codes", "mcp_grants", on_delete: :cascade
  add_foreign_key "mcp_grants", "accounts", on_delete: :cascade
  add_foreign_key "mcp_grants", "environments", on_delete: :cascade
  add_foreign_key "mcp_grants", "mcp_clients", on_delete: :cascade
  add_foreign_key "mcp_grants", "users", on_delete: :cascade
  add_foreign_key "mcp_request_logs", "accounts", on_delete: :cascade
  add_foreign_key "mcp_request_logs", "mcp_grants", on_delete: :nullify
  add_foreign_key "mcp_settings", "accounts", on_delete: :cascade
  add_foreign_key "mcp_tokens", "mcp_grants", on_delete: :cascade
  add_foreign_key "messages", "accounts"
  add_foreign_key "messages", "environments"
  add_foreign_key "messages", "messages", column: "parent_message_id"
  add_foreign_key "messages", "templates"
  add_foreign_key "opens", "accounts"
  add_foreign_key "opens", "messages"
  add_foreign_key "operator_profiles", "accounts"
  add_foreign_key "operator_profiles", "users"
  add_foreign_key "page_visits", "accounts"
  add_foreign_key "page_visits", "customers"
  add_foreign_key "rules", "accounts"
  add_foreign_key "rules", "environments"
  add_foreign_key "segments", "accounts"
  add_foreign_key "social_alternatives", "social_posts"
  add_foreign_key "social_channels", "integrations"
  add_foreign_key "social_channels", "social_regions"
  add_foreign_key "social_post_deliveries", "accounts"
  add_foreign_key "social_post_deliveries", "integrations"
  add_foreign_key "social_post_deliveries", "social_posts"
  add_foreign_key "social_posts", "social_alternatives", column: "carousel_alternative_id", on_delete: :nullify
  add_foreign_key "social_posts", "social_alternatives", column: "feed_alternative_id", on_delete: :nullify
  add_foreign_key "social_posts", "social_alternatives", column: "reel_alternative_id", on_delete: :nullify
  add_foreign_key "social_posts", "social_regions"
  add_foreign_key "social_regions", "accounts"
  add_foreign_key "social_regions", "environments"
  add_foreign_key "social_regions", "integrations"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "templates", "accounts"
  add_foreign_key "templates", "environments"
  add_foreign_key "templates", "folders"
  add_foreign_key "templates", "layouts"
  add_foreign_key "users", "accounts"
end
