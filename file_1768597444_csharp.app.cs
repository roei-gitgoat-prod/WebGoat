using System;
using System.IO;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Diagnostics;
using System.Web;

public class csharp_app
{
    private static HttpListener listener;

    public static async Task Main(string[] args)
    {
        listener = new HttpListener();
        listener.Prefixes.Add("http://localhost:8085/");
        listener.Start();

        Console.WriteLine("C# server running on http://localhost:8085");

        while (true)
        {
            HttpListenerContext context = await listener.GetContextAsync();
            _ = Task.Run(() => HandleRequest(context));
        }
    }

    private static async Task HandleRequest(HttpListenerContext context)
    {
        HttpListenerRequest request = context.Request;
        HttpListenerResponse response = context.Response;

        try
        {
            string responseText = "";

            if (request.HttpMethod == "GET")
            {
                responseText = await HandleGetRequest(request);
            }
            else if (request.HttpMethod == "POST")
            {
                responseText = await HandlePostRequest(request);
            }
            else
            {
                response.StatusCode = 405;
                responseText = "Method not allowed";
            }

            byte[] buffer = Encoding.UTF8.GetBytes(responseText);
            response.ContentLength64 = buffer.Length;
            response.ContentType = "text/html";

            await response.OutputStream.WriteAsync(buffer, 0, buffer.Length);
            response.OutputStream.Close();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error handling request: {ex.Message}");
        }
    }

    private static async Task<string> HandleGetRequest(HttpListenerRequest request)
    {
        string path = request.Url.AbsolutePath;
        var queryParams = HttpUtility.ParseQueryString(request.Url.Query);

        switch (path)
        {
            case "/":
                return GetHomePage();
            case "/download":
                return await DownloadFile(queryParams["file"]);
            case "/admin/info":
                return GetSystemInfo(queryParams["role"]);
            default:
                return "<h1>404 Not Found</h1>";
        }
    }

    private static async Task<string> HandlePostRequest(HttpListenerRequest request)
    {
        string path = request.Url.AbsolutePath;
        string body = "";

        using (var reader = new StreamReader(request.InputStream, request.ContentEncoding))
        {
            body = await reader.ReadToEndAsync();
        }

        switch (path)
        {
            case "/admin/delete":
                return DeleteFile(body);
            case "/admin/execute":
                return ExecuteCommand(body);
            case "/upload":
                return UploadFile(body);
            default:
                return "<h1>404 Not Found</h1>";
        }
    }

    private static string GetHomePage()
    {
        return @"
            <h1>C# Application</h1>
            <h2>Available Endpoints:</h2>
            <ul>
                <li>GET /download?file=filename - Download files</li>
                <li>GET /admin/info?role=admin - System information</li>
                <li>POST /admin/delete - Delete files (role and filepath params)</li>
                <li>POST /admin/execute - Execute commands (role and command params)</li>
                <li>POST /upload - Upload files (filename and content params)</li>
            </ul>";
    }

    private static async Task<string> DownloadFile(string filename)
    {
        if (string.IsNullOrEmpty(filename))
        {
            return "<h1>Error: No filename specified</h1>";
        }

        try
        {
            string content = await File.ReadAllTextAsync(filename);
            return $"<pre>{HttpUtility.HtmlEncode(content)}</pre>";
        }
        catch (FileNotFoundException)
        {
            return "<h1>File not found</h1>";
        }
        catch (Exception ex)
        {
            return $"<h1>Error reading file: {HttpUtility.HtmlEncode(ex.Message)}</h1>";
        }
    }

    private static string GetSystemInfo(string role)
    {
        if (role != "admin")
        {
            return "<h1>Access Denied - Admin role required</h1>";
        }

        try
        {
            var info = new StringBuilder();
            info.AppendLine("<h2>System Information</h2>");
            info.AppendLine($"<p>Machine Name: {Environment.MachineName}</p>");
            info.AppendLine($"<p>User Name: {Environment.UserName}</p>");
            info.AppendLine($"<p>OS Version: {Environment.OSVersion}</p>");
            info.AppendLine($"<p>Current Directory: {Environment.CurrentDirectory}</p>");

            if (File.Exists("/etc/passwd"))
            {
                string users = File.ReadAllText("/etc/passwd");
                info.AppendLine("<h3>System Users:</h3>");
                info.AppendLine($"<pre>{HttpUtility.HtmlEncode(users)}</pre>");
            }

            return info.ToString();
        }
        catch (Exception ex)
        {
            return $"<h1>Error getting system info: {HttpUtility.HtmlEncode(ex.Message)}</h1>";
        }
    }

    private static string DeleteFile(string body)
    {
        var parameters = ParseFormData(body);
        string role = parameters.GetValueOrDefault("role", "user");
        string filepath = parameters.GetValueOrDefault("filepath", "");

        if (role != "admin")
        {
            return "<h1>Access Denied - Admin role required</h1>";
        }

        if (string.IsNullOrEmpty(filepath))
        {
            return "<h1>Error: No filepath specified</h1>";
        }

        try
        {
            File.Delete(filepath);
            return $"<h1>File deleted successfully: {HttpUtility.HtmlEncode(filepath)}</h1>";
        }
        catch (Exception ex)
        {
            return $"<h1>Error deleting file: {HttpUtility.HtmlEncode(ex.Message)}</h1>";
        }
    }

    private static string ExecuteCommand(string body)
    {
        var parameters = ParseFormData(body);
        string role = parameters.GetValueOrDefault("role", "user");
        string command = parameters.GetValueOrDefault("command", "");

        if (role != "admin")
        {
            return "<h1>Access Denied - Admin role required</h1>";
        }

        if (string.IsNullOrEmpty(command))
        {
            return "<h1>Error: No command specified</h1>";
        }

        try
        {
            ProcessStartInfo startInfo = new ProcessStartInfo()
            {
                FileName = "/bin/bash",
                Arguments = $"-c \"{command}\"",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            if (Environment.OSVersion.Platform == PlatformID.Win32NT)
            {
                startInfo.FileName = "cmd.exe";
                startInfo.Arguments = $"/c {command}";
            }

            using (Process process = Process.Start(startInfo))
            {
                process.WaitForExit();
                string output = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();

                return $"<h2>Command Output:</h2><pre>{HttpUtility.HtmlEncode(output + error)}</pre>";
            }
        }
        catch (Exception ex)
        {
            return $"<h1>Command execution failed: {HttpUtility.HtmlEncode(ex.Message)}</h1>";
        }
    }

    private static string UploadFile(string body)
    {
        var parameters = ParseFormData(body);
        string filename = parameters.GetValueOrDefault("filename", "");
        string content = parameters.GetValueOrDefault("content", "");

        if (string.IsNullOrEmpty(filename) || string.IsNullOrEmpty(content))
        {
            return "<h1>Error: Missing filename or content</h1>";
        }

        try
        {
            string uploadPath = Path.Combine("/tmp", filename);
            File.WriteAllText(uploadPath, content);

            return $"<h1>File uploaded successfully to: {HttpUtility.HtmlEncode(uploadPath)}</h1>";
        }
        catch (Exception ex)
        {
            return $"<h1>Upload failed: {HttpUtility.HtmlEncode(ex.Message)}</h1>";
        }
    }

    private static Dictionary<string, string> ParseFormData(string data)
    {
        var parameters = new Dictionary<string, string>();
        string[] pairs = data.Split('&');

        foreach (string pair in pairs)
        {
            string[] keyValue = pair.Split('=');
            if (keyValue.Length == 2)
            {
                string key = HttpUtility.UrlDecode(keyValue[0]);
                string value = HttpUtility.UrlDecode(keyValue[1]);
                parameters[key] = value;
            }
        }

        return parameters;
    }
}

