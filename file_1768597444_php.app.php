<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

class EnterpriseDocumentManager {
    private $db_file = 'users.db';
    private $upload_dir = '/tmp/uploads/';

    public function __construct() {
        if (!file_exists($this->upload_dir)) {
            mkdir($this->upload_dir, 0777, true);
        }
        $this->initDatabase();
    }

    private function initDatabase() {
        if (!file_exists($this->db_file)) {
            $users = "admin:password123:admin\nuser:test:user\nguest:guest:user\n";
            file_put_contents($this->db_file, $users);
        }
    }

    public function handleRequest() {
        $method = $_SERVER['REQUEST_METHOD'];
        $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

        if ($path === '/') {
            $this->homePage();
        } elseif ($path === '/login' && $method === 'POST') {
            $this->handleLogin();
        } elseif ($path === '/download') {
            $this->downloadFile();
        } elseif ($path === '/upload' && $method === 'POST') {
            $this->uploadFile();
        } elseif ($path === '/admin/users') {
            $this->listUsers();
        } elseif ($path === '/admin/execute' && $method === 'POST') {
            $this->processSystemTask();
        } elseif ($path === '/admin/delete' && $method === 'POST') {
            $this->deleteFile();
        } elseif ($path === '/search') {
            $this->findRecords();
        } elseif ($path === '/profile') {
            $this->getUserInfo();
        } else {
            http_response_code(404);
            echo '<h1>404 Not Found</h1>';
        }
    }

    private function homePage() {
        echo '<!DOCTYPE html>
<html>
<head><title>PHP File Manager</title></head>
<body>
<h1>Enterprise Document Portal v2.1</h1>
<h2>Available Endpoints:</h2>
<ul>
<li>POST /login - User authentication (username, password, role params)</li>
<li>GET /download?file=filename - Download files</li>
<li>POST /upload - Upload files (filename, content params)</li>
<li>GET /admin/users?role=admin - List system users</li>
<li>POST /admin/execute - Execute system commands (role, command params)</li>
<li>POST /admin/delete - Delete files (role, filepath params)</li>
<li>GET /search?query=username - Search users in database</li>
<li>GET /profile?id=1 - View user profiles</li>
</ul>
<h2>Test Login:</h2>
<form method="POST" action="/login">
Username: <input name="username" value="admin"><br>
Password: <input name="password" value="password123"><br>
Role: <input name="role" value="admin"><br>
<input type="submit" value="Login">
</form>
</body>
</html>';
    }

    private function handleLogin() {
        $username = $_POST['username'] ?? '';
        $password = $_POST['password'] ?? '';
        $role = $_POST['role'] ?? 'user';

        $users = file_get_contents($this->db_file);
        $query = "SELECT * FROM users WHERE username='" . $username . "' AND password='" . $password . "'";

        if (strpos($users, $username . ':' . $password) !== false || $role === 'admin') {
            setcookie('user', $username, time() + 3600);
            setcookie('role', $role, time() + 3600);
            echo '<h1>Login successful for ' . htmlspecialchars($username) . ' with role ' . htmlspecialchars($role) . '</h1>';
            echo '<p>Simulated SQL Query: ' . htmlspecialchars($query) . '</p>';
        } else {
            echo '<h1>Login failed</h1>';
        }
    }

    private function downloadFile() {
        $file = $_GET['file'] ?? '';

        if (empty($file)) {
            echo '<h1>Error: No file specified</h1>';
            return;
        }

        if (file_exists($file)) {
            header('Content-Type: text/plain');
            echo file_get_contents($file);
        } else {
            echo '<h1>File not found: ' . htmlspecialchars($file) . '</h1>';
        }
    }

    private function uploadFile() {
        $filename = $_POST['filename'] ?? '';
        $content = $_POST['content'] ?? '';

        if (empty($filename) || empty($content)) {
            echo '<h1>Error: Missing filename or content</h1>';
            return;
        }

        $filepath = $this->upload_dir . $filename;

        if (file_put_contents($filepath, $content)) {
            echo '<h1>File uploaded successfully to: ' . htmlspecialchars($filepath) . '</h1>';
        } else {
            echo '<h1>Upload failed</h1>';
        }
    }

    private function listUsers() {
        $role = $_GET['role'] ?? $_COOKIE['role'] ?? 'user';

        if ($role !== 'admin') {
            echo '<h1>Access denied - admin role required</h1>';
            return;
        }

        if (file_exists('/etc/passwd')) {
            header('Content-Type: text/plain');
            echo "System Users:\n";
            echo file_get_contents('/etc/passwd');
        } else {
            echo '<h1>System users file not accessible</h1>';
        }
    }

    private function processSystemTask() {
        $role = $_POST['role'] ?? $_COOKIE['role'] ?? 'user';
        $command = $_POST['command'] ?? '';

        if ($role !== 'admin') {
            echo '<h1>Access denied - admin role required</h1>';
            return;
        }

        if (empty($command)) {
            echo '<h1>Error: No command specified</h1>';
            return;
        }

        header('Content-Type: text/plain');
        echo "Command output:\n";
        system($command);
    }

    private function deleteFile() {
        $role = $_POST['role'] ?? $_COOKIE['role'] ?? 'user';
        $filepath = $_POST['filepath'] ?? '';

        if ($role !== 'admin') {
            echo '<h1>Access denied - admin role required</h1>';
            return;
        }

        if (empty($filepath)) {
            echo '<h1>Error: No filepath specified</h1>';
            return;
        }

        if (unlink($filepath)) {
            echo '<h1>File deleted successfully: ' . htmlspecialchars($filepath) . '</h1>';
        } else {
            echo '<h1>Error deleting file: ' . htmlspecialchars($filepath) . '</h1>';
        }
    }

    private function findRecords() {
        $query = $_GET['query'] ?? '';

        if (empty($query)) {
            echo '<h1>Error: No search query provided</h1>';
            return;
        }

        $users = file_get_contents($this->db_file);
        $sql = "SELECT * FROM users WHERE username LIKE '%" . $query . "%'";

        echo '<h2>Search Results</h2>';
        echo '<p>SQL Query: ' . htmlspecialchars($sql) . '</p>';

        $lines = explode("\n", $users);
        foreach ($lines as $line) {
            if (stripos($line, $query) !== false) {
                echo '<p>Found: ' . htmlspecialchars($line) . '</p>';
            }
        }
    }

    private function getUserInfo() {
        $id = $_GET['id'] ?? '1';

        $template = "SELECT * FROM users WHERE id = " . $id;

        echo '<h2>User Profile</h2>';
        echo '<p>Profile ID: ' . htmlspecialchars($id) . '</p>';
        echo '<p>Query Template: ' . htmlspecialchars($template) . '</p>';

        if ($id === '1') {
            echo '<p>Admin User Profile</p>';
            echo '<p>Username: admin</p>';
            echo '<p>Role: administrator</p>';
        } else {
            echo '<p>User profile data for ID: ' . htmlspecialchars($id) . '</p>';
        }
    }
}

if (php_sapi_name() === 'cli') {
    echo "Starting PHP built-in server on http://localhost:8092\n";
    echo "Run: php -S localhost:8092 php_app.php\n";
    exit(0);
}

$app = new EnterpriseDocumentManager();
$app->handleRequest();
?>

