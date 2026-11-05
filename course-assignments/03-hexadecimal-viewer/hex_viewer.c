#include <stdio.h>
#include <stdlib.h>

#define BYTES_PER_LINE 16

int main(int argc, char *argv[])
{
    FILE *file;
    unsigned char buffer[BYTES_PER_LINE];
    size_t bytes_read;
    unsigned long long offset = 0;
    int exit_status = EXIT_SUCCESS;

    if (argc != 2) {
        fprintf(stderr, "Usage: %s <filename>\n", argv[0]);
        return EXIT_FAILURE;
    }

    file = fopen(argv[1], "rb");
    if (file == NULL) {
        perror("Error opening file");
        return EXIT_FAILURE;
    }

    printf("\nHexadecimal Viewer\n");
    printf("File: %s\n\n", argv[1]);
    printf("Offset   Hexadecimal                                      ASCII\n");
    printf("-------- ------------------------------------------------ ----------------\n");

    while ((bytes_read = fread(buffer, 1, sizeof buffer, file)) > 0) {
        printf("%08llX  ", offset);

        for (size_t i = 0; i < BYTES_PER_LINE; i++) {
            if (i < bytes_read) {
                printf("%02X ", (unsigned int)buffer[i]);
            } else {
                printf("   ");
            }

            if (i == 7) {
                putchar(' ');
            }
        }

        printf(" |");

        for (size_t i = 0; i < BYTES_PER_LINE; i++) {
            if (i < bytes_read) {
                if (buffer[i] >= 32 && buffer[i] <= 126) {
                    putchar((int)buffer[i]);
                } else {
                    putchar('.');
                }
            } else {
                putchar(' ');
            }
        }

        printf("|\n");
        offset += (unsigned long long)bytes_read;
    }

    if (ferror(file)) {
        perror("Error reading file");
        exit_status = EXIT_FAILURE;
    }

    if (fclose(file) == EOF) {
        perror("Error closing file");
        exit_status = EXIT_FAILURE;
    }

    printf("\nTotal bytes read: %llu\n", offset);
    return exit_status;
}
