# models/task.rb
class Task < Sequel::Model
  plugin :timestamps, update_on_create: true # Automatically handle created_at/updated_at

  # A Task can have many notes
  one_to_many :task_notes, order: :created_at, on_delete: :cascade # Order notes by creation time

  # Associations with Contact and Customer models
  many_to_one :contact   # Task belongs to a Contact (references contact_id)
  many_to_one :customer  # Task belongs to a Customer (references customer_id)
  
  # Validations (add any specific validations here)
  plugin :validation_helpers
  def validate
    super
    validates_presence :title   # Title is required
    # Due date is now optional
  end
end
