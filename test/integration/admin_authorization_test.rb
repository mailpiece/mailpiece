require "test_helper"

class AdminAuthorizationTest < ActionDispatch::IntegrationTest
  ADMIN_ONLY = {
    "searches#show"                        => [ :get,    -> { search_path } ],
    "posts#index"                          => [ :get,    -> { posts_path } ],
    "posts#new"                            => [ :get,    -> { new_post_path } ],
    "posts#create"                         => [ :post,   -> { posts_path } ],
    "posts#show"                           => [ :get,    -> { "#{posts_path}/#{posts(:draft).id}.json" } ],
    "posts#edit"                           => [ :get,    -> { edit_post_path(posts(:draft)) } ],
    "posts#update"                         => [ :patch,  -> { post_path(posts(:draft)) } ],
    "posts#destroy"                        => [ :delete, -> { post_path(posts(:draft)) } ],
    "posts/publisheds#show"                => [ :get,    -> { posts_published_path } ],
    "posts/sents#show"                     => [ :get,    -> { posts_sent_path } ],
    "posts/nearbies#show"                  => [ :get,    -> { post_nearby_path(posts(:draft), day: "2026-10-04") } ],
    "posts/releases#create"                => [ :post,   -> { post_release_path(posts(:draft)) } ],
    "posts/publications#create"            => [ :post,   -> { post_publication_path(posts(:draft)) } ],
    "posts/publications#destroy"           => [ :delete, -> { post_publication_path(posts(:unlisted)) } ],
    "posts/listings#create"                => [ :post,   -> { post_listing_path(posts(:unlisted)) } ],
    "posts/listings#destroy"               => [ :delete, -> { post_listing_path(posts(:sent)) } ],
    "posts/deliveries#create"              => [ :post,   -> { post_delivery_path(posts(:draft)) } ],
    "posts/test_deliveries#create"         => [ :post,   -> { post_test_delivery_path(posts(:draft)) } ],
    "posts/schedules#create"               => [ :post,   -> { post_schedule_path(posts(:draft)) } ],
    "posts/schedules#destroy"              => [ :delete, -> { post_schedule_path(posts(:scheduled)) } ],
    "posts/revisions#index"                => [ :get,    -> { post_revisions_path(posts(:draft), format: :json) } ],
    "posts/revisions#show"                 => [ :get,    -> { post_revision_path(posts(:draft), post_revisions(:draft_before)) } ],
    "posts/links#index"                    => [ :get,    -> { post_links_path(posts(:sent), format: :json) } ],
    "posts/links#edit"                     => [ :get,    -> { edit_post_link_path(posts(:sent), post_links(:training)) } ],
    "posts/links#update"                   => [ :patch,  -> { post_link_path(posts(:sent), post_links(:training)) } ],
    "posts/results#show"                   => [ :get,    -> { post_results_path(posts(:sent)) } ],

    "calendars#show"                       => [ :get,    -> { calendar_path } ],
    "calendars/weeks#show"                 => [ :get,    -> { calendar_week_path("2026-10-04") } ],
    "calendars/agenda#show"                => [ :get,    -> { calendar_agenda_path("2026-10-04") } ],

    "subscribers#index"                    => [ :get,    -> { subscribers_path } ],
    "subscribers#show"                     => [ :get,    -> { subscriber_path(subscribers(:active)) } ],
    "subscribers#create"                   => [ :post,   -> { subscribers_path } ],
    "subscribers/actives#show"             => [ :get,    -> { subscribers_active_path } ],
    "subscribers/unconfirmeds#show"        => [ :get,    -> { subscribers_unconfirmed_path } ],
    "subscribers/unsubscribeds#show"       => [ :get,    -> { subscribers_unsubscribed_path } ],
    "subscribers/bounceds#show"            => [ :get,    -> { subscribers_bounced_path } ],
    "subscribers/deactivateds#show"        => [ :get,    -> { subscribers_deactivated_path } ],
    "subscribers#destroy"                  => [ :delete, -> { subscriber_path(subscribers(:active)) } ],
    "subscribers/activations#create"       => [ :post,   -> { subscriber_activation_path(subscribers(:stopped)) } ],
    "subscribers/activations#destroy"      => [ :delete, -> { subscriber_activation_path(subscribers(:active)) } ],
    "subscribers/confirmations#create"     => [ :post,   -> { subscriber_confirmation_path(subscribers(:unconfirmed)) } ],
    "subscribers/bounces#create"           => [ :post,   -> { subscriber_bounce_path(subscribers(:active)) } ],
    "subscribers/address_bounces#create"   => [ :post,   -> { subscribers_bounces_path(format: :json) } ],
    "subscribers/batches#new"              => [ :get,    -> { new_subscribers_batch_path } ],
    "subscribers/batches#create"           => [ :post,   -> { subscribers_batch_path } ],
    "subscribers/imports#new"              => [ :get,    -> { new_subscribers_import_path } ],
    "subscribers/imports#create"           => [ :post,   -> { subscribers_imports_path } ],
    "subscribers/imports#show"             => [ :get,    -> { subscribers_import_path(subscriber_imports(:read)) } ],
    "subscribers/imports/batches#new"      => [ :get,    -> { new_subscribers_import_batch_path(subscriber_imports(:read)) } ],
    "subscribers/imports/batches#create"   => [ :post,   -> { subscribers_import_batch_path(subscriber_imports(:read)) } ],
    "subscribers/import_templates#show"    => [ :get,    -> { subscribers_import_template_path } ],

    "account/settings#show"                => [ :get,    -> { account_settings_path } ],
    "account/newsletters#show"             => [ :get,    -> { account_newsletter_path(format: :json) } ],
    "account/newsletters#edit"             => [ :get,    -> { edit_account_newsletter_path } ],
    "account/newsletters#update"           => [ :patch,  -> { account_newsletter_path } ],
    "account/handles#show"                 => [ :get,    -> { account_handle_path(format: :json) } ],
    "account/handles#edit"                 => [ :get,    -> { edit_account_handle_path } ],
    "account/handles#update"               => [ :patch,  -> { account_handle_path } ],
    "account/domains#show"                 => [ :get,    -> { account_domain_path(format: :json) } ],
    "account/domains#edit"                 => [ :get,    -> { edit_account_domain_path } ],
    "account/domains#update"               => [ :patch,  -> { account_domain_path } ],
    "account/senders#show"                 => [ :get,    -> { account_sender_path(format: :json) } ],
    "account/senders#edit"                 => [ :get,    -> { edit_account_sender_path } ],
    "account/senders#update"               => [ :patch,  -> { account_sender_path } ],
    "account/outgoing_mails#show"          => [ :get,    -> { account_outgoing_mail_path } ],
    "account/senders/relays#edit"          => [ :get,    -> { edit_account_sender_relay_path } ],
    "account/senders/relays#update"        => [ :patch,  -> { account_sender_relay_path } ],
    "account/senders/relays#destroy"       => [ :delete, -> { account_sender_relay_path } ],
    "account/senders/smtp_servers#edit"    => [ :get,    -> { edit_account_sender_smtp_server_path } ],
    "account/senders/smtp_servers#update"  => [ :patch,  -> { account_sender_smtp_server_path } ],
    "account/senders/smtp_servers#destroy" => [ :delete, -> { account_sender_smtp_server_path } ],
    "account/subscribe_forms#show"         => [ :get,    -> { account_subscribe_form_path(format: :json) } ],
    "account/subscribe_forms#edit"         => [ :get,    -> { edit_account_subscribe_form_path } ],
    "account/subscribe_forms#update"       => [ :patch,  -> { account_subscribe_form_path } ],
    "account/welcomes#show"                => [ :get,    -> { account_welcome_path } ],
    "account/welcomes#create"              => [ :post,   -> { account_welcome_path } ],
    "account/welcomes#destroy"             => [ :delete, -> { account_welcome_path } ],
    "snippets#index"                       => [ :get,    -> { snippets_path } ],
    "snippets#new"                         => [ :get,    -> { new_snippet_path } ],
    "snippets#create"                      => [ :post,   -> { snippets_path } ],
    "snippets#show"                        => [ :get,    -> { "#{snippets_path}/#{snippets(:sign_off).id}.json" } ],
    "snippets#edit"                        => [ :get,    -> { edit_snippet_path(snippets(:sign_off)) } ],
    "snippets#update"                      => [ :patch,  -> { snippet_path(snippets(:sign_off)) } ],
    "snippets#destroy"                     => [ :delete, -> { snippet_path(snippets(:sign_off)) } ],
    "prompts/snippets#index"               => [ :get,    -> { prompts_snippets_path } ],
    "journeys#index"                       => [ :get,    -> { journeys_path } ],
    "journeys#show"                        => [ :get,    -> { journey_path("subscriber_confirmed") } ],
    "journeys/emails#new"                  => [ :get,    -> { new_journey_email_path("subscriber_confirmed") } ],
    "journeys/emails#create"               => [ :post,   -> { journey_emails_path("subscriber_confirmed") } ],
    "journeys/emails#show"                 => [ :get,    -> { journey_email_path("subscriber_confirmed", journey_emails(:davids), format: :json) } ],
    "journeys/emails#edit"                 => [ :get,    -> { edit_journey_email_path("subscriber_confirmed", journey_emails(:davids)) } ],
    "journeys/emails#update"               => [ :patch,  -> { journey_email_path("subscriber_confirmed", journey_emails(:davids)) } ],
    "journeys/emails#destroy"              => [ :delete, -> { journey_email_path("subscriber_confirmed", journey_emails(:davids)) } ],
    "journeys/emails/activations#create"   => [ :post,   -> { journey_email_activation_path("subscriber_confirmed", journey_emails(:davids)) } ],
    "journeys/emails/activations#destroy"  => [ :delete, -> { journey_email_activation_path("subscriber_confirmed", journey_emails(:davids)) } ],
    "journeys/emails/test_deliveries#create" => [ :post,   -> { journey_email_test_delivery_path("subscriber_confirmed", journey_emails(:davids)) } ],
    "account/join_codes#show"              => [ :get,    -> { account_join_code_path } ],
    "account/join_codes#edit"              => [ :get,    -> { edit_account_join_code_path } ],
    "account/join_codes#update"            => [ :patch,  -> { account_join_code_path } ],
    "account/join_codes#destroy"           => [ :delete, -> { account_join_code_path } ],
    "account/avatars#destroy"              => [ :delete, -> { account_avatar_path } ],

    "notifications/settings#show"          => [ :get,    -> { notifications_settings_path } ],
    "notifications/settings#update"        => [ :patch,  -> { notifications_settings_path } ]
  }

  # What a member, or nobody at all, may ask for. A route goes here only once it is clear it needs no admin.
  OPEN = %w[
    landings#show
    account/avatars#show

    users#show
    users#update
    users/email_addresses#new
    users/email_addresses#create
    users/email_addresses/confirmations#show
    users/email_addresses/confirmations#create
    users/joins#new
    users/joins#create
    users/verifications#new
    users/verifications#create

    my/identities#show
    my/timezones#update
    my/access_tokens#index
    my/access_tokens#new
    my/access_tokens#create
    my/access_tokens#show
    my/access_tokens#destroy
    my/passkeys#index
    my/passkeys#create
    my/passkeys#edit
    my/passkeys#update
    my/passkeys#destroy
    my/passkey_challenges#create

    qr_codes#show
    join_codes#new
    join_codes#create
    sessions#new
    sessions#create
    sessions#destroy
    sessions/magic_links#show
    sessions/magic_links#create
    sessions/menus#show
    sessions/passkeys#create
    signups#new
    signups#create
    signups/completions#new
    signups/completions#create

    public/posts#index
    public/posts#show
    public/sitemaps#show
    public/links#show
    public/subscriptions#show
    public/subscriptions#create
    public/embedded_subscriptions#create
    public/subscriptions/confirmations#show
    public/subscriptions/confirmations#create
    public/subscriptions/unsubscriptions#show
    public/subscriptions/unsubscriptions#create
    public/ratings#new
    public/ratings#create
    public/ratings#show
    hosts#show
  ]

  FRAMEWORK = %r{\A(rails|active_storage|action_mailbox|turbo)/}

  setup do
    sign_in_as :nonstaff
  end

  ADMIN_ONLY.each do |action, (verb, path)|
    test "a member is refused #{action}" do
      public_send verb, instance_exec(&path)

      assert_response :forbidden

      public_send verb, instance_exec(&path), as: :json

      assert_response :forbidden
    end
  end

  test "every route is on one list" do
    assert_empty routed_actions - ADMIN_ONLY.keys - OPEN, "Routes on neither list: say whether each is admin only"
    assert_empty (ADMIN_ONLY.keys + OPEN) - routed_actions, "Listed, but no longer routed"
    assert_empty ADMIN_ONLY.keys & OPEN, "On both lists"
  end

  test "an admin is not refused what a member is" do
    sign_in_as :mia

    get posts_path
    assert_response :success

    get subscribers_path
    assert_response :success

    get account_settings_path
    assert_response :success
  end

  private
    # A bare `resource` routes verbs its controller never answers, so only actions that exist count.
    def routed_actions
      Rails.application.routes.routes.filter_map do |route|
        controller, action = route.defaults.values_at(:controller, :action)

        if controller && !controller.match?(FRAMEWORK) && answered?(controller, action)
          "#{controller}##{action}"
        end
      end.uniq
    end

    def answered?(controller, action)
      "#{controller}_controller".camelize.constantize.action_methods.include?(action)
    end
end
