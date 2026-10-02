# frozen_string_literal: true

class PagesController < ApplicationController
  def index
    @pages = Page.order(:title, :created_at).to_a
  end
end
