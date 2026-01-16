import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

public class java_app {
    private static final int PORT = 8084;
    private static ExecutorService executor = Executors.newFixedThreadPool(10);

    public static void main(String[] args) {
        try {
            ServerSocket serverSocket = new ServerSocket(PORT);
            System.out.println("Java server running on http://localhost:" + PORT);

            while (true) {
                Socket clientSocket = serverSocket.accept();
                executor.submit(new ClientHandler(clientSocket));
            }
        } catch (IOException e) {
            System.err.println("Server error: " + e.getMessage());
        }
    }

    static class ClientHandler implements Runnable {
        private Socket clientSocket;

        public ClientHandler(Socket socket) {
            this.clientSocket = socket;
        }

        @Override
        public void run() {
            try (BufferedReader in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
                 PrintWriter out = new PrintWriter(clientSocket.getOutputStream(), true)) {

                String requestLine = in.readLine();
                if (requestLine != null) {
                    String[] parts = requestLine.split(" ");
                    if (parts.length >= 2) {
                        String method = parts[0];
                        String path = parts[1];

                        Map<String, String> headers = new HashMap<>();
                        String line;
                        while ((line = in.readLine()) != null && !line.isEmpty()) {
                            int colonIndex = line.indexOf(":");
                            if (colonIndex != -1) {
                                String key = line.substring(0, colonIndex).trim();
                                String value = line.substring(colonIndex + 1).trim();
                                headers.put(key, value);
                            }
                        }

                        String body = "";
                        if (headers.containsKey("Content-Length")) {
                            int contentLength = Integer.parseInt(headers.get("Content-Length"));
                            char[] bodyChars = new char[contentLength];
                            in.read(bodyChars, 0, contentLength);
                            body = new String(bodyChars);
                        }

                        String response = handleRequest(method, path, body);
                        out.println(response);
                    }
                }

                clientSocket.close();
            } catch (IOException e) {
                System.err.println("Client handler error: " + e.getMessage());
            }
        }

        private String handleRequest(String method, String path, String body) {
            if ("GET".equals(method)) {
                if (path.equals("/")) {
                    return getHomePage();
                } else if (path.startsWith("/read?file=")) {
                    String filename = path.substring(11);
                    return readFile(filename);
                } else if (path.startsWith("/admin/system?role=")) {
                    String role = extractParameter(path, "role");
                    return getSystemInfo(role);
                }
            } else if ("POST".equals(method)) {
                if (path.equals("/admin/delete")) {
                    return deleteFile(body);
                } else if (path.equals("/admin/exec")) {
                    return executeCommand(body);
                } else if (path.equals("/log")) {
                    return writeLog(body);
                }
            }

            return "HTTP/1.1 404 Not Found\r\nContent-Type: text/html\r\n\r\n<h1>404 Not Found</h1>";
        }

        private String getHomePage() {
            return "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n" +
                   "<h1>Java Application</h1>" +
                   "<h2>Endpoints:</h2>" +
                   "<ul>" +
                   "<li>GET /read?file=filename - Read files</li>" +
                   "<li>GET /admin/system?role=admin - System info</li>" +
                   "<li>POST /admin/delete - Delete files</li>" +
                   "<li>POST /admin/exec - Execute commands</li>" +
                   "<li>POST /log - Write logs</li>" +
                   "</ul>";
        }

        private String readFile(String filename) {
            try {
                Path filePath = Paths.get(filename);
                String content = Files.readString(filePath);
                return "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n" + content;
            } catch (IOException e) {
                return "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\nFile not found: " + e.getMessage();
            }
        }

        private String getSystemInfo(String role) {
            if (!"admin".equals(role)) {
                return "HTTP/1.1 403 Forbidden\r\nContent-Type: text/plain\r\n\r\nAccess denied - admin role required";
            }

            try {
                Properties props = System.getProperties();
                StringBuilder info = new StringBuilder();
                info.append("System Information:\n");
                info.append("OS: ").append(props.getProperty("os.name")).append("\n");
                info.append("User: ").append(props.getProperty("user.name")).append("\n");
                info.append("Home: ").append(props.getProperty("user.home")).append("\n");
                info.append("Java Version: ").append(props.getProperty("java.version")).append("\n");

                String passwd = Files.readString(Paths.get("/etc/passwd"));
                info.append("\nUsers:\n").append(passwd);

                return "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n" + info.toString();
            } catch (Exception e) {
                return "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\n\r\nError: " + e.getMessage();
            }
        }

        private String deleteFile(String body) {
            Map<String, String> params = parseFormData(body);
            String role = params.getOrDefault("role", "user");
            String filepath = params.get("filepath");

            if (!"admin".equals(role)) {
                return "HTTP/1.1 403 Forbidden\r\nContent-Type: text/plain\r\n\r\nAccess denied - admin role required";
            }

            if (filepath == null) {
                return "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nMissing filepath parameter";
            }

            try {
                Files.delete(Paths.get(filepath));
                return "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nFile deleted successfully: " + filepath;
            } catch (IOException e) {
                return "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\n\r\nError deleting file: " + e.getMessage();
            }
        }

        private String executeCommand(String body) {
            Map<String, String> params = parseFormData(body);
            String role = params.getOrDefault("role", "user");
            String command = params.get("command");

            if (!"admin".equals(role)) {
                return "HTTP/1.1 403 Forbidden\r\nContent-Type: text/plain\r\n\r\nAccess denied - admin role required";
            }

            if (command == null) {
                return "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nMissing command parameter";
            }

            try {
                Process process = Runtime.getRuntime().exec(command);
                BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
                StringBuilder output = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
                process.waitFor();

                return "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nCommand output:\n" + output.toString();
            } catch (Exception e) {
                return "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\n\r\nCommand failed: " + e.getMessage();
            }
        }

        private String writeLog(String body) {
            Map<String, String> params = parseFormData(body);
            String logfile = params.get("logfile");
            String message = params.get("message");

            if (logfile == null || message == null) {
                return "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nMissing logfile or message parameter";
            }

            try {
                String timestamp = new Date().toString();
                String logEntry = timestamp + ": " + message + "\n";
                Files.write(Paths.get(logfile), logEntry.getBytes(), StandardOpenOption.CREATE, StandardOpenOption.APPEND);

                return "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nLog written to: " + logfile;
            } catch (IOException e) {
                return "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\n\r\nError writing log: " + e.getMessage();
            }
        }

        private String extractParameter(String path, String param) {
            int paramIndex = path.indexOf(param + "=");
            if (paramIndex != -1) {
                int valueStart = paramIndex + param.length() + 1;
                int valueEnd = path.indexOf("&", valueStart);
                if (valueEnd == -1) valueEnd = path.length();
                return path.substring(valueStart, valueEnd);
            }
            return "";
        }

        private Map<String, String> parseFormData(String data) {
            Map<String, String> params = new HashMap<>();
            String[] pairs = data.split("&");
            for (String pair : pairs) {
                String[] keyValue = pair.split("=", 2);
                if (keyValue.length == 2) {
                    params.put(keyValue[0], keyValue[1]);
                }
            }
            return params;
        }
    }
}

