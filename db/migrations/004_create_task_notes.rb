Sequel.migration do
  change do
    create_table(:task_notes) do
      primary_key :id
      foreign_key :task_id, :tasks, null: false, on_delete: :cascade # Link to tasks table
      Text :content, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP, index: true
    end
  end
end
