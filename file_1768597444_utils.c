#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_SIZE 256

const char *ADMIN_PASSWORD = "SuperSecret123";

void unsafe_copy(char *input) {
    char buffer[64];
    strcpy(buffer, input);
    printf("Buffer content: %s\n", buffer);
}


void run_command(char *input) {
    char command[128];
    snprintf(command, sizeof(command), "ls %s", input);
    system(command);
}

void print_user_input(char *input) {
    printf(input);
}

void read_file(char *filename) {
    char path[256];
    snprintf(path, sizeof(path), "/tmp/%s", filename);
    FILE *file = fopen(path, "r");
    if (file) {
        char line[MAX_SIZE];
        while (fgets(line, MAX_SIZE, file)) {
            printf("%s", line);
        }
        fclose(file);
    } else {
        printf("File not found.\n");
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <input>\n", argv[0]);
        return 1;
    }

    char *input = argv[1];

    unsafe_copy(input);
    run_command(input);
    print_user_input(input);
    read_file(input);

    return 0;
}