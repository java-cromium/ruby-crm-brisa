Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :email, null: false, unique: true
      String :name
      String :role, null: false, default: 'agent' # Default role for new users
      String :google_uid, unique: true # Store Google's unique ID

      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :email
      index :google_uid
    end
  end
end
