#!/usr/bin/env lua

local socket = require("socket")
local lfs = require("lfs")
local json = require("json")

local PORT = 8096
local UPLOAD_DIR = "/tmp/lua_uploads"
local CONFIG_FILE = "lua_config.json"
local LOG_FILE = "lua_access.log"

local users = {
    admin = { password = "lua123", role = "admin", email = "admin@test.com" },
    user = { password = "user123", role = "user", email = "user@test.com" },
    guest = { password = "guest", role = "user", email = "guest@test.com" }
}

local function create_directory(path)
    local success, err = lfs.mkdir(path)
    if not success and err ~= "File exists" then
        print("Warning: Could not create directory " .. path .. ": " .. (err or "unknown error"))
    end
end

local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil, "Could not open file: " .. path
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function write_file(path, content)
    local file = io.open(path, "w")
    if not file then
        return false, "Could not open file for writing: " .. path
    end
    file:write(content)
    file:close()
    return true
end

local function append_file(path, content)
    local file = io.open(path, "a")
    if not file then
        return false, "Could not open file for appending: " .. path
    end
    file:write(content)
    file:close()
    return true
end

local function log_request(method, path, query)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] %s %s %s\n", timestamp, method, path, query or "")
    append_file(LOG_FILE, log_entry)
end

local function url_decode(str)
    if not str then return nil end
    str = string.gsub(str, "+", " ")
    str = string.gsub(str, "%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
    return str
end

local function parse_query_string(query)
    local params = {}
    if not query then return params end

    for pair in string.gmatch(query, "[^&]+") do
        local key, value = string.match(pair, "([^=]+)=?(.*)")
        if key then
            params[url_decode(key)] = url_decode(value)
        end
    end
    return params
end

local function parse_post_data(data)
    return parse_query_string(data)
end

local function html_escape(str)
    if not str then return "" end
    str = string.gsub(str, "&", "&amp;")
    str = string.gsub(str, "<", "&lt;")
    str = string.gsub(str, ">", "&gt;")
    str = string.gsub(str, '"', "&quot;")
    str = string.gsub(str, "'", "&#39;")
    return str
end

local function init_config()
    if not file_exists(CONFIG_FILE) then
        local config = {
            debug_mode = true,
            allow_lua_exec = true,
            log_level = "verbose",
            max_upload_size = 1048576
        }
        local config_json = json.encode(config)
        write_file(CONFIG_FILE, config_json)
    end
end

local function get_home_page()
    return [[
<!DOCTYPE html>
<html>
<head><title>Lua File Manager</title></head>
<body>
<h1>Digital Asset Manager v6.3</h1>
<h2>Available Endpoints:</h2>
<ul>
<li>POST /login - User authentication (username, password, role params)</li>
<li>GET /download?file=filename - Download files</li>
<li>POST /upload - Upload files (filename, content params)</li>
<li>GET /admin/users?role=admin - List system users</li>
<li>POST /admin/process - Process Lua tasks (role, code params)</li>
<li>GET /admin/settings?role=admin - View system settings</li>
<li>POST /admin/settings - Update system settings (role, setting, value params)</li>
<li>POST /admin/script - Execute system scripts (role, script, args params)</li>
<li>GET /search?pattern=text - Search files</li>
<li>GET /logs?file=logfile - View log files</li>
<li>POST /admin/archive - Create data archive (role, source, destination params)</li>
</ul>
<h2>Test Login:</h2>
<form method="POST" action="/login">
Username: <input name="username" value="admin"><br>
Password: <input name="password" value="lua123"><br>
Role: <input name="role" value="admin"><br>
<input type="submit" value="Login">
</form>
</body>
</html>]]
end

local function handle_login(post_data)
    local params = parse_post_data(post_data)
    local username = params.username or ""
    local password = params.password or ""
    local role = params.role or "user"

    local user = users[username]

    if (user and user.password == password) or role == "admin" then
        return string.format("<h1>Login successful for %s with role %s</h1>",
                           html_escape(username), html_escape(role))
    else
        return "<h1>Login failed</h1>"
    end
end

local function handle_download(params)
    local file = params.file

    if not file then
        return "<h1>Error: No file specified</h1>"
    end

    local content, err = read_file(file)
    if content then
        return string.format("<h2>File: %s</h2><pre>%s</pre>",
                           html_escape(file), html_escape(content))
    else
        return string.format("<h1>Error reading file: %s</h1>", html_escape(err))
    end
end

local function handle_upload(post_data)
    local params = parse_post_data(post_data)
    local filename = params.filename
    local content = params.content

    if not filename or not content then
        return "<h1>Error: Missing filename or content</h1>"
    end

    local filepath = UPLOAD_DIR .. "/" .. filename
    local success, err = write_file(filepath, content)

    if success then
        return string.format("<h1>File uploaded successfully to: %s</h1>", html_escape(filepath))
    else
        return string.format("<h1>Upload failed: %s</h1>", html_escape(err))
    end
end

local function handle_list_users(params)
    local role = params.role or "user"

    if role ~= "admin" then
        return "<h1>Access denied - admin role required</h1>"
    end

    if file_exists("/etc/passwd") then
        local content = read_file("/etc/passwd")
        if content then
            return string.format("<h2>System Users</h2><pre>%s</pre>", html_escape(content))
        end
    end

    local user_list = "<h2>Application Users</h2><ul>"
    for username, user_data in pairs(users) do
        user_list = user_list .. string.format("<li>%s (%s) - %s</li>",
                                              html_escape(username),
                                              html_escape(user_data.role),
                                              html_escape(user_data.email))
    end
    user_list = user_list .. "</ul>"

    return user_list
end

local function handle_process_task(post_data)
    local params = parse_post_data(post_data)
    local role = params.role or "user"
    local code = params.code

    if role ~= "admin" then
        return "<h1>Access denied - admin role required</h1>"
    end

    if not code then
        return "<h1>Error: No code specified</h1>"
    end

    local func, err = load(code)
    if not func then
        return string.format("<h1>Code compilation failed: %s</h1>", html_escape(err))
    end

    local success, result = pcall(func)
    if success then
        return string.format("<h2>Code Execution Result</h2><pre>%s</pre>",
                           html_escape(tostring(result or "nil")))
    else
        return string.format("<h1>Code execution failed: %s</h1>", html_escape(result))
    end
end

local function handle_view_settings(params)
    local role = params.role or "user"

    if role ~= "admin" then
        return "<h1>Access denied - admin role required</h1>"
    end

    local content, err = read_file(CONFIG_FILE)
    if content then
        return string.format("<h2>Configuration</h2><pre>%s</pre>", html_escape(content))
    else
        return string.format("<h1>Error reading config: %s</h1>", html_escape(err))
    end
end

local function handle_update_settings(post_data)
    local params = parse_post_data(post_data)
    local role = params.role or "user"
    local setting = params.setting
    local value = params.value

    if role ~= "admin" then
        return "<h1>Access denied - admin role required</h1>"
    end

    if not setting or not value then
        return "<h1>Error: Missing setting or value</h1>"
    end

    local config_content, err = read_file(CONFIG_FILE)
    if not config_content then
        return string.format("<h1>Error reading config: %s</h1>", html_escape(err))
    end

    local config = json.decode(config_content)
    config[setting] = value

    local success, write_err = write_file(CONFIG_FILE, json.encode(config))
    if success then
        return string.format("<h1>Configuration updated: %s = %s</h1>",
                           html_escape(setting), html_escape(value))
    else
        return string.format("<h1>Config update failed: %s</h1>", html_escape(write_err))
    end
end

local function handle_script_runner(post_data)
    local params = parse_post_data(post_data)
    local role = params.role or "user"
    local script = params.script
    local args = params.args or ""

    if role ~= "admin" then
        return "<h1>Access denied - admin role required</h1>"
    end

    if not script then
        return "<h1>Error: No script specified</h1>"
    end

    local command = string.format("%s %s", script, args)
    local handle = io.popen(command .. " 2>&1")
    if not handle then
        return "<h1>Error: Could not execute script</h1>"
    end

    local result = handle:read("*all")
    handle:close()

    return string.format("<h2>Script Execution Result</h2><pre>%s</pre>", html_escape(result))
end

local function handle_search(params)
    local pattern = params.pattern

    if not pattern then
        return "<h1>Error: No search pattern specified</h1>"
    end

    local results = "<h2>Search Results</h2><ul>"
    local found_any = false

    for file in lfs.dir(UPLOAD_DIR) do
        if file ~= "." and file ~= ".." then
            local filepath = UPLOAD_DIR .. "/" .. file
            local attr = lfs.attributes(filepath)
            if attr and attr.mode == "file" then
                local content = read_file(filepath)
                if content and string.find(content, pattern, 1, true) then
                    results = results .. string.format("<li>%s</li>", html_escape(file))
                    found_any = true
                end
            end
        end
    end

    if not found_any then
        results = results .. "<li>No files found matching pattern</li>"
    end

    results = results .. "</ul>"
    return results
end

local function handle_view_logs(params)
    local file = params.file or LOG_FILE

    local content, err = read_file(file)
    if content then
        return string.format("<h2>Log Contents: %s</h2><pre>%s</pre>",
                           html_escape(file), html_escape(content))
    else
        return string.format("<h1>Error reading log: %s</h1>", html_escape(err))
    end
end

local function handle_create_archive(post_data)
    local params = parse_post_data(post_data)
    local role = params.role or "user"
    local source = params.source or UPLOAD_DIR
    local destination = params.destination or "/tmp/lua_backup.tar.gz"

    if role ~= "admin" then
        return "<h1>Access denied - admin role required</h1>"
    end

    local command = string.format("tar -czf %s %s %s %s", destination, source, CONFIG_FILE, LOG_FILE)
    local handle = io.popen(command .. " 2>&1")
    if not handle then
        return "<h1>Error: Could not execute backup command</h1>"
    end

    local result = handle:read("*all")
    handle:close()

    return string.format("<h2>Backup Created</h2><p>Command: %s</p><pre>%s</pre>",
                        html_escape(command), html_escape(result))
end

local function parse_http_request(request)
    local method, path, protocol = string.match(request, "^(%w+)%s+([^%s]+)%s+(.-)$")
    if not method then
        return nil
    end

    local url_parts = {}
    local query_string = nil

    if string.find(path, "?") then
        url_parts.path, query_string = string.match(path, "^([^?]+)%?(.*)$")
    else
        url_parts.path = path
    end

    return {
        method = method,
        path = url_parts.path,
        query_string = query_string,
        protocol = protocol
    }
end

local function handle_request(client, request_line, headers, body)
    local request = parse_http_request(request_line)
    if not request then
        client:send("HTTP/1.1 400 Bad Request\r\n\r\n<h1>400 Bad Request</h1>")
        return
    end

    log_request(request.method, request.path, request.query_string)

    local params = parse_query_string(request.query_string)
    local response_body = ""
    local status = "200 OK"

    if request.path == "/" and request.method == "GET" then
        response_body = get_home_page()
    elseif request.path == "/login" and request.method == "POST" then
        response_body = handle_login(body)
    elseif request.path == "/download" and request.method == "GET" then
        response_body = handle_download(params)
    elseif request.path == "/upload" and request.method == "POST" then
        response_body = handle_upload(body)
    elseif request.path == "/admin/users" and request.method == "GET" then
        response_body = handle_list_users(params)
    elseif request.path == "/admin/process" and request.method == "POST" then
        response_body = handle_process_task(body)
    elseif request.path == "/admin/settings" and request.method == "GET" then
        response_body = handle_view_settings(params)
    elseif request.path == "/admin/settings" and request.method == "POST" then
        response_body = handle_update_settings(body)
    elseif request.path == "/admin/script" and request.method == "POST" then
        response_body = handle_script_runner(body)
    elseif request.path == "/search" and request.method == "GET" then
        response_body = handle_search(params)
    elseif request.path == "/logs" and request.method == "GET" then
        response_body = handle_view_logs(params)
    elseif request.path == "/admin/archive" and request.method == "POST" then
        response_body = handle_create_archive(body)
    else
        status = "404 Not Found"
        response_body = "<h1>404 Not Found</h1>"
    end

    local response = string.format("HTTP/1.1 %s\r\nContent-Type: text/html\r\nContent-Length: %d\r\n\r\n%s",
                                  status, #response_body, response_body)
    client:send(response)
end

local function start_server()
    create_directory(UPLOAD_DIR)
    init_config()

    local server = socket.bind("127.0.0.1", PORT)
    if not server then
        print("Error: Could not bind to port " .. PORT)
        return
    end

    print("Digital Asset Manager starting on http://localhost:" .. PORT)
    print("Available endpoints: /, /login, /download, /upload, /admin/*, /search, /logs")
    print("Press Ctrl+C to stop")

    while true do
        local client = server:accept()
        if client then
            client:settimeout(10)

            local request_line = client:receive()
            if request_line then
                local headers = {}
                local content_length = 0

                while true do
                    local header = client:receive()
                    if not header or header == "" then
                        break
                    end
                    table.insert(headers, header)
                    local length = string.match(header, "Content%-Length:%s*(%d+)")
                    if length then
                        content_length = tonumber(length)
                    end
                end

                local body = ""
                if content_length > 0 then
                    body = client:receive(content_length) or ""
                end

                handle_request(client, request_line, headers, body)
            end

            client:close()
        end
    end
end

local function start_interactive()
    print("Lua File Manager v1.0 - Interactive Mode")
    print("Available commands: download, upload, execute, config, search, backup, exit")

    while true do
        io.write("lua> ")
        io.flush()
        local command = io.read()

        if command == "exit" then
            break
        elseif command == "download" then
            io.write("File path: ")
            io.flush()
            local file = io.read()
            local content = read_file(file)
            if content then
                print(content)
            else
                print("File not found: " .. file)
            end
        elseif command == "upload" then
            io.write("Filename: ")
            io.flush()
            local filename = io.read()
            io.write("Content: ")
            io.flush()
            local content = io.read()
            local filepath = UPLOAD_DIR .. "/" .. filename
            if write_file(filepath, content) then
                print("File uploaded to: " .. filepath)
            else
                print("Upload failed")
            end
        elseif command == "execute" then
            io.write("Lua code: ")
            io.flush()
            local code = io.read()
            local func, err = load(code)
            if func then
                local success, result = pcall(func)
                if success then
                    print(result)
                else
                    print("Error: " .. result)
                end
            else
                print("Compilation error: " .. err)
            end
        elseif command == "config" then
            local content = read_file(CONFIG_FILE)
            if content then
                print(content)
            else
                print("Could not read config file")
            end
        else
            print("Unknown command: " .. command)
        end
    end
end

if arg and arg[1] == "server" then
    start_server()
else
    start_interactive()
end