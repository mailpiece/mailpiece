resource :landing, only: :show
resource :search, only: :show

namespace :account do
  resource :join_code
  resource :avatar, only: :destroy
  resource :settings, only: :show
  resource :newsletter, only: %i[ edit update ]
  resource :newsletter, only: :show, format: true, constraints: { format: "json" }
  resource :handle, only: %i[ edit update ]
  resource :handle, only: :show, format: true, constraints: { format: "json" }
  resource :domain, only: %i[ edit update ]
  resource :domain, only: :show, format: true, constraints: { format: "json" }
  resource :sender, only: %i[ edit update ], path: "sending" do
    resource :relay, only: %i[ edit update destroy ], module: :senders
    resource :smtp_server, only: %i[ edit update destroy ], module: :senders, path: "smtp"
  end
  resource :sender, only: :show, path: "sending", format: true, constraints: { format: "json" }
  resource :outgoing_mail, only: :show
  resource :subscribe_form, only: %i[ edit update ]
  resource :subscribe_form, only: :show, format: true, constraints: { format: "json" }
  resource :welcome, only: %i[ show create destroy ]
end

namespace :prompts do
  resources :snippets, only: :index
end

namespace :posts do
  resource :published, only: :show
  resource :sent, only: :show
end

resources :posts, except: :show do
  scope module: :posts do
    resource :release, only: :create
    resource :publication, only: %i[ create destroy ]
    resource :listing, only: %i[ create destroy ]
    resource :delivery, only: :create
    resource :test_delivery, only: :create
    resource :schedule, only: %i[ create destroy ]
    resources :revisions, only: :show, path: "history"
    resources :revisions, only: :index, path: "history", format: true, constraints: { format: "json" }
    resources :links, only: :index, format: true, constraints: { format: "json" }
    resources :links, only: %i[ edit update ]
    resource :results, only: :show
    resource :nearby, only: :show
  end
end

resource :calendar, only: :show do
  scope module: :calendars do
    resources :weeks, only: :show, param: :date
    resources :agenda, only: :show, param: :date
  end
end

resources :snippets, except: :show
resources :snippets, only: :show, format: true, constraints: { format: "json" }

resources :journeys, only: %i[ index show ], param: :trigger do
  resources :emails, except: %i[ index show ], module: :journeys do
    scope module: :emails do
      resource :activation, only: %i[ create destroy ]
      resource :test_delivery, only: :create
    end
  end
  resources :emails, only: :show, module: :journeys, format: true, constraints: { format: "json" }
end

resources :posts, only: :show, format: true, constraints: { format: "json" }

namespace :subscribers do
  # The page answers at subscribers/new; its form keeps an address of its own, since subscribers takes one person.
  resource :batch, only: :new, path: ""
  resource :batch, only: :create
  resources :imports, only: %i[ new create show ] do
    resource :batch, only: %i[ new create ], module: :imports
  end
  resource :import_template, only: :show
  resource :active, only: :show
  resource :unconfirmed, only: :show
  resource :unsubscribed, only: :show
  resource :bounced, only: :show
  resource :deactivated, only: :show
  resources :bounces, only: :create, controller: :address_bounces, format: true, constraints: { format: "json" }
end
resources :subscribers, only: %i[ index show create destroy ] do
  scope module: :subscribers do
    resource :activation, only: %i[ create destroy ]
    resource :confirmation, only: :create
    resource :bounce, only: :create
  end
end

filter_path_parameters :id do
  resources :qr_codes
end

filter_path_parameters :code do
  get "join/:code", to: "join_codes#new", as: :join
  post "join/:code", to: "join_codes#create"
end

resources :users, only: %i[ show update ] do
  scope module: :users do
    filter_path_parameters :token, :email_address_token do
      resources :email_addresses, param: :token do
        resource :confirmation, module: :email_addresses
      end
    end
  end
end

namespace :notifications do
  resource :settings, only: %i[ show update ]
end

namespace :users do
  resources :joins
  resources :verifications, only: %i[ new create ]
end

resource :session do
  scope module: :sessions do
    resource :magic_link
    resource :menu
    resource :passkey, only: :create
  end
end

get "/signup", to: redirect("/signup/new")

resource :signup, only: %i[ new create ] do
  collection do
    scope module: :signups, as: :signup do
      resource :completion, only: %i[ new create ]
    end
  end
end

namespace :my do
  resource :passkey_challenge, only: :create
  resource :identity, only: :show
  resources :access_tokens, except: %i[ show edit update ]
  resources :passkeys, except: %i[ show new ]
  resource :timezone
end

get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

namespace :admin do
  mount MissionControl::Jobs::Engine, at: "/jobs"
end
