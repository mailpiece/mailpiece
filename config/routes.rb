Rails.application.routes.draw do
  # What a reader asks for, and what is called from outside: these answer on any host, a newsletter's own
  # domain included. A link from here to a screen of the app, or back, is an absolute URL.
  root "public/posts#index"

  namespace :account do
    resource :avatar, only: :show
  end

  scope module: :public, as: :public do
    get "feed", to: "posts#index", as: :feed, format: false, defaults: { format: :atom }
    get "sitemap.xml", to: "sitemaps#show", as: :sitemap, defaults: { format: :xml }
    resources :links, only: :show, param: :code, path: "link"

    resource :subscription, only: %i[ show create ]
    resource :embedded_subscription, only: :create, path: "subscribe"
    filter_path_parameters :subscription_token do
      resources :subscriptions, only: [], param: :token do
        scope module: :subscriptions do
          resource :confirmation, only: %i[ show create ], path: "confirm"
          resource :unsubscription, only: %i[ show create ], path: "unsubscribe"
        end
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
  resource :host, only: :show, path: "up/host"

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # The app's own screens, which a newsletter's domain never answers. A new route goes in routes/app.rb
  # unless a reader asks for it.
  constraints ->(request) { !AccountDomain.request?(request) } do
    draw :app
  end

  # Last, so every screen of the app's own is tried first: a post answers at its title and code alone.
  scope module: :public, as: :public do
    get ":id", to: "posts#show", as: :post, format: false, constraints: { id: /[a-z0-9_-]+-[0-9a-f]{8}/ }
    get ":id.md", to: "posts#show", as: :post_markdown, format: false, defaults: { format: :md }, constraints: { id: /[a-z0-9_-]+-[0-9a-f]{8}/ }
  end
end
