# frozen_string_literal: true

class CreatePressKits < ActiveRecord::Migration[8.1]
  def change
    create_table :press_kits, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.text :credits

      t.timestamps
    end
  end
end
