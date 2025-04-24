Sequel.migration do
  change do
    alter_table(:tasks) do
      add_column :created_at, DateTime, default: Sequel::CURRENT_TIMESTAMP, index: true
      add_column :updated_at, DateTime, default: Sequel::CURRENT_TIMESTAMP
      add_column :due_date, Date # Use Date for due date, time is often not needed
    end

    # Add an index to updated_at as well, often useful
    add_index :tasks, :updated_at
  end
end
