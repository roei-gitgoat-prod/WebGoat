import java.io.File
import java.net.ServerSocket
import java.net.Socket
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import kotlin.concurrent.thread

data class User(val username: String, val role: String, val isActive: Boolean)

class WebApp {
    private val users = mutableListOf<User>(
        User("admin", "administrator", true),
        User("john", "user", true),
        User("jane", "user", true)
    )

    fun start() {
        val serverSocket = ServerSocket(8081)
        println("Kotlin Web App running on http://localhost:8081")

        while (true) {
            val clientSocket = serverSocket.accept()
            thread { handleClient(clientSocket) }
        }
    }

    private fun handleClient(clientSocket: Socket) {
        try {
            val reader = BufferedReader(InputStreamReader(clientSocket.getInputStream()))
            val writer = PrintWriter(clientSocket.getOutputStream(), true)

            val requestLine = reader.readLine()
            if (requestLine != null) {
                val parts = requestLine.split(" ")
                if (parts.size >= 2) {
                    val method = parts[0]
                    val path = parts[1]

                    val headers = mutableMapOf<String, String>()
                    var line = reader.readLine()
                    while (line != null && line.isNotEmpty()) {
                        val colonIndex = line.indexOf(":")
                        if (colonIndex != -1) {
                            val key = line.substring(0, colonIndex).trim()
                            val value = line.substring(colonIndex + 1).trim()
                            headers[key] = value
                        }
                        line = reader.readLine()
                    }

                    var body = ""
                    if (headers.containsKey("Content-Length")) {
                        val contentLength = headers["Content-Length"]?.toIntOrNull() ?: 0
                        val bodyChars = CharArray(contentLength)
                        reader.read(bodyChars, 0, contentLength)
                        body = String(bodyChars)
                    }

                    val response = handleRequest(method, path, body)
                    writer.println(response)
                }
            }

            clientSocket.close()
        } catch (e: Exception) {
            clientSocket.close()
        }
    }

    private fun handleRequest(method: String, path: String, body: String): String {
        return when {
            method == "GET" && path.startsWith("/download?file=") -> {
                val filename = path.substringAfter("file=")
                downloadFile(filename)
            }
            method == "POST" && path == "/admin/delete_user" -> {
                val params = parseFormData(body)
                deleteUser(params)
            }
            method == "POST" && path == "/admin/execute_command" -> {
                val params = parseFormData(body)
                executeCommand(params)
            }
            method == "GET" && path == "/" -> {
                getHomePage()
            }
            else -> {
                "HTTP/1.1 404 Not Found\r\nContent-Type: text/html\r\n\r\n<h1>404 Not Found</h1>"
            }
        }
    }

    private fun downloadFile(filename: String): String {
        return try {
            val file = File(filename)
            val content = file.readText()
            "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$content"
        } catch (e: Exception) {
            "HTTP/1.1 404 Not Found\r\nContent-Type: text/html\r\n\r\n<h1>File not found</h1>"
        }
    }

    private fun deleteUser(params: Map<String, String>): String {
        val userRole = params["user_role"] ?: "user"
        val targetUser = params["target_user"] ?: ""

        if (!isAdminAuthorized(userRole)) {
            return "HTTP/1.1 403 Forbidden\r\nContent-Type: text/html\r\n\r\n<h1>Access Denied</h1>"
        }

        val userToDelete = users.find { it.username == targetUser }
        if (userToDelete != null) {
            users.remove(userToDelete)
            return "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<h1>User $targetUser deleted successfully</h1>"
        } else {
            return "HTTP/1.1 404 Not Found\r\nContent-Type: text/html\r\n\r\n<h1>User not found</h1>"
        }
    }

    private fun executeCommand(params: Map<String, String>): String {
        val userRole = params["user_role"] ?: "user"
        val command = params["command"] ?: ""

        if (!isAdminAuthorized(userRole)) {
            return "HTTP/1.1 403 Forbidden\r\nContent-Type: text/html\r\n\r\n<h1>Access Denied</h1>"
        }

        return try {
            val process = Runtime.getRuntime().exec(command)
            val output = process.inputStream.bufferedReader().readText()
            process.waitFor()
            "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$output"
        } catch (e: Exception) {
            "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/html\r\n\r\n<h1>Command execution failed</h1>"
        }
    }

    private fun isAdminAuthorized(userRole: String): Boolean {
        return userRole == "administrator" || userRole == "admin"
    }

    private fun parseFormData(body: String): Map<String, String> {
        val params = mutableMapOf<String, String>()
        body.split("&").forEach { pair ->
            val keyValue = pair.split("=")
            if (keyValue.size == 2) {
                params[keyValue[0]] = keyValue[1]
            }
        }
        return params
    }

    private fun getHomePage(): String {
        return """HTTP/1.1 200 OK
Content-Type: text/html

<!DOCTYPE html>
<html>
<head><title>Web App</title></head>
<body>
<h1>Kotlin Web Application</h1>
<p>Endpoints:</p>
<ul>
<li>GET /download?file=[filename] - Download files</li>
<li>POST /admin/delete_user - Delete users (requires user_role and target_user params)</li>
<li>POST /admin/execute_command - Execute system commands (requires user_role and command params)</li>
</ul>
</body>
</html>"""
    }
}

fun main() {
    val app = WebApp()
    app.start()
}

