#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <limits.h>

#define INPUT_CHUNK_SIZE 512U

/* Append one fgets() chunk to the current logical line. */
static int append_chunk(char **line, size_t *length, size_t *capacity,
                        const char *chunk, size_t chunk_length)
{
    size_t required;
    size_t new_capacity;
    char *resized;

    if (*length >= SIZE_MAX || chunk_length > SIZE_MAX - *length - 1U) {
        return 0;
    }

    required = *length + chunk_length + 1U;
    if (required > *capacity) {
        new_capacity = (*capacity == 0U) ? INPUT_CHUNK_SIZE : *capacity;
        while (new_capacity < required) {
            if (new_capacity > SIZE_MAX / 2U) {
                new_capacity = required;
                break;
            }
            new_capacity *= 2U;
        }

        resized = (char *)realloc(*line, new_capacity);
        if (resized == NULL) {
            return 0;
        }
        *line = resized;
        *capacity = new_capacity;
    }

    memcpy(*line + *length, chunk, chunk_length);
    *length += chunk_length;
    (*line)[*length] = '\0';
    return 1;
}

/* Process exactly one logical line and count it at most once. */
static int inspect_line(const char *line, const char *keyword,
                        unsigned long long *line_number,
                        unsigned long long *alert_count)
{
    size_t line_length;

    if (*line_number == ULLONG_MAX) {
        fprintf(stderr, "Error: line counter overflow.\n");
        return 0;
    }
    ++(*line_number);

    if (strstr(line, keyword) == NULL) {
        return 1;
    }

    if (*alert_count == ULLONG_MAX) {
        fprintf(stderr, "Error: alert counter overflow.\n");
        return 0;
    }
    ++(*alert_count);

    printf("Line %llu: ", *line_number);
    fputs(line, stdout);
    line_length = strlen(line);
    if (line_length == 0U || line[line_length - 1U] != '\n') {
        putchar('\n');
    }
    return 1;
}

int main(int argc, char *argv[])
{
    FILE *log_file;
    char chunk[INPUT_CHUNK_SIZE];
    char *line;
    size_t line_length = 0U;
    size_t line_capacity = INPUT_CHUNK_SIZE;
    unsigned long long line_number = 0ULL;
    unsigned long long alert_count = 0ULL;
    int exit_status = EXIT_SUCCESS;

    if (argc != 3 || argv[2][0] == '\0') {
        fprintf(stderr, "Usage: %s <log_file> <keyword>\n", argv[0]);
        fprintf(stderr, "Example: %s samples/sample.log FAILED\n", argv[0]);
        return EXIT_FAILURE;
    }

    log_file = fopen(argv[1], "r");
    if (log_file == NULL) {
        perror("Error opening log file");
        return EXIT_FAILURE;
    }

    line = (char *)malloc(line_capacity);
    if (line == NULL) {
        fprintf(stderr, "Error: unable to allocate the line buffer.\n");
        (void)fclose(log_file);
        return EXIT_FAILURE;
    }
    line[0] = '\0';

    printf("Log File Parser\n");
    printf("File: %s\n", argv[1]);
    printf("Keyword: %s\n\n", argv[2]);
    printf("Matching records:\n");

    while (fgets(chunk, (int)sizeof chunk, log_file) != NULL) {
        size_t chunk_length = strlen(chunk);

        if (!append_chunk(&line, &line_length, &line_capacity,
                          chunk, chunk_length)) {
            fprintf(stderr, "Error: unable to extend the line buffer.\n");
            exit_status = EXIT_FAILURE;
            break;
        }

        /* A newline marks the end of a logical line, not merely a chunk. */
        if (memchr(chunk, '\n', chunk_length) != NULL) {
            if (!inspect_line(line, argv[2], &line_number, &alert_count)) {
                exit_status = EXIT_FAILURE;
                break;
            }
            line_length = 0U;
            line[0] = '\0';
        }
    }

    if (exit_status == EXIT_SUCCESS) {
        if (ferror(log_file)) {
            perror("Error reading log file");
            exit_status = EXIT_FAILURE;
        } else if (line_length > 0U) {
            /* Also process a final line that does not end with '\n'. */
            if (!inspect_line(line, argv[2], &line_number, &alert_count)) {
                exit_status = EXIT_FAILURE;
            }
        }
    }

    if (fclose(log_file) == EOF) {
        perror("Error closing log file");
        exit_status = EXIT_FAILURE;
    }

    if (alert_count == 0ULL) {
        printf("No matching records found.\n");
    }
    printf("\nTotal alerts: %llu\n", alert_count);

    free(line);
    return exit_status;
}
