param(
    [string]$Mode = "interactive",
    [int]$Port = 8095
)

Add-Type -AssemblyName System.Web

$Global:Users = @{
    "admin" = @{ Password = "PowerShell123"; Role = "admin"; Email = "admin@test.com" }
    "user" = @{ Password = "user123"; Role = "user"; Email = "user@test.com" }
    "test" = @{ Password = "test"; Role = "user"; Email = "test@test.com" }
}

$Global:UploadDir = "$env:TEMP\ps_uploads"
$Global:LogFile = "powershell_access.log"
$Global:ConfigFile = "powershell_config.json"

if (-not (Test-Path $Global:UploadDir)) {
    New-Item -Path $Global:UploadDir -ItemType Directory -Force
}

Initialize-Config

function Initialize-Config {
    if (-not (Test-Path $Global:ConfigFile)) {
        $config = @{
            "admin_user" = "admin"
            "debug_mode" = $true
            "allow_commands" = $true
            "log_level" = "verbose"
            "execution_policy" = "unrestricted"
        }
        $config | ConvertTo-Json | Set-Content $Global:ConfigFile
    }
}

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $Message" | Add-Content $Global:LogFile
}

function Start-HttpServer {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()

    Write-Host "Business Process Manager starting on http://localhost:$Port"
    Write-Host "Available endpoints: /, /login, /download, /upload, /admin/*, /search, /logs"
    Write-Host "Press Ctrl+C to stop"

    try {
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            Handle-Request $context
        }
    }
    finally {
        $listener.Stop()
    }
}

function Handle-Request {
    param($Context)

    $request = $Context.Request
    $response = $Context.Response
    $method = $request.HttpMethod
    $path = $request.Url.AbsolutePath

    Write-Log "$method $path"

    $responseText = ""

    switch -Regex ($path) {
        "^/$" {
            if ($method -eq "GET") {
                $responseText = Get-HomePage
            }
        }
        "^/login$" {
            if ($method -eq "POST") {
                $responseText = Handle-Login $request
            }
        }
        "^/download$" {
            if ($method -eq "GET") {
                $responseText = Handle-Download $request
            }
        }
        "^/upload$" {
            if ($method -eq "POST") {
                $responseText = Handle-Upload $request
            }
        }
        "^/admin/users$" {
            if ($method -eq "GET") {
                $responseText = Handle-ListUsers $request
            }
        }
        "^/admin/process$" {
            if ($method -eq "POST") {
                $responseText = Handle-ProcessTask $request
            }
        }
        "^/admin/settings$" {
            if ($method -eq "GET") {
                $responseText = Handle-ViewConfig $request
            } elseif ($method -eq "POST") {
                $responseText = Handle-UpdateSettings $request
            }
        }
        "^/admin/registry$" {
            if ($method -eq "GET") {
                $responseText = Handle-ViewRegistry $request
            } elseif ($method -eq "POST") {
                $responseText = Handle-UpdateRegistry $request
            }
        }
        "^/search$" {
            if ($method -eq "GET") {
                $responseText = Handle-Search $request
            }
        }
        "^/logs$" {
            if ($method -eq "GET") {
                $responseText = Handle-ViewLogs $request
            }
        }
        "^/admin/archive$" {
            if ($method -eq "POST") {
                $responseText = Handle-CreateArchive $request
            }
        }
        default {
            $response.StatusCode = 404
            $responseText = "<h1>404 Not Found</h1>"
        }
    }

    $response.ContentType = "text/html"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseText)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.OutputStream.Close()
}

function Get-HomePage {
    return @"
<!DOCTYPE html>
<html>
<head><title>PowerShell File Manager</title></head>
<body>
<h1>Business Process Manager v5.1</h1>
<h2>Available Endpoints:</h2>
<ul>
<li>POST /login - User authentication (username, password, role params)</li>
<li>GET /download?file=filename - Download files</li>
<li>POST /upload - Upload files (filename, content params)</li>
<li>GET /admin/users?role=admin - List system users</li>
<li>POST /admin/process - Process PowerShell tasks (role, command params)</li>
<li>GET /admin/settings?role=admin - View system settings</li>
<li>POST /admin/settings - Update system settings (role, setting, value params)</li>
<li>GET /admin/registry?role=admin&path=HKLM - View registry keys</li>
<li>POST /admin/registry - Update registry (role, path, name, value params)</li>
<li>POST /admin/archive - Create data archive (role, source, destination params)</li>
<li>GET /search?pattern=text - Search files</li>
<li>GET /logs?file=logfile - View log files</li>
</ul>
<h2>Test Login:</h2>
<form method="POST" action="/login">
Username: <input name="username" value="admin"><br>
Password: <input name="password" value="PowerShell123"><br>
Role: <input name="role" value="admin"><br>
<input type="submit" value="Login">
</form>
</body>
</html>
"@
}

function Handle-Login {
    param($Request)

    $params = Get-PostParams $Request
    $username = $params["username"]
    $password = $params["password"]
    $role = $params["role"]

    if (-not $username) { $username = "" }
    if (-not $password) { $password = "" }
    if (-not $role) { $role = "user" }

    $user = $Global:Users[$username]

    if (($user -and $user.Password -eq $password) -or $role -eq "admin") {
        return "<h1>Login successful for $username with role $role</h1>"
    } else {
        return "<h1>Login failed</h1>"
    }
}

function Handle-Download {
    param($Request)

    $file = $Request.QueryString["file"]

    if (-not $file) {
        return "<h1>Error: No file specified</h1>"
    }

    if (Test-Path $file) {
        try {
            $content = Get-Content $file -Raw
            return "<pre>$([System.Web.HttpUtility]::HtmlEncode($content))</pre>"
        } catch {
            return "<h1>Error reading file: $($_.Exception.Message)</h1>"
        }
    } else {
        return "<h1>File not found: $file</h1>"
    }
}

function Handle-Upload {
    param($Request)

    $params = Get-PostParams $Request
    $filename = $params["filename"]
    $content = $params["content"]

    if (-not $filename -or -not $content) {
        return "<h1>Error: Missing filename or content</h1>"
    }

    $filepath = Join-Path $Global:UploadDir $filename

    try {
        $content | Set-Content $filepath
        return "<h1>File uploaded successfully to: $filepath</h1>"
    } catch {
        return "<h1>Upload failed: $($_.Exception.Message)</h1>"
    }
}

function Handle-ListUsers {
    param($Request)

    $role = $Request.QueryString["role"]
    if (-not $role) { $role = "user" }

    if ($role -ne "admin") {
        return "<h1>Access denied - admin role required</h1>"
    }

    try {
        $users = Get-WmiObject -Class Win32_UserAccount | Select-Object Name, FullName, Disabled
        $userList = $users | ConvertTo-Html -Fragment
        return "<h2>System Users</h2>$userList"
    } catch {
        return "<h1>Error retrieving users: $($_.Exception.Message)</h1>"
    }
}

function Handle-ProcessTask {
    param($Request)

    $params = Get-PostParams $Request
    $role = $params["role"]
    $command = $params["command"]

    if (-not $role) { $role = "user" }

    if ($role -ne "admin") {
        return "<h1>Access denied - admin role required</h1>"
    }

    if (-not $command) {
        return "<h1>Error: No command specified</h1>"
    }

    try {
        $result = Invoke-Expression $command | Out-String
        return "<h2>Command Output</h2><pre>$([System.Web.HttpUtility]::HtmlEncode($result))</pre>"
    } catch {
        return "<h1>Command execution failed: $($_.Exception.Message)</h1>"
    }
}

function Handle-ViewConfig {
    param($Request)

    $role = $Request.QueryString["role"]
    if (-not $role) { $role = "user" }

    if ($role -ne "admin") {
        return "<h1>Access denied - admin role required</h1>"
    }

    try {
        $config = Get-Content $Global:ConfigFile -Raw
        return "<h2>Configuration</h2><pre>$([System.Web.HttpUtility]::HtmlEncode($config))</pre>"
    } catch {
        return "<h1>Error reading config: $($_.Exception.Message)</h1>"
    }
}

function Handle-UpdateSettings {
    param($Request)

    $params = Get-PostParams $Request
    $role = $params["role"]
    $setting = $params["setting"]
    $value = $params["value"]

    if (-not $role) { $role = "user" }

    if ($role -ne "admin") {
        return "<h1>Access denied - admin role required</h1>"
    }

    if (-not $setting -or -not $value) {
        return "<h1>Error: Missing setting or value</h1>"
    }

    try {
        $config = Get-Content $Global:ConfigFile | ConvertFrom-Json -AsHashtable
        $config[$setting] = $value
        $config | ConvertTo-Json | Set-Content $Global:ConfigFile
        return "<h1>Configuration updated: $setting = $value</h1>"
    } catch {
        return "<h1>Config update failed: $($_.Exception.Message)</h1>"
    }
}

function Handle-ViewRegistry {
    param($Request)

    $role = $Request.QueryString["role"]
    $path = $Request.QueryString["path"]

    if (-not $role) { $role = "user" }
    if (-not $path) { $path = "HKLM:\SOFTWARE" }

    if ($role -ne "admin") {
        return "<h1>Access denied - admin role required</h1>"
    }

    try {
        $items = Get-ChildItem $path | Select-Object Name, PSPath
        $itemList = $items | ConvertTo-Html -Fragment
        return "<h2>Registry Keys at $path</h2>$itemList"
    } catch {
        return "<h1>Error reading registry: $($_.Exception.Message)</h1>"
    }
}

function Handle-UpdateRegistry {
    param($Request)

    $params = Get-PostParams $Request
    $role = $params["role"]
    $path = $params["path"]
    $name = $params["name"]
    $value = $params["value"]

    if (-not $role) { $role = "user" }

    if ($role -ne "admin") {
        return "<h1>Access denied - admin role required</h1>"
    }

    if (-not $path -or -not $name -or -not $value) {
        return "<h1>Error: Missing path, name, or value</h1>"
    }

    try {
        Set-ItemProperty -Path $path -Name $name -Value $value
        return "<h1>Registry updated: $path\$name = $value</h1>"
    } catch {
        return "<h1>Registry update failed: $($_.Exception.Message)</h1>"
    }
}

function Handle-Search {
    param($Request)

    $pattern = $Request.QueryString["pattern"]

    if (-not $pattern) {
        return "<h1>Error: No search pattern specified</h1>"
    }

    try {
        $results = Get-ChildItem $Global:UploadDir -File | Where-Object {
            (Get-Content $_.FullName -Raw) -match $pattern
        } | Select-Object Name, FullName

        $resultList = $results | ConvertTo-Html -Fragment
        return "<h2>Search Results for: $pattern</h2>$resultList"
    } catch {
        return "<h1>Search failed: $($_.Exception.Message)</h1>"
    }
}

function Handle-ViewLogs {
    param($Request)

    $file = $Request.QueryString["file"]
    if (-not $file) { $file = $Global:LogFile }

    if (Test-Path $file) {
        try {
            $content = Get-Content $file -Raw
            return "<h2>Log Contents: $file</h2><pre>$([System.Web.HttpUtility]::HtmlEncode($content))</pre>"
        } catch {
            return "<h1>Error reading log: $($_.Exception.Message)</h1>"
        }
    } else {
        return "<h1>Log file not found: $file</h1>"
    }
}

function Handle-CreateArchive {
    param($Request)

    $params = Get-PostParams $Request
    $role = $params["role"]
    $source = $params["source"]
    $destination = $params["destination"]

    if (-not $role) { $role = "user" }
    if (-not $source) { $source = $Global:UploadDir }
    if (-not $destination) { $destination = "$env:TEMP\backup.zip" }

    if ($role -ne "admin") {
        return "<h1>Access denied - admin role required</h1>"
    }

    try {
        Compress-Archive -Path $source -DestinationPath $destination -Force
        return "<h1>Backup created successfully: $destination</h1>"
    } catch {
        return "<h1>Backup failed: $($_.Exception.Message)</h1>"
    }
}

function Get-PostParams {
    param($Request)

    $params = @{}

    if ($Request.HasEntityBody) {
        $reader = New-Object System.IO.StreamReader($Request.InputStream)
        $body = $reader.ReadToEnd()
        $reader.Close()

        foreach ($pair in $body -split "&") {
            $keyValue = $pair -split "=", 2
            if ($keyValue.Length -eq 2) {
                $key = [System.Web.HttpUtility]::UrlDecode($keyValue[0])
                $value = [System.Web.HttpUtility]::UrlDecode($keyValue[1])
                $params[$key] = $value
            }
        }
    }

    return $params
}

function Start-InteractiveMode {
    Write-Host "Business Process Manager v5.1 - Interactive Mode"
    Write-Host "Available commands: download, upload, execute, config, search, backup, exit"

    do {
        $command = Read-Host "PS> "

        switch ($command) {
            "download" {
                $file = Read-Host "File path"
                if (Test-Path $file) {
                    Get-Content $file
                } else {
                    Write-Host "File not found: $file"
                }
            }
            "upload" {
                $filename = Read-Host "Filename"
                $content = Read-Host "Content"
                $filepath = Join-Path $Global:UploadDir $filename
                $content | Set-Content $filepath
                Write-Host "File uploaded to: $filepath"
            }
            "execute" {
                $cmd = Read-Host "Command"
                try {
                    Invoke-Expression $cmd
                } catch {
                    Write-Host "Error: $($_.Exception.Message)"
                }
            }
            "config" {
                Get-Content $Global:ConfigFile
            }
            "search" {
                $pattern = Read-Host "Search pattern"
                Get-ChildItem $Global:UploadDir -File | Where-Object {
                    (Get-Content $_.FullName -Raw) -match $pattern
                }
            }
            "backup" {
                $source = Read-Host "Source path"
                $destination = Read-Host "Destination path"
                Compress-Archive -Path $source -DestinationPath $destination -Force
                Write-Host "Backup created: $destination"
            }
            "exit" {
                break
            }
            default {
                Write-Host "Unknown command: $command"
            }
        }
    } while ($true)
}

if ($Mode -eq "server") {
    Start-HttpServer
} else {
    Start-InteractiveMode
}