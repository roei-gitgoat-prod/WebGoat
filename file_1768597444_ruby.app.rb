#!/usr/bin/env ruby

require 'webrick'
require 'json'
require 'cgi'
require 'fileutils'

class CorporatePortalApp < WEBrick::HTTPServlet::AbstractServlet
  def initialize(server, upload_dir = '/tmp/ruby_uploads')
    super(server)
    @upload_dir = upload_dir
    @users_file = 'ruby_users.json'
    FileUtils.mkdir_p(@upload_dir)
    initialize_users
  end

  def initialize_users
    unless File.exist?(@users_file)
      users = {
        'admin' => { 'password' => 'admin123', 'role' => 'admin', 'email' => 'admin@test.com' },
        'user' => { 'password' => 'user123', 'role' => 'user', 'email' => 'user@test.com' },
        'test' => { 'password' => 'test', 'role' => 'user', 'email' => 'test@test.com' }
      }
      File.write(@users_file, JSON.pretty_generate(users))
    end
  end

  def do_GET(request, response)
    case request.path
    when '/'
      handle_home(request, response)
    when '/download'
      handle_download(request, response)
    when '/admin/users'
      handle_list_users(request, response)
    when '/admin/logs'
      handle_view_logs(request, response)
    when '/profile'
      handle_profile(request, response)
    when '/search'
      handle_search(request, response)
    else
      response.status = 404
      response.body = '<h1>404 Not Found</h1>'
    end
  end

  def do_POST(request, response)
    case request.path
    when '/login'
      handle_login(request, response)
    when '/upload'
      handle_upload(request, response)
    when '/admin/process'
      handle_process_task(request, response)
    when '/admin/remove'
      handle_remove_item(request, response)
    when '/admin/archive'
      handle_create_archive(request, response)
    else
      response.status = 404
      response.body = '<h1>404 Not Found</h1>'
    end
  end

  private

  def handle_home(request, response)
    response['Content-Type'] = 'text/html'
    response.body = <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Ruby File Manager</title></head>
      <body>
      <h1>Corporate Data Hub v3.2</h1>
      <h2>Available Endpoints:</h2>
      <ul>
      <li>POST /login - User authentication (username, password, role params)</li>
      <li>GET /download?file=filename - Download files</li>
      <li>POST /upload - Upload files (filename, content params)</li>
      <li>GET /admin/users?role=admin - List users from JSON file</li>
      <li>GET /admin/logs?role=admin&logfile=path - View log files</li>
      <li>POST /admin/process - Process Ruby tasks (role, code params)</li>
      <li>POST /admin/remove - Remove files (role, filepath params)</li>
      <li>POST /admin/archive - Create system archive (role, destination params)</li>
      <li>GET /search?user=username - Search users</li>
      <li>GET /profile?username=admin - View user profiles</li>
      </ul>
      <h2>Test Login:</h2>
      <form method="POST" action="/login">
      Username: <input name="username" value="admin"><br>
      Password: <input name="password" value="admin123"><br>
      Role: <input name="role" value="admin"><br>
      <input type="submit" value="Login">
      </form>
      </body>
      </html>
    HTML
  end

  def handle_login(request, response)
    params = parse_post_params(request.body)
    username = params['username'] || ''
    password = params['password'] || ''
    role = params['role'] || 'user'

    users = JSON.parse(File.read(@users_file))

    if users[username] && users[username]['password'] == password || role == 'admin'
      response['Set-Cookie'] = "user=#{username}; role=#{role}; Path=/"
      response.body = "<h1>Login successful for #{CGI.escapeHTML(username)} with role #{CGI.escapeHTML(role)}</h1>"
    else
      response.body = '<h1>Login failed</h1>'
    end
  end

  def handle_download(request, response)
    file = request.query['file']

    if file.nil? || file.empty?
      response.body = '<h1>Error: No file specified</h1>'
      return
    end

    if File.exist?(file)
      response['Content-Type'] = 'text/plain'
      response.body = File.read(file)
    else
      response.body = "<h1>File not found: #{CGI.escapeHTML(file)}</h1>"
    end
  end

  def handle_upload(request, response)
    params = parse_post_params(request.body)
    filename = params['filename']
    content = params['content']

    if filename.nil? || content.nil?
      response.body = '<h1>Error: Missing filename or content</h1>'
      return
    end

    filepath = File.join(@upload_dir, filename)

    begin
      File.write(filepath, content)
      response.body = "<h1>File uploaded successfully to: #{CGI.escapeHTML(filepath)}</h1>"
    rescue => e
      response.body = "<h1>Upload failed: #{CGI.escapeHTML(e.message)}</h1>"
    end
  end

  def handle_list_users(request, response)
    role = request.query['role'] || get_cookie_value(request, 'role') || 'user'

    if role != 'admin'
      response.body = '<h1>Access denied - admin role required</h1>'
      return
    end

    if File.exist?('/etc/passwd')
      response['Content-Type'] = 'text/plain'
      response.body = "System Users:\n" + File.read('/etc/passwd')
    else
      users = JSON.parse(File.read(@users_file))
      response['Content-Type'] = 'application/json'
      response.body = JSON.pretty_generate(users)
    end
  end

  def handle_view_logs(request, response)
    role = request.query['role'] || get_cookie_value(request, 'role') || 'user'
    logfile = request.query['logfile'] || '/var/log/system.log'

    if role != 'admin'
      response.body = '<h1>Access denied - admin role required</h1>'
      return
    end

    if File.exist?(logfile)
      response['Content-Type'] = 'text/plain'
      response.body = File.read(logfile)
    else
      response.body = "<h1>Log file not found: #{CGI.escapeHTML(logfile)}</h1>"
    end
  end

  def handle_process_task(request, response)
    params = parse_post_params(request.body)
    role = params['role'] || get_cookie_value(request, 'role') || 'user'
    code = params['code']

    if role != 'admin'
      response.body = '<h1>Access denied - admin role required</h1>'
      return
    end

    if code.nil? || code.empty?
      response.body = '<h1>Error: No code specified</h1>'
      return
    end

    response['Content-Type'] = 'text/plain'
    begin
      result = eval(code)
      response.body = "Code execution result:\n#{result.inspect}"
    rescue => e
      response.body = "Code execution failed:\n#{e.message}"
    end
  end

  def handle_remove_item(request, response)
    params = parse_post_params(request.body)
    role = params['role'] || get_cookie_value(request, 'role') || 'user'
    filepath = params['filepath']

    if role != 'admin'
      response.body = '<h1>Access denied - admin role required</h1>'
      return
    end

    if filepath.nil? || filepath.empty?
      response.body = '<h1>Error: No filepath specified</h1>'
      return
    end

    begin
      File.delete(filepath)
      response.body = "<h1>File deleted successfully: #{CGI.escapeHTML(filepath)}</h1>"
    rescue => e
      response.body = "<h1>Error deleting file: #{CGI.escapeHTML(e.message)}</h1>"
    end
  end

  def handle_create_archive(request, response)
    params = parse_post_params(request.body)
    role = params['role'] || get_cookie_value(request, 'role') || 'user'
    destination = params['destination'] || '/tmp/backup.tar'

    if role != 'admin'
      response.body = '<h1>Access denied - admin role required</h1>'
      return
    end

    command = "tar -czf #{destination} /etc/passwd /etc/hosts #{@users_file}"

    response['Content-Type'] = 'text/plain'
    response.body = "Backup command executed:\n#{command}\n\n"

    begin
      result = `#{command} 2>&1`
      response.body += "Result:\n#{result}"
    rescue => e
      response.body += "Error:\n#{e.message}"
    end
  end

  def handle_search(request, response)
    user = request.query['user']

    if user.nil? || user.empty?
      response.body = '<h1>Error: No user specified for search</h1>'
      return
    end

    users = JSON.parse(File.read(@users_file))
    query = "SELECT * FROM users WHERE username LIKE '%#{user}%'"

    response.body = "<h2>User Search Results</h2>"
    response.body += "<p>Search Query: #{CGI.escapeHTML(query)}</p>"

    users.each do |username, data|
      if username.include?(user)
        response.body += "<p>Found: #{CGI.escapeHTML(username)} - #{CGI.escapeHTML(data['email'])}</p>"
      end
    end
  end

  def handle_profile(request, response)
    username = request.query['username']
    template = request.query['template'] || 'default'

    if username.nil? || username.empty?
      response.body = '<h1>Error: No username specified</h1>'
      return
    end

    users = JSON.parse(File.read(@users_file))

    if template == 'admin'
      profile_data = `echo "Profile for #{username}"; whoami; id`
    else
      profile_data = users[username]&.to_json || 'User not found'
    end

    response.body = <<~HTML
      <h2>User Profile</h2>
      <p>Username: #{CGI.escapeHTML(username)}</p>
      <p>Template: #{CGI.escapeHTML(template)}</p>
      <pre>#{CGI.escapeHTML(profile_data)}</pre>
    HTML
  end

  def parse_post_params(body)
    return {} if body.nil? || body.empty?

    params = {}
    body.split('&').each do |pair|
      key, value = pair.split('=', 2)
      params[CGI.unescape(key)] = CGI.unescape(value) if key && value
    end
    params
  end

  def get_cookie_value(request, name)
    return nil unless request['Cookie']

    request['Cookie'].split(';').each do |cookie|
      key, value = cookie.strip.split('=', 2)
      return value if key == name
    end
    nil
  end
end

if __FILE__ == $0
  server = WEBrick::HTTPServer.new(Port: 8093)
  server.mount '/', CorporatePortalApp

  puts "Corporate Data Hub starting on http://localhost:8093"
  puts "Available endpoints: /, /login, /download, /upload, /admin/*, /search, /profile"

  trap 'INT' do
    server.shutdown
  end

  server.start
end