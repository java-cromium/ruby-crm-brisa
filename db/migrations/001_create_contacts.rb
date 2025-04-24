# db/migrations/001_create_contacts.rb
Sequel.migration do
  up do
    create_table(:contacts) do
      primary_key :id
      String :first_name, null: false
      String :last_name
      String :email, unique: true # Add a unique constraint for email
      String :phone

      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end

  down do
    # This block defines how to reverse the migration (undo the 'up' block)
    drop_table(:contacts)
  end
end
