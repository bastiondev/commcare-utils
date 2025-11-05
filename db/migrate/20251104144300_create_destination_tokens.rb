class CreateDestinationTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :destination_tokens do |t|
      t.references :destination, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :last_accessed_at

      t.timestamps
    end

    add_index :destination_tokens, :token, unique: true
  end
end
