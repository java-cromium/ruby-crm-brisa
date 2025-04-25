# app.rb
require 'sinatra/base' # Use sinatra/base for modular style
require 'sinatra/flash'

class BrisaApp < Sinatra::Base # Define the application class

  # Register extensions
  register Sinatra::Flash

  # --- Helpers ---
  helpers do
    # Get the currently logged-in user object
    def current_user
      # Memoization: Avoid hitting the DB repeatedly within the same request
      @current_user ||= User.first(id: session[:user_id]) if session[:user_id]
    end
    
    # Check if a user is logged in
    def logged_in?
      !!current_user
    end
    
    # Helper for links, handling nil
    def link_to(url, body)
      "<a href='#{url}'>#{body}</a>"
    end
    
    # Format date/time
    def format_datetime(dt)
      dt ? dt.strftime('%Y-%m-%d %H:%M') : 'N/A'
    end
    
    def format_date(d)
      d ? d.strftime('%Y-%m-%d') : 'Not Set'
    end
    
    # Helper for form authenticity token (if needed later for non-GET requests)
    # def csrf_token
    #   Rack::Csrf.csrf_token(env)
    # end
    # def csrf_tag
    #   Rack::Csrf.csrf_tag(env)
    # end
    
    # Redirects to login if user is not authenticated
    # Skips auth-related paths
    def authenticate!
      unless logged_in?
        flash[:error] = "You need to sign in to access this page."
        redirect '/login'
      end
    end
  end

  # --- Sinatra Configuration ---
  configure do
    enable :sessions # Enable Sinatra's session handling (works with Rack::Session::Cookie)
    set :session_secret, ENV['SESSION_SECRET'] # Use the same secret for consistency (optional but good practice)
    
    # Set default content type
    set :erb, escape_html: true
    
    # Critical settings for modular Sinatra app
    enable :method_override # Enable method override for PUT/PATCH/DELETE in forms
    enable :absolute_redirects # Use absolute URLs
    
    # If using a different views directory
    # set :views, File.dirname(__FILE__) + '/views'
    # If using a different public directory
    # set :public_folder, File.dirname(__FILE__) + '/public'
  end

  # --- Filters (Middleware) ---

  # Apply authentication check to all routes EXCEPT auth routes and root
  before do
    # Skip authentication for login, logout, auth callback/failure, and root path
    pass if ['/login', '/logout', '/auth'].any? { |path| request.path_info.start_with?(path) } || request.path_info == '/'
    authenticate! # Apply to all other routes
  end

  # --- Routes ---

  # --- Authentication Routes ---

  # Display login page (will just contain a button)
  get '/login' do
    erb :'auth/login'
  end

  # Handle callback from Google OAuth2
  get '/auth/google_oauth2/callback' do
    auth = request.env['omniauth.auth']
  
    unless auth && auth.info && auth.info.email
      flash[:error] = 'Authentication failed: Could not retrieve user information from Google.'
      redirect '/login'
    end
  
    # Extract info
    email = auth.info.email
    name = auth.info.name
    google_uid = auth.uid
  
    # Find or create the user
    user = User.find_or_create(email: email) do |u|
      u.name = name
      u.google_uid = google_uid
      u.role = 'agent'  # Explicitly set role to meet validation requirements
    end
  
    # Update google_uid or name if user existed but didn't have them from a previous login
    user.update(google_uid: google_uid) if user.google_uid.nil? && google_uid
    user.update(name: name) if user.name.nil? && name
  
    if user && user.id
      session[:user_id] = user.id
      flash[:success] = "Welcome, #{user.name || user.email}! You are now logged in."
      redirect '/'
    else
      # This case should ideally not happen if find_or_create works, but good to handle
      flash[:error] = 'Authentication failed: Could not process user information.'
      redirect '/login'
    end
  rescue => e
    # Catch potential database or other errors during user processing
    puts "Error during Google OAuth callback: #{e.message}"
    puts e.backtrace.join("\n")
    flash[:error] = 'An unexpected error occurred during login. Please try again.'
    redirect '/login'
  end

  # Handle authentication failure
  get '/auth/failure' do
    flash[:error] = "Authentication failed: #{params[:message]}"
    redirect '/login'
  end

  # Logout
  get '/logout' do
    session.clear
    flash[:success] = "You have been logged out."
    redirect '/login'
  end

  # --- Main Application Routes ---

  # Root / Dashboard
  get '/' do
    # Fetch data for the dashboard
    @tasks = Task.where(completed: false).order(Sequel.desc(:id)).limit(5).all
    @customers = Customer.order(Sequel.desc(:id)).limit(5).all
    @contacts = Contact.order(Sequel.desc(:id)).limit(5).all
    erb :index
  end

  # --- Contacts Routes ---
  
  # List all contacts
  get '/contacts' do
    @contacts = Contact.order(:last_name, :first_name).all
    erb :'contacts/index'
  end
  
  # Show form to create a new contact
  get '/contacts/new' do
    @contact = Contact.new
    erb :'contacts/new'
  end
  
  # Create a new contact
  post '/contacts' do
    @contact = Contact.new(params[:contact])
    if @contact.save
      flash[:success] = 'Contact created successfully.'
      redirect '/contacts'
    else
      flash.now[:error] = "Error creating contact: #{@contact.errors.full_messages.join(', ')}"
      erb :'contacts/new'
    end
  end
  
  # Show contact details
  get '/contacts/:id' do
    @contact = Contact[params[:id]]
    if @contact
      erb :'contacts/show'
    else
      flash[:error] = 'Contact not found.'
      redirect '/contacts'
    end
  end
  
  # Show form to edit an existing contact
  get '/contacts/:id/edit' do
    @contact = Contact[params[:id]]
    if @contact
      erb :'contacts/edit'
    else
      flash[:error] = 'Contact not found.'
      redirect '/contacts'
    end
  end
  
  # Update an existing contact
  patch '/contacts/:id' do
    @contact = Contact[params[:id]]
    if @contact
      if @contact.update(params[:contact])
        flash[:success] = 'Contact updated successfully.'
        redirect '/contacts'
      else
        flash.now[:error] = "Error updating contact: #{@contact.errors.full_messages.join(', ')}"
        erb :'contacts/edit'
      end
    else
      flash[:error] = 'Contact not found.'
      redirect '/contacts'
    end
  end
  
  # Delete a contact
  delete '/contacts/:id' do
    @contact = Contact[params[:id]]
    if @contact
      # Check if contact is associated with a customer
      if Customer.where(contact_id: @contact.id).count > 0
        flash[:error] = 'Cannot delete contact associated with a customer. Please reassign or delete the customer first.'
        redirect '/contacts'
      else
        @contact.destroy
        flash[:success] = 'Contact deleted successfully.'
        redirect '/contacts'
      end
    else
      flash[:error] = 'Contact not found.'
      redirect '/contacts'
    end
  end

  # --- Customers Routes ---
  
  # List all customers
  get '/customers' do
    @customers = Customer.eager(:contact).order(Sequel.desc(:created_at)).all
    erb :'customers/index'
  end
  
  # Show form to create a new customer
  get '/customers/new' do
    @customer = Customer.new
    @contacts = Contact.order(:last_name, :first_name).all # Fetch contacts for dropdown
    @allowed_statuses = Customer::ALLOWED_STATUSES
    erb :'customers/new'
  end
  
  # Create a new customer
  post '/customers' do
    @customer = Customer.new(params[:customer])
    if @customer.save
      flash[:success] = 'Customer created successfully.'
      redirect '/customers'
    else
      @contacts = Contact.order(:last_name, :first_name).all # Need contacts again for form redisplay
      @allowed_statuses = Customer::ALLOWED_STATUSES
      flash.now[:error] = "Error creating customer: #{@customer.errors.full_messages.join(', ')}"
      erb :'customers/new'
    end
  end
  
  # Show customer details
  get '/customers/:id' do
    @customer = Customer.eager(:contact).with_pk(params[:id])
    if @customer
      erb :'customers/show'
    else
      flash[:error] = 'Customer not found.'
      redirect '/customers'
    end
  end
  
  # Show form to edit an existing customer
  get '/customers/:id/edit' do
    @customer = Customer[params[:id]]
    if @customer
      @contacts = Contact.order(:last_name, :first_name).all
      @allowed_statuses = Customer::ALLOWED_STATUSES
      erb :'customers/edit'
    else
      flash[:error] = 'Customer not found.'
      redirect '/customers'
    end
  end
  
  # Update an existing customer
  patch '/customers/:id' do
    @customer = Customer[params[:id]]
    if @customer
      if @customer.update(params[:customer])
        flash[:success] = 'Customer updated successfully.'
        redirect "/customers/#{@customer.id}"
      else
        @contacts = Contact.order(:last_name, :first_name).all # Need contacts again for form redisplay
        @allowed_statuses = Customer::ALLOWED_STATUSES
        flash.now[:error] = "Error updating customer: #{@customer.errors.full_messages.join(', ')}"
        erb :'customers/edit'
      end
    else
      flash[:error] = 'Customer not found.'
      redirect '/customers'
    end
  end
  
  # Delete a customer
  delete '/customers/:id' do
    @customer = Customer[params[:id]]
    if @customer
      # Optionally add checks here (e.g., prevent deletion if active tasks exist)
      @customer.destroy
      flash[:success] = 'Customer deleted successfully.'
      redirect '/customers'
    else
      flash[:error] = 'Customer not found.'
      redirect '/customers'
    end
  end

  # --- Tasks Routes ---
  
  # List all tasks (can be filtered later)
  get '/tasks' do
    # Skip eager loading on associations that don't exist in DB schema yet
    @tasks = Task.order(Sequel.desc(:created_at)).all
    erb :'tasks/index'
  end
  
  # Show form to create a new task
  get '/tasks/new' do
    @task = Task.new
    @contacts = Contact.order(:last_name, :first_name).all
    @customers = Customer.eager(:contact).order(Sequel.desc(:created_at)).all
    erb :'tasks/new'
  end
  
  # Create a new task
  post '/tasks' do
    task_params = params[:task]
    # Handle empty strings for optional associations
    task_params[:contact_id] = nil if task_params[:contact_id] == ''
    task_params[:customer_id] = nil if task_params[:customer_id] == ''
  
    @task = Task.new(task_params)
    if @task.save
      flash[:success] = 'Task created successfully.'
      redirect '/tasks'
    else
      @contacts = Contact.order(:last_name, :first_name).all
      @customers = Customer.eager(:contact).order(Sequel.desc(:created_at)).all
      flash.now[:error] = "Error creating task: #{@task.errors.full_messages.join(', ')}"
      erb :'tasks/new'
    end
  end
  
  # Show task details (including notes)
  get '/tasks/:id' do
    # Only eager load associations that exist in schema
    @task = Task.eager(:task_notes).with_pk(params[:id])
    if @task
      @note = TaskNote.new(task_id: @task.id) # For the 'add note' form
      erb :'tasks/show'
    else
      flash[:error] = 'Task not found.'
      redirect '/tasks'
    end
  end
  
  # Show form to edit an existing task
  get '/tasks/:id/edit' do
    @task = Task[params[:id]]
    if @task
      @contacts = Contact.order(:last_name, :first_name).all
      @customers = Customer.eager(:contact).order(Sequel.desc(:created_at)).all
      erb :'tasks/edit'
    else
      flash[:error] = 'Task not found.'
      redirect '/tasks'
    end
  end
  
  # Update an existing task
  patch '/tasks/:id' do
    @task = Task[params[:id]]
    if @task
      task_params = params[:task]
      task_params[:contact_id] = nil if task_params[:contact_id] == ''
      task_params[:customer_id] = nil if task_params[:customer_id] == ''
  
      if @task.update(task_params)
        flash[:success] = 'Task updated successfully.'
        redirect "/tasks/#{@task.id}"
      else
        @contacts = Contact.order(:last_name, :first_name).all
        @customers = Customer.eager(:contact).order(Sequel.desc(:created_at)).all
        flash.now[:error] = "Error updating task: #{@task.errors.full_messages.join(', ')}"
        erb :'tasks/edit'
      end
    else
      flash[:error] = 'Task not found.'
      redirect '/tasks'
    end
  end
  
  # Mark task as complete/incomplete
  patch '/tasks/:id/toggle_complete' do
    @task = Task[params[:id]]
    if @task
      new_status = !@task.completed
      # Use update_fields to bypass validation when only updating the completion status
      @task.update_fields({completed: new_status}, [:completed])
      status_text = new_status ? 'completed' : 'incomplete'
      flash[:success] = "Task marked as #{status_text}."
      redirect request.referrer || '/tasks' # Redirect back or to tasks index
    else
      flash[:error] = 'Task not found.'
      redirect '/tasks'
    end
  end
  
  # Alternative route for toggling task completion status (to match the form action)
  patch '/tasks/:id/toggle' do
    @task = Task[params[:id]]
    if @task
      new_status = !@task.completed
      # Use update_fields to bypass validation when only updating the completion status
      @task.update_fields({completed: new_status}, [:completed])
      status_text = new_status ? 'completed' : 'incomplete'
      flash[:success] = "Task marked as #{status_text}."
      redirect request.referrer || '/tasks' # Redirect back or to tasks index
    else
      flash[:error] = 'Task not found.'
      redirect '/tasks'
    end
  end
  
  # Delete a task
  delete '/tasks/:id' do
    @task = Task[params[:id]]
    if @task
      @task.destroy
      flash[:success] = 'Task deleted successfully.'
      redirect '/tasks'
    else
      flash[:error] = 'Task not found.'
      redirect '/tasks'
    end
  end
  
  # Delete a contact
  delete '/contacts/:id' do
    @contact = Contact[params[:id]]
    if @contact
      @contact.destroy
      flash[:success] = 'Contact deleted successfully.'
      redirect '/contacts'
    else
      flash[:error] = 'Contact not found.'
      redirect '/contacts'
    end
  end
  
  # Make a contact a customer
  post '/contacts/:id/make_customer' do
    @contact = Contact[params[:id]]
    if @contact
      # Create a new customer with this contact
      @customer = Customer.new(contact_id: @contact.id, status: 'prospect')
      if @customer.save
        flash[:success] = 'Contact successfully marked as customer.'
        redirect "/customers/#{@customer.id}"
      else
        flash[:error] = "Error updating contact: #{@customer.errors.full_messages.join(', ')}"
        redirect "/contacts/#{@contact.id}"
      end
    else
      flash[:error] = 'Contact not found.'
      redirect '/contacts'
    end
  end

  # --- Task Notes Routes ---
  
  # Add a note to a task
  post '/tasks/:task_id/notes' do
    @task = Task[params[:task_id]]
    if @task
      # Create a new task note with the content from the form
      @note = TaskNote.new(content: params[:content], task_id: @task.id)
      if @note.save
        flash[:success] = 'Note added successfully.'
        redirect "/tasks/#{@task.id}"
      else
        # Need to reload task data for rendering the show page again on error
        @task = Task.eager(:task_notes).with_pk(params[:task_id])
        flash.now[:error] = "Error adding note: #{@note.errors.full_messages.join(', ')}"
        erb :'tasks/show'
      end
    else
      flash[:error] = 'Task not found.'
      redirect '/tasks'
    end
  end
  
  # Delete a task note
  delete '/tasks/:task_id/notes/:note_id' do
    @note = TaskNote[params[:note_id]]
    if @note && @note.task_id == params[:task_id].to_i
      @note.destroy
      flash[:success] = 'Note deleted successfully.'
      redirect "/tasks/#{params[:task_id]}"
    else
      flash[:error] = 'Note not found or does not belong to this task.'
      redirect request.referrer || "/tasks/#{params[:task_id]}"
    end
  end

  # --- Customers Routes ---
  
  # List all customers
  get '/customers' do
    @customers = Customer.eager(:contact).order(Sequel.desc(:created_at)).all
    erb :'customers/index'
  end
  
  # Show form to create a new customer
  get '/customers/new' do
    @contact = Contact[params[:contact_id]] if params[:contact_id]
    @customer = Customer.new
    @allowed_statuses = Customer.allowed_statuses
    erb :'customers/new'
  end
  
  # Create a new customer
  post '/customers' do
    @customer = Customer.new(params[:customer])
    if @customer.save
      flash[:success] = 'Customer created successfully.'
      redirect '/customers'
    else
      @allowed_statuses = Customer.allowed_statuses
      flash.now[:error] = "Error creating customer: #{@customer.errors.full_messages.join(', ')}"
      erb :'customers/new'
    end
  end
  
  # Show customer details
  get '/customers/:id' do
    @customer = Customer.eager(:contact).with_pk(params[:id])
    if @customer
      erb :'customers/show'
    else
      flash[:error] = 'Customer not found.'
      redirect '/customers'
    end
  end
  
  # Show form to edit customer
  get '/customers/:id/edit' do
    @customer = Customer.eager(:contact).with_pk(params[:id])
    if @customer
      @allowed_statuses = Customer.allowed_statuses
      erb :'customers/edit'
    else
      flash[:error] = 'Customer not found.'
      redirect '/customers'
    end
  end
  
  # Update customer
  put '/customers/:id' do
    @customer = Customer[params[:id]]
    if @customer
      if @customer.update(params[:customer])
        flash[:success] = 'Customer updated successfully.'
        redirect "/customers/#{@customer.id}"
      else
        @allowed_statuses = Customer.allowed_statuses
        flash.now[:error] = "Error updating customer: #{@customer.errors.full_messages.join(', ')}"
        erb :'customers/edit'
      end
    else
      flash[:error] = 'Customer not found.'
      redirect '/customers'
    end
  end
  
  # Delete customer
  delete '/customers/:id' do
    @customer = Customer[params[:id]]
    if @customer
      @customer.destroy
      flash[:success] = 'Customer status removed successfully.'
      redirect '/customers'
    else
      flash[:error] = 'Customer not found.'
      redirect '/customers'
    end
  end

end # End of BrisaApp class
