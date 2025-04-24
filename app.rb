# app.rb
require 'sinatra'
require 'sinatra/flash'
require 'sequel'

# TODO: Move database credentials to environment variables or a config file
# Database connection using Sequel
DB = Sequel.connect('postgres://ruby_crm_user:Str0ngP%40ssw0rdCRM%21@localhost:5432/ruby_crm_dev')

# Basic check to see if connection is working (optional, but good for verification)
begin
  DB.test_connection
  puts "Database connection successful!"
rescue Sequel::DatabaseConnectionError => e
  puts "Database connection failed: #{e.message}"
  # Exit or handle the error appropriately if the DB is essential
  exit(1)
end

# --- Sinatra Configuration ---
configure do
  # Enable sessions - required for flash messages
  # A secret key is needed for session security. Generate a secure random one
  # in production. For development, a simple string is okay, but change it!
  # You can generate one using: ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') { 'replace_this_with_your_generated_64_char_secret_e5a8b1c3d4f5a6b7c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0' } # Example - GENERATE YOUR OWN!
end

# Load models
require_relative 'models/contact'
require_relative 'models/task'
require_relative 'models/task_note'
require_relative 'models/customer'

# Routes
get '/' do
  # Fetch data for the dashboard
  @tasks = Task.where(completed: false).order(Sequel.desc(:id)).limit(5).all
  @customers = Customer.eager(:contact).order(Sequel.desc(:id)).limit(5).all

  erb :index # Render the new dashboard view
end

# --- Task Routes ---

# List all tasks
get '/tasks' do
  @tasks = Task.order(:id).all # Fetch all tasks, ordered by ID for now
  erb :'tasks/index' # Render the tasks index view
end

# Show form to create a new task
get '/tasks/new' do
  erb :'tasks/new' # Render the new task form view
end

# Handle form submission to create a new task
post '/tasks' do
  @task = Task.new(params[:task])
  if @task.save
    flash[:notice] = 'Task was successfully created.'
    redirect '/tasks'
  else
    # Validation failed, re-render the form with errors
    flash.now[:alert] = 'Please fix the errors below.'
    erb :'tasks/new'
  end
end

# Show details for a specific task
get '/tasks/:id' do
  # Eager load notes when fetching the task
  @task = Task.eager(:task_notes).with_pk(params[:id]) # with_pk is efficient for finding by primary key

  if @task
    erb :'tasks/show'
  else
    # Handle task not found (e.g., 404 page or redirect)
    # For now, redirecting back to list
    redirect '/tasks'
  end
end

# Show form to edit an existing task
get '/tasks/:id/edit' do
  @task = Task[params[:id]] # Find task by ID
  if @task
    erb :'tasks/edit'
  else
    # Handle task not found (e.g., show 404 or redirect)
    # For now, just redirecting back
    redirect '/tasks'
  end
end

# Handle form submission to update an existing task
patch '/tasks/:id' do
  @task = Task[params[:id]]
  if @task.update(params[:task])
    flash[:notice] = 'Task was successfully updated.'
    redirect "/tasks/#{@task.id}" # Redirect to show page after update
  else
    # Validation failed, re-render the form with errors
    flash.now[:alert] = 'Please fix the errors below.'
    erb :'tasks/edit'
  end
end

# Toggle the completion status of a task
patch '/tasks/:id/toggle' do
  @task = Task[params[:id]]
  if @task
    new_status = !@task.completed
    @task.update(completed: new_status)
    redirect '/tasks'
  else
    # Handle task not found
    redirect '/tasks'
  end
end

# Delete a task
delete '/tasks/:id' do
  @task = Task[params[:id]]
  if @task
    @task.destroy # This will also destroy associated task_notes due to :on_delete
    flash[:notice] = 'Task was successfully deleted.'
    redirect '/tasks'
  else
    flash[:error] = 'Task not found.'
    redirect '/tasks'
  end
end

# --- End Task Routes ---

# --- Task Notes Routes ---

# Handle form submission to add a new note to a task
post '/tasks/:task_id/notes' do
  @task = Task[params[:task_id]]
  if @task && params[:content] && !params[:content].strip.empty?
    # Use the association to create the note, automatically setting task_id
    @task.add_task_note(content: params[:content])
    redirect "/tasks/#{@task.id}/edit" # Redirect back to the edit page to see the new note
  elsif @task
    # Content was empty, just redirect back
    # Optionally: add flash message here to indicate error
    redirect "/tasks/#{@task.id}/edit"
  else
    # Task not found
    redirect '/tasks'
  end
end

# --- End Task Notes Routes ---


# --- Customer Routes ---

# List all customers
get '/customers' do
  # Eager load the associated contact to avoid N+1 queries in the view
  @customers = Customer.eager(:contact).all
  erb :'customers/index'
end

# Display form to create a new customer from an existing contact
get '/customers/new' do
  # Find contacts that are not already customers
  # This requires joining contacts and customers and finding contacts without a match
  # Or simpler: find contacts whose IDs are not in the customers table's contact_id column
  customer_contact_ids = Customer.select_map(:contact_id)
  @available_contacts = if customer_contact_ids.empty?
                          Contact.order(:last_name, :first_name) # If no customers, all contacts are available
                        else
                          Contact.where(Sequel.~(id: customer_contact_ids)).order(:last_name, :first_name)
                        end

  # Pass allowed statuses to the view for the dropdown
  @allowed_statuses = Customer::ALLOWED_STATUSES

  # Initialize an empty customer for form helpers
  @customer = Customer.new 

  erb :'customers/new'
end

# Show details for a specific customer
get '/customers/:id' do
  # Eager load the contact when fetching the customer
  @customer = Customer.eager(:contact).with_pk(params[:id])

  if @customer
    erb :'customers/show'
  else
    # Handle customer not found
    redirect '/customers'
  end
end

# Create a new customer record (associate with contact)
post '/customers' do
  # The params[:customer] hash should now contain 'contact_id' and 'status'
  @customer = Customer.new(params[:customer])
  if @customer.save
    flash[:notice] = 'Customer status was successfully added.' # Added
    redirect "/customers/#{@customer.id}"
  else
    # Validation failed
    flash.now[:alert] = 'Please fix the errors below.'
    # Reload necessary data for the form
    customer_contact_ids = Customer.select_map(:contact_id)
    @available_contacts = if customer_contact_ids.empty?
                            Contact.order(:last_name, :first_name)
                          else
                            Contact.where(Sequel.~(id: customer_contact_ids)).order(:last_name, :first_name)
                          end
    @allowed_statuses = Customer::ALLOWED_STATUSES
    erb :'customers/new'
  end
end

# Show form to edit an existing customer's status
get '/customers/:id/edit' do
  @customer = Customer.eager(:contact).with_pk(params[:id]) # Eager load contact for display

  if @customer
    @allowed_statuses = Customer::ALLOWED_STATUSES # Pass statuses to the view
    erb :'customers/edit'
  else
    # Handle customer not found
    redirect '/customers'
  end
end

# Process form submission for updating a customer's status
put '/customers/:id' do
  @customer = Customer[params[:id]]
  # Assuming params[:customer] contains the 'status' field
  if @customer&.update(status: params[:status]) # Simplified update
    flash[:notice] = 'Customer status was successfully updated.'
    redirect "/customers/#{@customer.id}"
  else
    if @customer.nil?
      flash[:error] = 'Customer not found.' # Keep flash[:error] for actual not found
      redirect '/customers'
    else
      # Validation error occurred during update
      flash.now[:alert] = 'Please fix the errors below.' # Use flash.now for re-render
      @allowed_statuses = Customer::ALLOWED_STATUSES # Need statuses for the form
      # @customer still holds the attempted (failed) update values and errors
      erb :'customers/edit' # Re-render form
    end
  end
end

# Delete a customer (remove customer status, keep contact)
delete '/customers/:id' do
  @customer = Customer[params[:id]]
  if @customer
    contact_id = @customer.contact_id # Get contact id before deleting
    @customer.destroy
    flash[:notice] = 'Customer status was successfully removed.'
    # Redirect to the contact's page might be more logical
    redirect contact_id ? "/contacts/#{contact_id}" : '/customers'
  else
    flash[:error] = 'Customer not found.'
    redirect '/customers'
  end
end

# TODO: Add routes for creating, updating, deleting customers

# --- End Customer Routes ---

# --- Contact Routes ---

# List all contacts
get '/contacts' do
  # Eager load the associated customer record (if it exists)
  @contacts = Contact.eager(:customer).order(:last_name, :first_name).all
  erb :'contacts/index'
end

# Show form to create a new contact
get '/contacts/new' do
  # Initialize an empty contact object for the form helper
  @contact = Contact.new
  erb :'contacts/new' # Render the new contact form view (we'll create this next)
end

# Show details for a specific contact
get '/contacts/:id' do
  # Eager load customer status when fetching contact
  @contact = Contact.eager(:customer).with_pk(params[:id])

  if @contact
    erb :'contacts/show'
  else
    # Handle contact not found
    redirect '/contacts'
  end
end

# Handle form submission to create a new contact
post '/contacts' do
  @contact = Contact.new(params[:contact])
  if @contact.save
    flash[:notice] = 'Contact was successfully created.'
    redirect '/contacts'
  else
    # Validation failed
    flash.now[:alert] = 'Please fix the errors below.'
    erb :'contacts/new'
  end
end

# Promote a Contact to a Customer
post '/contacts/:id/make_customer' do
  @contact = Contact[params[:id]]

  # Check if contact exists and is not already a customer
  if @contact && !@contact.customer
    # Create the customer record, linking it to the contact
    # The status defaults to 'active' as defined in the migration
    Customer.create(contact_id: @contact.id)
    # Optionally: Add a success flash message
    redirect '/contacts' # Redirect back to the contacts list
  elsif @contact && @contact.customer
    # Contact is already a customer, maybe show an error/info message
    # Optionally: Add an info flash message
    redirect '/contacts'
  else
    # Contact not found
    # Optionally: Add an error flash message
    redirect '/contacts'
  end
end

# Show form to edit an existing contact
get '/contacts/:id/edit' do
  @contact = Contact[params[:id]] # Find contact by ID

  if @contact
    erb :'contacts/edit'
  else
    # Handle contact not found
    redirect '/contacts'
  end
end

# Process form submission for updating a contact
put '/contacts/:id' do
  @contact = Contact[params[:id]]
  if @contact.update(params[:contact])
    flash[:notice] = 'Contact was successfully updated.'
    redirect "/contacts/#{@contact.id}" # Redirect to the contact's show page
  else
    # Validation failed
    flash.now[:alert] = 'Please fix the errors below.'
    erb :'contacts/edit'
  end
end

# Delete a contact
delete '/contacts/:id' do
  @contact = Contact[params[:id]]

  if @contact
    # Optional: Check for associated customer and prevent deletion or handle cascade
    if @contact.customer
      flash[:error] = 'Cannot delete contact with associated customer record. Remove customer status first.'
      redirect "/contacts/#{@contact.id}"
    else
      @contact.destroy
      flash[:notice] = 'Contact was successfully deleted.'
      redirect '/contacts'
    end
  else
    flash[:error] = 'Contact not found.'
    redirect '/contacts'
  end
end

# --- End Contact Routes ---
