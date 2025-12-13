const http = require('http');
const url = require('url');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    const query = parsedUrl.query;

    if (req.method === 'GET') {
        if (pathname === '/') {
            handleHomePage(req, res);
        } else if (pathname === '/file') {
            handleFileRead(req, res, query);
        } else if (pathname === '/admin/users') {
            handleAdminUsers(req, res, query);
        } else {
            sendNotFound(res);
        }
    } else if (req.method === 'POST') {
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });
        req.on('end', () => {
            if (pathname === '/admin/delete') {
                handleAdminDelete(req, res, body);
            } else if (pathname === '/admin/command') {
                handleAdminCommand(req, res, body);
            } else if (pathname === '/upload') {
                handleFileUpload(req, res, body);
            } else {
                sendNotFound(res);
            }
        });
    } else {
        sendNotFound(res);
    }
});

function handleHomePage(req, res) {
    const html = `
        <h1>Node.js Application</h1>
        <h2>Available Endpoints:</h2>
        <ul>
            <li>GET /file?path=filename - Read files</li>
            <li>GET /admin/users?role=admin - List users</li>
            <li>POST /admin/delete - Delete files (role and filepath params)</li>
            <li>POST /admin/command - Execute commands (role and cmd params)</li>
            <li>POST /upload - Upload files (filename and content params)</li>
        </ul>
    `;
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
}

function handleFileRead(req, res, query) {
    const filePath = query.path;

    if (!filePath) {
        res.writeHead(400, { 'Content-Type': 'text/plain' });
        res.end('Missing path parameter');
        return;
    }

    fs.readFile(filePath, 'utf8', (err, data) => {
        if (err) {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('File not found: ' + err.message);
        } else {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end(data);
        }
    });
}

function handleAdminUsers(req, res, query) {
    const userRole = query.role || 'user';

    if (userRole !== 'admin') {
        res.writeHead(403, { 'Content-Type': 'text/plain' });
        res.end('Access denied - admin role required');
        return;
    }

    fs.readFile('/etc/passwd', 'utf8', (err, data) => {
        if (err) {
            res.writeHead(500, { 'Content-Type': 'text/plain' });
            res.end('Error reading user data: ' + err.message);
        } else {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end('System users:\n' + data);
        }
    });
}

function handleAdminDelete(req, res, body) {
    const params = parseFormData(body);
    const role = params.role || 'user';
    const filepath = params.filepath;

    if (role !== 'admin') {
        res.writeHead(403, { 'Content-Type': 'text/plain' });
        res.end('Access denied - admin role required');
        return;
    }

    if (!filepath) {
        res.writeHead(400, { 'Content-Type': 'text/plain' });
        res.end('Missing filepath parameter');
        return;
    }

    fs.unlink(filepath, (err) => {
        if (err) {
            res.writeHead(500, { 'Content-Type': 'text/plain' });
            res.end('Error deleting file: ' + err.message);
        } else {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end('File deleted successfully: ' + filepath);
        }
    });
}

function handleAdminCommand(req, res, body) {
    const params = parseFormData(body);
    const role = params.role || 'user';
    const command = params.cmd;

    if (role !== 'admin') {
        res.writeHead(403, { 'Content-Type': 'text/plain' });
        res.end('Access denied - admin role required');
        return;
    }

    if (!command) {
        res.writeHead(400, { 'Content-Type': 'text/plain' });
        res.end('Missing cmd parameter');
        return;
    }

    exec(command, (error, stdout, stderr) => {
        if (error) {
            res.writeHead(500, { 'Content-Type': 'text/plain' });
            res.end('Command failed: ' + error.message);
        } else {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end('Command output:\n' + stdout + stderr);
        }
    });
}

function handleFileUpload(req, res, body) {
    const params = parseFormData(body);
    const filename = params.filename;
    const content = params.content;

    if (!filename || !content) {
        res.writeHead(400, { 'Content-Type': 'text/plain' });
        res.end('Missing filename or content parameter');
        return;
    }

    const uploadPath = path.join('/tmp', filename);

    fs.writeFile(uploadPath, content, (err) => {
        if (err) {
            res.writeHead(500, { 'Content-Type': 'text/plain' });
            res.end('Upload failed: ' + err.message);
        } else {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end('File uploaded successfully to: ' + uploadPath);
        }
    });
}

function parseFormData(data) {
    const params = {};
    const pairs = data.split('&');
    for (const pair of pairs) {
        const [key, value] = pair.split('=');
        if (key && value) {
            params[decodeURIComponent(key)] = decodeURIComponent(value);
        }
    }
    return params;
}

function sendNotFound(res) {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('404 Not Found');
}

const PORT = 8083;
server.listen(PORT, () => {
    console.log(`Node.js server running on http://localhost:${PORT}`);
});
