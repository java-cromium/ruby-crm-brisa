# models/contact.rb
class Contact < Sequel::Model
  # No need to define columns here unless you want specific configurations.
  # Sequel introspects the schema from the database.

  # A Contact can have zero or one associated Customer record
  # Add on_delete: :cascade to delete the associated customer record when a contact is deleted
  one_to_one :customer, on_delete: :cascade

  # Enable validation helpers
  plugin :validation_helpers

  # You can add validations, associations, and helper methods here later.
  def validate
    super # Call super for any parent validations
    validates_presence [:first_name, :last_name, :email, :phone]
    validates_unique :email
  end
end
