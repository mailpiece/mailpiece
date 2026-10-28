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

ActiveRecord::Schema[8.2].define(version: 2026_10_28_100000) do
  create_table "account_cancellations", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "initiated_by_id", null: false
    t.datetime "created_at", null: false
    t.index ["account_id"], name: "index_account_cancellations_on_account_id", unique: true
  end

  create_table "account_external_id_sequences", id: :uuid, force: :cascade do |t|
    t.bigint "value", default: 0, null: false
    t.index ["value"], name: "index_account_external_id_sequences_on_value", unique: true
  end

  create_table "account_join_codes", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "code", limit: 255, null: false
    t.bigint "usage_count", default: 0, null: false
    t.bigint "usage_limit", default: 10, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "code"], name: "index_account_join_codes_on_account_id_and_code", unique: true
  end

  create_table "account_senders", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "from_name", limit: 255
    t.string "from_address", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reply_to_address", limit: 255
    t.string "transport", limit: 255
    t.string "relay_url", limit: 255
    t.text "relay_token", limit: 65535
    t.string "smtp_address", limit: 255
    t.integer "smtp_port"
    t.string "smtp_username", limit: 255
    t.text "smtp_password", limit: 65535
    t.index ["account_id"], name: "index_account_senders_on_account_id", unique: true
  end

  create_table "account_welcomes", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.index ["account_id"], name: "index_account_welcomes_on_account_id", unique: true
  end

  create_table "accounts", id: :uuid, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.bigint "external_account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "subscription_return_url", limit: 255
    t.string "handle", limit: 255
    t.string "locale", limit: 255
    t.string "domain", limit: 255
    t.index ["domain"], name: "index_accounts_on_domain", unique: true
    t.index ["external_account_id"], name: "index_accounts_on_external_account_id", unique: true
    t.index ["handle"], name: "index_accounts_on_handle", unique: true
  end

  create_table "action_pack_passkeys", id: :uuid, force: :cascade do |t|
    t.uuid "holder_id", null: false
    t.string "holder_type", limit: 255, null: false
    t.string "credential_id", limit: 255, null: false
    t.binary "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.string "name", limit: 255
    t.text "transports", limit: 65535
    t.string "aaguid", limit: 255
    t.boolean "backed_up"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credential_id"], name: "index_action_pack_passkeys_on_credential_id", unique: true
    t.index ["holder_type", "holder_id"], name: "index_action_pack_passkeys_on_holder_type_and_holder_id"
  end

  create_table "action_text_rich_texts", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "name", limit: 255, null: false
    t.text "body", limit: 4294967295
    t.uuid "record_id", null: false
    t.string "record_type", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_action_text_rich_texts_on_account_id"
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "record_type", limit: 255, null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.uuid "account_id", null: false
    t.index ["account_id"], name: "index_active_storage_attachments_on_account_id"
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, force: :cascade do |t|
    t.string "key", limit: 255, null: false
    t.string "filename", limit: 255, null: false
    t.string "content_type", limit: 255
    t.text "metadata", limit: 65535
    t.string "service_name", limit: 255, null: false
    t.bigint "byte_size", null: false
    t.string "checksum", limit: 255
    t.datetime "created_at", null: false
    t.uuid "account_id", null: false
    t.index ["account_id"], name: "index_active_storage_blobs_on_account_id"
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", limit: 255, null: false
    t.uuid "account_id", null: false
    t.index ["account_id"], name: "index_active_storage_variant_records_on_account_id"
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "identities", id: :uuid, force: :cascade do |t|
    t.text "email_address", limit: 255, null: false
    t.boolean "staff", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_identities_on_email_address", unique: true
  end

  create_table "identity_access_tokens", id: :uuid, force: :cascade do |t|
    t.uuid "identity_id", null: false
    t.string "token_digest", limit: 255, null: false
    t.string "permission", limit: 255
    t.text "description", limit: 65535
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identity_id"], name: "index_identity_access_tokens_on_identity_id"
    t.index ["token_digest"], name: "index_identity_access_tokens_on_token_digest", unique: true
  end

  create_table "journey_deliveries", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "email_id", null: false
    t.uuid "subscriber_id", null: false
    t.datetime "deliver_at"
    t.datetime "claimed_at"
    t.datetime "sent_at"
    t.datetime "refused_at"
    t.string "message_id", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_id", "subscriber_id"], name: "index_journey_deliveries_on_email_id_and_subscriber_id", unique: true
    t.index ["sent_at", "refused_at", "claimed_at", "deliver_at"], name: "index_journey_deliveries_on_pending"
    t.index ["subscriber_id"], name: "index_journey_deliveries_on_subscriber_id"
  end

  create_table "journey_emails", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "trigger", limit: 255, null: false
    t.string "subject", limit: 255
    t.string "summary", limit: 300
    t.integer "delay_days", default: 0, null: false
    t.integer "send_hour"
    t.string "time_zone", limit: 255
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "trigger", "delay_days"], name: "index_journey_emails_on_account_id_and_trigger_and_delay_days"
  end

  create_table "journey_runs", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "subscriber_id", null: false
    t.string "trigger", limit: 255, null: false
    t.string "state", limit: 255, default: "in_progress", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "trigger", "state"], name: "index_journey_runs_on_account_id_and_trigger_and_state"
    t.index ["subscriber_id", "trigger"], name: "index_journey_runs_on_subscriber_id_and_trigger", unique: true
  end

  create_table "magic_links", id: :uuid, force: :cascade do |t|
    t.uuid "identity_id"
    t.string "code", limit: 255, null: false
    t.integer "purpose", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_magic_links_on_code", unique: true
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
    t.index ["identity_id"], name: "index_magic_links_on_identity_id"
  end

  create_table "post_deliveries", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "post_id", null: false
    t.uuid "subscriber_id", null: false
    t.datetime "deliver_at"
    t.datetime "sent_at"
    t.datetime "refused_at"
    t.string "message_id", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "claimed_at"
    t.index ["post_id", "subscriber_id"], name: "index_post_deliveries_on_post_id_and_subscriber_id", unique: true
    t.index ["sent_at", "refused_at", "claimed_at", "deliver_at"], name: "index_post_deliveries_on_pending"
    t.index ["subscriber_id"], name: "index_post_deliveries_on_subscriber_id"
  end

  create_table "post_links", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "post_id", null: false
    t.string "code", limit: 8, null: false
    t.text "original_url", limit: 65535, null: false
    t.text "url", limit: 65535, null: false
    t.string "text", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "code"], name: "index_post_links_on_account_id_and_code", unique: true
    t.index ["post_id", "original_url"], name: "index_post_links_on_post_id_and_original_url", unique: true
  end

  create_table "post_revisions", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "post_id", null: false
    t.uuid "creator_id", null: false
    t.string "title", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "created_at"], name: "index_post_revisions_on_post_id_and_created_at"
  end

  create_table "posts", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "creator_id", null: false
    t.string "title", limit: 255
    t.datetime "published_at"
    t.datetime "sent_at"
    t.datetime "scheduled_posting_at"
    t.boolean "scheduled_delivery", default: false, null: false
    t.integer "deliveries_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", limit: 255, default: "listed", null: false
    t.string "code", limit: 8, null: false
    t.string "summary", limit: 300
    t.datetime "dated_at"
    t.index ["account_id", "code"], name: "index_posts_on_account_id_and_code", unique: true
    t.index ["account_id", "dated_at"], name: "index_posts_on_account_id_and_dated_at"
    t.index ["account_id", "published_at"], name: "index_posts_on_account_id_and_published_at"
    t.index ["scheduled_posting_at"], name: "index_posts_on_scheduled_posting_at"
  end

  create_table "search_records", force: :cascade do |t|
    t.string "searchable_type", limit: 255, null: false
    t.uuid "searchable_id", null: false
    t.uuid "account_id", null: false
    t.index ["account_id"], name: "index_search_records_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "sessions", id: :uuid, force: :cascade do |t|
    t.uuid "identity_id", null: false
    t.string "ip_address", limit: 255
    t.string "user_agent", limit: 4096
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identity_id"], name: "index_sessions_on_identity_id"
  end

  create_table "snippets", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "name", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_snippets_on_account_id"
  end

  create_table "subscriber_imports", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "creator_id", null: false
    t.string "status", limit: 255, default: "pending", null: false
    t.string "failure_reason", limit: 255
    t.json "rows"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_subscriber_imports_on_account_id"
    t.index ["created_at"], name: "index_subscriber_imports_on_created_at"
  end

  create_table "subscribers", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "email", limit: 255, null: false
    t.string "token", limit: 255, null: false
    t.datetime "confirmed_at"
    t.datetime "unsubscribed_at"
    t.datetime "bounced_at"
    t.datetime "confirmation_sent_at"
    t.integer "confirmations_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deactivated_at"
    t.uuid "source_post_id"
    t.string "referrer", limit: 255
    t.index ["account_id", "email"], name: "index_subscribers_on_account_id_and_email", unique: true
    t.index ["source_post_id"], name: "index_subscribers_on_source_post_id"
    t.index ["token"], name: "index_subscribers_on_token", unique: true
  end

  create_table "user_settings", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "user_id", null: false
    t.string "timezone_name", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "new_subscriber_notifications", default: true, null: false
    t.index ["account_id"], name: "index_user_settings_on_account_id"
    t.index ["user_id"], name: "index_user_settings_on_user_id"
  end

  create_table "users", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "identity_id"
    t.string "name", limit: 255, null: false
    t.string "role", limit: 255, default: "member", null: false
    t.boolean "active", default: true, null: false
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "identity_id"], name: "index_users_on_account_id_and_identity_id", unique: true
    t.index ["account_id", "role"], name: "index_users_on_account_id_and_role"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["identity_id"], name: "index_users_on_identity_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  execute "CREATE VIRTUAL TABLE search_records_fts USING fts5(\n  title,\n  content,\n  tokenize='trigram remove_diacritics 1'\n)"

end
