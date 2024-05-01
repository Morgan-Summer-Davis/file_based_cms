ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { 'rack.session' => { username: 'admin' } }
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def test_root_dir
    create_document 'about.txt'
    create_document 'changes.txt'

    get '/'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.txt'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_nonexistent_file
    error = 'test does not exist.'

    get '/test'
    assert_equal 302, last_response.status
    assert_equal error, session[:flash]

    get '/'
    refute_equal error, session[:flash]
  end

  def test_txt_file
    create_document 'about.txt', 'test'

    get '/about.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, 'test'
  end

  def test_md_file
    create_document 'markdown.md', '# test'

    get '/markdown.md'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>test</h1>'
  end

  def test_file_edit_page
    create_document 'about.txt', 'test'

    get '/about.txt/edit'
    assert_equal 302, last_response.status
    assert_equal 'You must be logged in to do that.', session[:flash]

    get '/about.txt/edit', {}, admin_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '>test</textarea>'
  end

  def test_editing_file
    create_document 'about.txt', 'test'
    success = 'about.txt has been updated.'

    post '/about.txt/edit', { content: 'update' }
    assert_equal 302, last_response.status
    assert_equal 'You must be logged in to do that.', session[:flash]

    post '/about.txt/edit', { content: 'update' }, admin_session
    assert_equal 302, last_response.status
    assert_equal success, session[:flash]

    get '/'
    refute_equal success, session[:flash]

    get '/about.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'update'
  end

  def test_new_file_page
    get '/new'
    assert_equal 302, last_response.status
    assert_equal 'You must be logged in to do that.', session[:flash]

    get '/new', {}, admin_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Add a new document:'
    assert_includes last_response.body, '<input type="text"'
  end

  def test_creating_file
    success = 'about.txt has been created.'

    post '/new', { file_name: 'about.txt' }
    assert_equal 302, last_response.status
    assert_equal 'You must be logged in to do that.', session[:flash]

    post '/new', { file_name: 'about.txt' }, admin_session
    assert_equal 302, last_response.status
    assert_equal success, session[:flash]

    get '/'
    refute_equal success, session[:flash]
    assert_includes last_response.body, 'about.txt'

    get '/about.txt'
    assert_equal 200, last_response.status
    assert_equal last_response.body, ''
  end

  def test_creating_file_without_file_name
    error = 'A name is required.'

    post '/new', { file_name: '' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, error

    get '/'
    refute_equal error, session[:flash]
  end

  def test_creating_file_without_extension
    error = 'A file extension is required.'

    post '/new', { file_name: 'about' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, error

    get '/'
    refute_equal error, session[:flash]
  end

  def test_creating_duplicate_file
    create_document 'about.txt'
    error = 'The file name must be unique.'

    post '/new', { file_name: 'about.txt' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, error

    get '/'
    refute_equal error, session[:flash]
  end

  def test_delete_file
    create_document 'about.txt'
    success = 'about.txt has been deleted.'

    post '/about.txt/delete'
    assert_equal 302, last_response.status
    assert_equal 'You must be logged in to do that.', session[:flash]

    post '/about.txt/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal success, session[:flash]

    get '/'
    refute_equal success, session[:flash]
    refute_includes last_response.body, 'href="/about.txt"'

    get '/about.txt'
    assert_equal 302, last_response.status
    assert_equal 'about.txt does not exist.', session[:flash]
  end

  def test_login_page
    get '/users/login'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:'
    assert_includes last_response.body, 'Password:'
    assert_includes last_response.body, "<input type='password'"
    assert_includes last_response.body, "<input type='submit'"
  end

  def test_login
    get '/'
    assert_equal nil, session[:username]

    post '/users/login', { username: 'admin', password: 'secret' }
    assert_equal 'admin', session[:username]
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:flash]
    assert_includes 'Sign Out', last_response.body
  end

  def test_logout
    post '/users/logout'
    assert_equal 302, last_response.status
    assert_equal 'You must be logged in to do that.', session[:flash]

    post '/users/logout', {}, admin_session
    assert_equal nil, session[:username]
    assert_equal 302, last_response.status
    assert_equal 'You have been signed out.', session[:flash]
    assert_includes 'Sign In', last_response.body
  end
end