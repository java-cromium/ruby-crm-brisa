# Seed data for the Brisa CRM application using Faker

require_relative '../app' # Load application environment (models, DB connection)
require 'faker'
require 'date'

puts "Seeding database with Faker data..."

# Clear existing data (optional, use with caution in development)
puts "Clearing existing data..."
DB.transaction do
  puts "Deleting Tasks..."
  Task.dataset.delete
  puts "Deleting Customers..."
  Customer.dataset.delete
  puts "Deleting Contacts..."
  Contact.dataset.delete
end

# Create Contacts
puts "Creating contacts (approx 120)..."
contact_ids = []
120.times do
  contact = Contact.create(
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    email: Faker::Internet.unique.email,
    phone: Faker::PhoneNumber.phone_number,
    company: Faker::Company.name,
    created_at: Faker::Time.between(from: DateTime.now - 365, to: DateTime.now),
    updated_at: Time.now
  )
  contact_ids << contact.id if contact&.id # Store ID if creation succeeded
end
puts "Created #{contact_ids.count} contacts."

# Create Customers
puts "Creating customers (approx 80)..."
if contact_ids.empty? || contact_ids.count < 80
  puts "Not enough unique contacts created (#{contact_ids.count}), skipping customer creation or creating fewer."
  # Decide how to handle: skip, or create fewer?
  # For now, let's create as many as possible up to 80
  customer_contact_ids_sample = contact_ids.uniq.sample([contact_ids.count, 80].min) # Sample unique IDs
else
  customer_contact_ids_sample = contact_ids.uniq.sample(80) # Sample 80 unique IDs
end

customer_count = 0
customer_contact_ids_sample.each do |chosen_contact_id|
  customer = Customer.create(
    contact_id: chosen_contact_id,
    status: Customer::ALLOWED_STATUSES.sample, # Use defined statuses
    created_at: Faker::Time.between(from: DateTime.now - 300, to: DateTime.now),
    updated_at: Time.now
  )
  customer_count += 1 if customer&.id
end
puts "Created #{customer_count} customers."

# Create Tasks
puts "Creating tasks (approx 150)..."
task_count = 0
150.times do
  due = [true, false].sample ? Faker::Date.between(from: Date.today - 30, to: Date.today + 90) : nil
  task = Task.create(
    title: Faker::Lorem.sentence(word_count: 3, supplemental: true, random_words_to_add: 4),
    description: Faker::Lorem.paragraph(sentence_count: 2),
    completed: [true, false].sample,
    due_date: due,
    created_at: Faker::Time.between(from: DateTime.now - 180, to: DateTime.now),
    updated_at: Time.now
  )
  task_count += 1 if task&.id
end
puts "Created #{task_count} tasks."

puts "Faker seeding completed successfully!"
