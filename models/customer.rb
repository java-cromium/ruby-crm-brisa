# models/customer.rb
class Customer < Sequel::Model
  # Enable plugin for validation helpers
  plugin :validation_helpers
  plugin :timestamps, update_on_create: true

  # Define allowed statuses
  ALLOWED_STATUSES = %w[active inactive prospect].freeze

  # A Customer is associated with one Contact
  many_to_one :contact

  # Validation block
  def validate
    super # Recommended to call super
    # Ensure status is one of the allowed values
    validates_includes ALLOWED_STATUSES, :status, message: "must be one of: #{ALLOWED_STATUSES.join(', ')}"
  end

  # Sequel will automatically map this to the 'customers' table.
end
