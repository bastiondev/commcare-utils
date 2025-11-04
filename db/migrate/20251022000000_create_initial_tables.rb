class CreateInitialTables < ActiveRecord::Migration[8.1]
  def change
    create_table :destinations do |t|
      t.string :name, null: false
      t.text :database_url, null: false
      t.string :commcare_username, null: false
      t.text :commcare_password, null: false

      t.timestamps
    end

    create_table :destination_sources do |t|
      t.references :destination, null: false, foreign_key: true
      t.string :name, null: false
      t.string :url, null: false
      t.string :key_column, null: false
      t.string :table_name, null: false

      t.timestamps
    end

    create_table :users do |t|
      t.string :email, null: false
      
      t.timestamps
    end

    add_index :destination_sources, [:destination_id, :name], unique: true
  end
end
