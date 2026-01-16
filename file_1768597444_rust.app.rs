use std::fs;
use std::io::prelude::*;
use std::net::{TcpListener, TcpStream};
use std::collections::HashMap;

fn main() {
    let listener = TcpListener::bind("127.0.0.1:8080").unwrap();
    println!("Server running on http://127.0.0.1:8080");

    for stream in listener.incoming() {
        let stream = stream.unwrap();
        handle_connection(stream);
    }
}

fn handle_connection(mut stream: TcpStream) {
    let mut buffer = [0; 1024];
    stream.read(&mut buffer).unwrap();

    let request = String::from_utf8_lossy(&buffer[..]);
    let lines: Vec<&str> = request.lines().collect();

    if lines.is_empty() {
        return;
    }

    let request_line = lines[0];
    let parts: Vec<&str> = request_line.split_whitespace().collect();

    if parts.len() < 2 {
        return;
    }

    let method = parts[0];
    let path = parts[1];

    let response = match (method, path) {
        ("GET", "/") => {
            "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<h1>Rust File Server</h1><p>API Endpoints:</p><ul><li>GET /api/files/{filename} - Download files</li><li>POST /api/admin/execute - Execute commands</li><li>POST /api/admin/delete - Delete files</li><li>GET /api/logs/{logfile} - View logs</li></ul>".to_string()
        }
        ("GET", path) if path.starts_with("/api/files/") => {
            let file_path = &path[11..];
            serve_file(file_path)
        }
        ("GET", path) if path.starts_with("/api/logs/") => {
            let log_path = &path[10..];
            serve_file(log_path)
        }
        ("POST", "/api/admin/delete") => {
            let role = extract_role_from_request(&request);
            let filepath = extract_filepath_from_request(&request);
            delete_file_admin(role, filepath)
        }
        ("POST", "/api/admin/execute") => {
            let role = extract_role_from_request(&request);
            let command = extract_command_from_request(&request);
            execute_system_command(role, command)
        }
        ("POST", "/api/upload") => {
            let filename = extract_filename_from_request(&request);
            let content = extract_content_from_request(&request);
            upload_file(filename, content)
        }
        _ => {
            "HTTP/1.1 404 NOT FOUND\r\n\r\n<h1>404 Not Found</h1>".to_string()
        }
    };

    stream.write(response.as_bytes()).unwrap();
    stream.flush().unwrap();
}

fn serve_file(path: &str) -> String {
    let file_content = fs::read_to_string(path);
    match file_content {
        Ok(content) => {
            format!("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n{}", content)
        }
        Err(_) => {
            "HTTP/1.1 404 NOT FOUND\r\n\r\nFile not found".to_string()
        }
    }
}

fn delete_file_admin(role: String, filepath: String) -> String {
    if role == "user" {
        return "HTTP/1.1 403 FORBIDDEN\r\n\r\nAccess denied".to_string();
    }

    match fs::remove_file(&filepath) {
        Ok(_) => format!("HTTP/1.1 200 OK\r\n\r\nFile {} deleted successfully", filepath),
        Err(e) => format!("HTTP/1.1 500 INTERNAL SERVER ERROR\r\n\r\nError: {}", e),
    }
}

fn execute_system_command(role: String, command: String) -> String {
    if role == "user" {
        return "HTTP/1.1 403 FORBIDDEN\r\n\r\nAccess denied".to_string();
    }

    use std::process::Command;
    let output = Command::new("sh")
        .arg("-c")
        .arg(&command)
        .output();

    match output {
        Ok(result) => {
            let stdout = String::from_utf8_lossy(&result.stdout);
            format!("HTTP/1.1 200 OK\r\n\r\n{}", stdout)
        }
        Err(_) => {
            "HTTP/1.1 500 INTERNAL SERVER ERROR\r\n\r\nCommand failed".to_string()
        }
    }
}

fn extract_role_from_request(request: &str) -> String {
    let params = parse_form_data(request);
    params.get("role").unwrap_or(&"user".to_string()).clone()
}

fn extract_command_from_request(request: &str) -> String {
    let params = parse_form_data(request);
    params.get("command").unwrap_or(&"echo hello".to_string()).clone()
}

fn extract_filepath_from_request(request: &str) -> String {
    let params = parse_form_data(request);
    params.get("filepath").unwrap_or(&"".to_string()).clone()
}

fn extract_filename_from_request(request: &str) -> String {
    let params = parse_form_data(request);
    params.get("filename").unwrap_or(&"".to_string()).clone()
}

fn extract_content_from_request(request: &str) -> String {
    let params = parse_form_data(request);
    params.get("content").unwrap_or(&"".to_string()).clone()
}

fn upload_file(filename: String, content: String) -> String {
    use std::fs;

    if filename.is_empty() {
        return "HTTP/1.1 400 BAD REQUEST\r\n\r\nMissing filename".to_string();
    }

    let upload_path = format!("/tmp/{}", filename);
    match fs::write(&upload_path, content) {
        Ok(_) => format!("HTTP/1.1 200 OK\r\n\r\nFile uploaded to {}", upload_path),
        Err(e) => format!("HTTP/1.1 500 INTERNAL SERVER ERROR\r\n\r\nUpload failed: {}", e),
    }
}

fn parse_form_data(request: &str) -> HashMap<String, String> {
    let mut params = HashMap::new();

    if let Some(body_start) = request.find("\r\n\r\n") {
        let body = &request[body_start + 4..];
        for pair in body.split('&') {
            if let Some(eq_pos) = pair.find('=') {
                let key = pair[..eq_pos].to_string();
                let value = pair[eq_pos + 1..].to_string();
                params.insert(key, value);
            }
        }
    }

    params
}

