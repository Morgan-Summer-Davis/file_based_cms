require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, '590a04149827f56b5d1860bf4b0399f1e30e2a34e89526cc7ba9c3d8d5dd99c1'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def users_hash
  if ENV["RACK_ENV"] == "test"
    users_path = File.expand_path("../test/users.yml", __FILE__)
  else
    users_path = File.expand_path("../users.yml", __FILE__)
  end

  YAML.load_file(users_path)
end

def display_file(filepath)
  content = File.read(filepath)

  case File.extname(filepath)
  when '.md'
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    erb markdown.render(content)
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    content
  end
end

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

def valid_file_name?(str)
  directory = File.join(data_path, '*')
  files = Dir.glob(directory).map { |path| File.basename(path) }

  if !str || str.strip == ''
    session[:flash] = 'A name is required.'
    false
  elsif File.extname(str) == ''
    session[:flash] = 'A file extension is required.'
    false
  elsif files.include? str.strip
    session[:flash] = 'The file name must be unique.'
    false
  else
    true
  end
end

def correct_password?(password, encrypted_password)
  BCrypt::Password.new(encrypted_password) == password
end

def refuse_unless_logged_in
  unless session[:username]
    session[:flash] = 'You must be logged in to do that.'
    redirect '/'
  end
end

get '/' do
  p request.env == env
  directory = File.join(data_path, '*')
  @files = Dir.glob(directory).map { |path| File.basename(path) }
  erb :directory, layout: :layout
end

get '/users/login' do
  erb :login, layout: :layout
end

post '/users/login' do
  if correct_password?(params[:password], users_hash[params[:username]])
    session[:flash] = 'Welcome!'
    session[:username] = params[:username]
    redirect '/'
  else
    session[:flash] = 'Invalid credentials.'
    status 422
    erb :login, layout: :layout
  end
end

post '/users/logout' do
  refuse_unless_logged_in

  session.delete(:username)

  session[:flash] = 'You have been signed out.'
  redirect '/'
end

get '/new' do
  refuse_unless_logged_in

  erb :new_document
end

post '/new' do
  refuse_unless_logged_in

  file_name = params[:file_name]

  if valid_file_name?(file_name)
    create_document(file_name)
    session[:flash] = "#{file_name} has been created."
    redirect '/'
  else
    status 422
    erb :new_document, layout: :layout
  end
end

get '/:file' do
  filepath = File.join(data_path, File.basename(params[:file]))

  if File.exist? filepath
    display_file(filepath)
  else
    session[:flash] = "#{File.basename(filepath)} does not exist."
    redirect '/'
  end
end

get '/:file/edit' do
  refuse_unless_logged_in

  filepath = File.join(data_path, params[:file])

  if File.exist? filepath
    @file = File.basename(filepath)
    @content = File.read(filepath)
    erb :edit_file
  else
    session[:flash] = "#{File.basename(filepath)} does not exist."
    redirect '/'
  end
end

post '/:file/edit' do
  refuse_unless_logged_in

  filepath = File.join(data_path, params[:file])
  File.open(filepath, "w+") { |file| file.puts params[:content] }

  session[:flash] = "#{File.basename(filepath)} has been updated."
  redirect '/'
end

post '/:file/delete' do
  refuse_unless_logged_in

  filepath = File.join(data_path, params[:file])
  File.delete(filepath)

  session[:flash] = "#{File.basename(filepath)} has been deleted."
  redirect '/'
end