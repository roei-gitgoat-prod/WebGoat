package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	http.HandleFunc("/", homeHandler)
	http.HandleFunc("/read", readFileHandler)
	http.HandleFunc("/admin/system", systemInfoHandler)
	http.HandleFunc("/admin/delete", deleteFileHandler)
	http.HandleFunc("/admin/exec", execCommandHandler)
	http.HandleFunc("/write", writeFileHandler)

	fmt.Println("Go server running on http://localhost:8086")
	log.Fatal(http.ListenAndServe(":8086", nil))
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
	html := `
	<h1>Go Application</h1>
	<h2>Available Endpoints:</h2>
	<ul>
		<li>GET /read?file=filename - Read files</li>
		<li>GET /admin/system?role=admin - System information</li>
		<li>POST /admin/delete - Delete files (role and filepath form params)</li>
		<li>POST /admin/exec - Execute commands (role and command form params)</li>
		<li>POST /write - Write files (filename and content form params)</li>
	</ul>`

	w.Header().Set("Content-Type", "text/html")
	fmt.Fprint(w, html)
}

func readFileHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	filename := r.URL.Query().Get("file")
	if filename == "" {
		http.Error(w, "Missing file parameter", http.StatusBadRequest)
		return
	}

	content, err := os.ReadFile(filename)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error reading file: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	w.Write(content)
}

func systemInfoHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	role := r.URL.Query().Get("role")
	if role != "admin" {
		http.Error(w, "Access denied - admin role required", http.StatusForbidden)
		return
	}

	info := fmt.Sprintf("System Information:\n")
	info += fmt.Sprintf("Hostname: %s\n", getHostname())
	info += fmt.Sprintf("Working Directory: %s\n", getCurrentDir())
	info += fmt.Sprintf("Environment Variables:\n")

	for _, env := range os.Environ() {
		info += fmt.Sprintf("  %s\n", env)
	}

	if content, err := os.ReadFile("/etc/passwd"); err == nil {
		info += fmt.Sprintf("\nSystem Users:\n%s\n", string(content))
	}

	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprint(w, info)
}

func deleteFileHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	err := r.ParseForm()
	if err != nil {
		http.Error(w, "Error parsing form", http.StatusBadRequest)
		return
	}

	role := r.Form.Get("role")
	filepath := r.Form.Get("filepath")

	if role != "admin" {
		http.Error(w, "Access denied - admin role required", http.StatusForbidden)
		return
	}

	if filepath == "" {
		http.Error(w, "Missing filepath parameter", http.StatusBadRequest)
		return
	}

	err = os.Remove(filepath)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error deleting file: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprintf(w, "File deleted successfully: %s", filepath)
}

func execCommandHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	err := r.ParseForm()
	if err != nil {
		http.Error(w, "Error parsing form", http.StatusBadRequest)
		return
	}

	role := r.Form.Get("role")
	command := r.Form.Get("command")

	if role != "admin" {
		http.Error(w, "Access denied - admin role required", http.StatusForbidden)
		return
	}

	if command == "" {
		http.Error(w, "Missing command parameter", http.StatusBadRequest)
		return
	}

	cmd := exec.Command("/bin/sh", "-c", command)
	output, err := cmd.CombinedOutput()
	if err != nil {
		http.Error(w, fmt.Sprintf("Command execution failed: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprintf(w, "Command output:\n%s", string(output))
}

func writeFileHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	err := r.ParseForm()
	if err != nil {
		http.Error(w, "Error parsing form", http.StatusBadRequest)
		return
	}

	filename := r.Form.Get("filename")
	content := r.Form.Get("content")

	if filename == "" || content == "" {
		http.Error(w, "Missing filename or content parameter", http.StatusBadRequest)
		return
	}

	fullPath := filepath.Join("/tmp", filename)

	err = os.WriteFile(fullPath, []byte(content), 0644)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error writing file: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprintf(w, "File written successfully to: %s", fullPath)
}

func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return hostname
}

func getCurrentDir() string {
	dir, err := os.Getwd()
	if err != nil {
		return "unknown"
	}
	return dir
}

