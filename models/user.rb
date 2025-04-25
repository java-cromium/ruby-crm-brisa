require 'sequel'

# User model representing application users
class User < Sequel::Model
  # Basic validations (can add more later)
  plugin :validation_helpers
  def validate
    super
    validates_presence [:email, :role]
    validates_unique :email
    validates_unique :google_uid, allow_nil: true # google_uid is optional but must be unique if present
    validates_includes ['admin', 'manager', 'agent'], :role # Define allowed roles
  end

  # Define associations if needed later (e.g., tasks assigned to user)
  # one_to_many :tasks
end
