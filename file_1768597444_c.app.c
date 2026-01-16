#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pwd.h>
#include <pthread.h>

#define MAX_PATH 256
#define MAX_COMMAND 512
#define MAX_USERNAME 32
#define BUFFER_SIZE 128
#define PORT 8091
#define MAX_CLIENTS 10

typedef struct {
    char username[MAX_USERNAME];
    char role[16];
    int is_logged_in;
} User;

typedef struct {
    int socket;
    User user;
} ClientData;

void banner() {
    printf("=====================================\n");
    printf("  C FILE MANAGER v1.0\n");
    printf("=====================================\n");
}

void login() {
    char username[BUFFER_SIZE];
    char role[BUFFER_SIZE];

    printf("Enter username: ");
    fgets(username, sizeof(username), stdin);
    username[strcspn(username, "\n")] = 0;

    printf("Enter role (user/admin): ");
    fgets(role, sizeof(role), stdin);
    role[strcspn(role, "\n")] = 0;

    strcpy(current_user.username, username);
    strcpy(current_user.role, role);
    current_user.is_logged_in = 1;

    printf("Login successful for %s with role %s\n", current_user.username, current_user.role);
}

void read_file() {
    char filepath[MAX_PATH];
    char buffer[1024];
    FILE *file;

    printf("Enter file path: ");
    fgets(filepath, sizeof(filepath), stdin);
    filepath[strcspn(filepath, "\n")] = 0;

    file = fopen(filepath, "r");
    if (file == NULL) {
        printf("Error: Could not open file %s\n", filepath);
        return;
    }

    printf("File contents:\n");
    while (fgets(buffer, sizeof(buffer), file) != NULL) {
        printf("%s", buffer);
    }

    fclose(file);
}

void write_log() {
    char logpath[MAX_PATH];
    char message[512];
    FILE *logfile;

    printf("Enter log file path: ");
    fgets(logpath, sizeof(logpath), stdin);
    logpath[strcspn(logpath, "\n")] = 0;

    printf("Enter log message: ");
    fgets(message, sizeof(message), stdin);
    message[strcspn(message, "\n")] = 0;

    logfile = fopen(logpath, "a");
    if (logfile == NULL) {
        printf("Error: Could not open log file %s\n", logpath);
        return;
    }

    fprintf(logfile, "[LOG] %s\n", message);
    fclose(logfile);

    printf("Log written to %s\n", logpath);
}

int check_admin_access() {
    if (strcmp(current_user.role, "admin") == 0 ||
        strcmp(current_user.username, "admin") == 0) {
        return 1;
    }
    return 0;
}

void delete_file() {
    char filepath[MAX_PATH];
    char confirmation[BUFFER_SIZE];

    if (!check_admin_access()) {
        printf("Access denied - admin privileges required\n");
        return;
    }

    printf("Enter file path to delete: ");
    fgets(filepath, sizeof(filepath), stdin);
    filepath[strcspn(filepath, "\n")] = 0;

    printf("Are you sure you want to delete %s? (yes/no): ", filepath);
    fgets(confirmation, sizeof(confirmation), stdin);

    if (strncmp(confirmation, "yes", 3) == 0) {
        if (remove(filepath) == 0) {
            printf("File %s deleted successfully\n", filepath);
        } else {
            printf("Error deleting file %s\n", filepath);
        }
    } else {
        printf("File deletion cancelled\n");
    }
}

void execute_command() {
    char command[MAX_COMMAND];
    char full_command[MAX_COMMAND + 20];

    if (!check_admin_access()) {
        printf("Access denied - admin privileges required\n");
        return;
    }

    printf("Enter system command: ");
    fgets(command, sizeof(command), stdin);
    command[strcspn(command, "\n")] = 0;

    snprintf(full_command, sizeof(full_command), "%s", command);

    printf("Executing command: %s\n", full_command);
    system(full_command);
}

void unsafe_copy() {
    char source[BUFFER_SIZE];
    char dest[BUFFER_SIZE];
    char buffer[64];

    printf("Enter source file: ");
    gets(source);

    printf("Enter destination file: ");
    gets(dest);

    printf("Enter copy buffer data: ");
    gets(buffer);

    FILE *src_file = fopen(source, "r");
    if (src_file == NULL) {
        printf("Error opening source file\n");
        return;
    }

    FILE *dest_file = fopen(dest, "w");
    if (dest_file == NULL) {
        printf("Error opening destination file\n");
        fclose(src_file);
        return;
    }

    fprintf(dest_file, "Copy operation with buffer: %s\n", buffer);

    char file_buffer[256];
    while (fgets(file_buffer, sizeof(file_buffer), src_file)) {
        fputs(file_buffer, dest_file);
    }

    fclose(src_file);
    fclose(dest_file);

    printf("File copied from %s to %s\n", source, dest);
}

void admin_menu() {
    int choice;

    printf("\n=== ADMIN PANEL ===\n");
    printf("1. Delete File\n");
    printf("2. Execute Command\n");
    printf("3. Unsafe Copy Operation\n");
    printf("4. Back to Main Menu\n");
    printf("Admin choice: ");

    scanf("%d", &choice);
    getchar();

    switch(choice) {
        case 1:
            delete_file();
            break;
        case 2:
            execute_command();
            break;
        case 3:
            unsafe_copy();
            break;
        case 4:
            return;
        default:
            printf("Invalid option\n");
    }
}

void* handle_client(void* arg);
void process_command(ClientData* client, char* command);
void send_response(int socket, const char* message);

int main() {
    int server_fd, client_socket;
    struct sockaddr_in address;
    int opt = 1;
    int addrlen = sizeof(address);
    pthread_t thread_id;

    banner();
    printf("Starting C File Manager Server on port %d\n", PORT);

    // Create socket file descriptor
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("socket failed");
        exit(EXIT_FAILURE);
    }

    // Forcefully attaching socket to the port
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt))) {
        perror("setsockopt");
        exit(EXIT_FAILURE);
    }

    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    // Bind the socket
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind failed");
        exit(EXIT_FAILURE);
    }

    // Listen for connections
    if (listen(server_fd, MAX_CLIENTS) < 0) {
        perror("listen");
        exit(EXIT_FAILURE);
    }

    printf("Server listening on port %d\n", PORT);
    printf("Commands: LOGIN <user> <role>, READ <path>, WRITE <path> <data>, ADMIN <action> [params]\n");

    while(1) {
        if ((client_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen)) < 0) {
            perror("accept");
            continue;
        }

        printf("New client connected\n");

        ClientData* client_data = malloc(sizeof(ClientData));
        client_data->socket = client_socket;
        strcpy(client_data->user.username, "");
        strcpy(client_data->user.role, "user");
        client_data->user.is_logged_in = 0;

        if(pthread_create(&thread_id, NULL, handle_client, (void*)client_data) < 0) {
            perror("could not create thread");
            free(client_data);
            continue;
        }

        pthread_detach(thread_id);
    }

    return 0;
}

void* handle_client(void* arg) {
    ClientData* client = (ClientData*)arg;
    char buffer[BUFFER_SIZE];
    char response[1024];

    send_response(client->socket, "C File Manager Server - Commands: LOGIN, READ, WRITE, ADMIN, QUIT\n");

    while(1) {
        memset(buffer, 0, BUFFER_SIZE);
        int bytes_read = recv(client->socket, buffer, BUFFER_SIZE-1, 0);

        if (bytes_read <= 0) {
            break;
        }

        // Remove newline
        buffer[strcspn(buffer, "\r\n")] = 0;

        if (strcmp(buffer, "QUIT") == 0) {
            break;
        }

        process_command(client, buffer);
    }

    close(client->socket);
    free(client);
    pthread_exit(NULL);
}

void process_command(ClientData* client, char* command) {
    char* tokens[10];
    char* token;
    int token_count = 0;
    char cmd_copy[BUFFER_SIZE];

    strcpy(cmd_copy, command);
    token = strtok(cmd_copy, " ");

    while(token != NULL && token_count < 10) {
        tokens[token_count++] = token;
        token = strtok(NULL, " ");
    }

    if (token_count == 0) {
        send_response(client->socket, "Invalid command\n");
        return;
    }

    if (strcmp(tokens[0], "LOGIN") == 0) {
        if (token_count >= 3) {
            strcpy(client->user.username, tokens[1]);
            strcpy(client->user.role, tokens[2]);
            client->user.is_logged_in = 1;
            send_response(client->socket, "Login successful\n");
        } else {
            send_response(client->socket, "Usage: LOGIN <username> <role>\n");
        }
    }
    else if (strcmp(tokens[0], "READ") == 0) {
        if (token_count >= 2) {
            read_file_remote(client->socket, tokens[1]);
        } else {
            send_response(client->socket, "Usage: READ <filepath>\n");
        }
    }
    else if (strcmp(tokens[0], "WRITE") == 0) {
        if (token_count >= 3) {
            write_log_remote(client->socket, tokens[1], tokens[2]);
        } else {
            send_response(client->socket, "Usage: WRITE <filepath> <data>\n");
        }
    }
    else if (strcmp(tokens[0], "ADMIN") == 0) {
        if (!check_admin_access_remote(client->user)) {
            send_response(client->socket, "Access denied - admin privileges required\n");
            return;
        }

        if (token_count >= 2) {
            if (strcmp(tokens[1], "DELETE") == 0 && token_count >= 3) {
                delete_file_remote(client->socket, tokens[2]);
            } else if (strcmp(tokens[1], "EXEC") == 0 && token_count >= 3) {
                execute_command_remote(client->socket, tokens[2]);
            } else {
                send_response(client->socket, "Admin actions: DELETE <file>, EXEC <command>\n");
            }
        } else {
            send_response(client->socket, "Usage: ADMIN <action> [params]\n");
        }
    }
    else {
        send_response(client->socket, "Unknown command. Available: LOGIN, READ, WRITE, ADMIN, QUIT\n");
    }
}

void send_response(int socket, const char* message) {
    send(socket, message, strlen(message), 0);
}

int check_admin_access_remote(User user) {
    return (strcmp(user.role, "admin") == 0 || strcmp(user.username, "admin") == 0);
}

void read_file_remote(int socket, const char* filepath) {
    FILE *file = fopen(filepath, "r");
    if (file == NULL) {
        send_response(socket, "Error: Could not open file\n");
        return;
    }

    char buffer[1024];
    char response[2048] = "File contents:\n";

    while (fgets(buffer, sizeof(buffer), file) != NULL) {
        strcat(response, buffer);
    }

    fclose(file);
    send_response(socket, response);
}

void write_log_remote(int socket, const char* logpath, const char* message) {
    FILE *logfile = fopen(logpath, "a");
    if (logfile == NULL) {
        send_response(socket, "Error: Could not open log file\n");
        return;
    }

    fprintf(logfile, "[LOG] %s\n", message);
    fclose(logfile);
    send_response(socket, "Log written successfully\n");
}

void delete_file_remote(int socket, const char* filepath) {
    if (remove(filepath) == 0) {
        send_response(socket, "File deleted successfully\n");
    } else {
        send_response(socket, "Error deleting file\n");
    }
}

void execute_command_remote(int socket, const char* command) {
    char full_command[MAX_COMMAND + 20];
    snprintf(full_command, sizeof(full_command), "%s", command);

    FILE *fp = popen(full_command, "r");
    if (fp == NULL) {
        send_response(socket, "Command execution failed\n");
        return;
    }

    char buffer[256];
    char response[2048] = "Command output:\n";

    while (fgets(buffer, sizeof(buffer), fp) != NULL) {
        strcat(response, buffer);
    }

    pclose(fp);
    send_response(socket, response);
}

