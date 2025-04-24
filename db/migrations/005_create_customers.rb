Sequel.migration do
  change do
    create_table(:customers) do
      primary_key :id
      foreign_key :contact_id, :contacts, null: false, unique: true, on_delete: :cascade # Each contact can be a customer only once
      String :status, null: false, default: 'active' # e.g., active, inactive, churned
      # Add other customer-specific fields here later if needed

      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP, index: true
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP, index: true
    end
  end
end
