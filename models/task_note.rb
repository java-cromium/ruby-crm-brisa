# models/task_note.rb
class TaskNote < Sequel::Model
  # Associate this note with a Task
  many_to_one :task

  # Optional: Use timestamps plugin if you want updated_at as well,
  # but created_at is already handled by the DB default.
  # plugin :timestamps, update_on_create: true
end
