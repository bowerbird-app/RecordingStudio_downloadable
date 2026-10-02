# frozen_string_literal: true

RecordingStudioDownloadable::Engine.routes.draw do
  resources :recordings, only: [] do
    resource :package, only: %i[show create] do
      get :status
    end
  end
end
