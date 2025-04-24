# models/task.rb
class Task < Sequel::Model
  plugin :timestamps, update_on_create: true # Automatically handle created_at/updated_at

  # A Task can have many notes
  one_to_many :task_notes, order: :created_at, on_delete: :cascade # Order notes by creation time

  # Sequel will automatically map this to the 'tasks' table.

  # Add validations or associations later if needed.
  # Example: Link to contacts (assuming a contact_id column)
  # many_to_one :contact
end
