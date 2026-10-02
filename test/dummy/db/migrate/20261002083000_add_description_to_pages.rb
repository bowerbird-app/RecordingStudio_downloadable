# frozen_string_literal: true

class AddDescriptionToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :description, :text
  end
end
