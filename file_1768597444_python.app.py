#!/usr/bin/env python3

import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

class AppHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed_url = urlparse(self.path)
        query_params = parse_qs(parsed_url.query)

        if parsed_url.path == '/download':
            filename = query_params.get('file', [''])[0]
            self.serve_file(filename)
        elif parsed_url.path == '/admin/list_users':
            role = query_params.get('role', ['user'])[0]
            self.list_users(role)
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'<h1>Python App</h1>')
            self.wfile.write(b'<p>Endpoints: /download?file=filename, /admin/list_users?role=admin</p>')

    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length).decode('utf-8')

        parsed_url = urlparse(self.path)

        if parsed_url.path == '/admin/delete_file':
            self.delete_file(post_data)
        elif parsed_url.path == '/admin/execute':
            self.execute_command(post_data)
        else:
            self.send_response(404)
            self.end_headers()

    def serve_file(self, filename):
        try:
            with open(filename, 'r') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(content.encode())
        except FileNotFoundError:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'File not found')
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def list_users(self, role):
        if role != 'admin':
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b'Access denied')
            return

        try:
            with open('/etc/passwd', 'r') as f:
                users = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(users.encode())
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def delete_file(self, post_data):
        params = self.parse_post_data(post_data)
        role = params.get('role', 'user')
        filepath = params.get('filepath', '')

        if role != 'admin':
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b'Access denied')
            return

        try:
            os.remove(filepath)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f'File {filepath} deleted successfully'.encode())
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def execute_command(self, post_data):
        params = self.parse_post_data(post_data)
        role = params.get('role', 'user')
        command = params.get('command', '')

        if role != 'admin':
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b'Access denied')
            return

        try:
            result = subprocess.run(command, shell=True, capture_output=True, text=True)
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(result.stdout.encode())
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def parse_post_data(self, data):
        params = {}
        for pair in data.split('&'):
            if '=' in pair:
                key, value = pair.split('=', 1)
                params[key] = value
        return params

def main():
    server = HTTPServer(('localhost', 8082), AppHandler)
    print("Python server running on http://localhost:8082")
    server.serve_forever()

if __name__ == '__main__':
    main()

