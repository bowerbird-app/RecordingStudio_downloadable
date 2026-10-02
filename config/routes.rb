# frozen_string_literal: true

RecordingStudioDownloadable::Engine.routes.draw do
  resources :recordings, only: [] do
    resource :package, only: %i[show create]
    get "package/status", to: "packages#status", as: :package_status
  end
end
