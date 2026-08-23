Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  resource :setup, only: [ :new, :create ], controller: "setup"
  resource :session
  resources :passwords, param: :token

  namespace :admin do
    resources :users, only: [ :index, :new, :create, :destroy ] do
      member do
        post :password_reset_link
      end
    end
  end

  resource :settings, only: [ :update ]
  resource :palette, only: [ :show ], controller: "palette"
  resources :todos, only: [ :index ]

  root "home#index"

  resources :notebooks, only: [ :create, :update, :destroy ] do
    collection do
      patch :reorder
    end
    member do
      get :export
    end
    resources :folders, only: [ :create, :update, :destroy ] do
      member do
        patch :move
      end
    end
  end

  resources :notes, only: [ :create, :update, :destroy ] do
    member do
      get :export
      patch :move
    end

    resources :todo_items, only: [ :create, :update, :destroy ] do
      collection do
        post :bulk_create
      end
    end
    resources :scrap_items, only: [ :create, :update, :destroy ] do
      member do
        post :promote
      end
    end
    resources :images, only: [ :create ], controller: "note_images"
  end
end
