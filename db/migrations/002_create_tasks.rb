Sequel.migration do
  change do
    create_table(:tasks) do
      primary_key :id
      String :title, null: false
      Text :description
      Boolean :completed, default: false, null: false
      # We can add timestamps later if needed:
      # DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      # DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
