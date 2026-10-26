#include <stdio.h>
#include <string.h>
#include <ctype.h>

#define MAX_PASSWORD_LENGTH 255

int main(void)
{
    char password[MAX_PASSWORD_LENGTH + 1];
    int has_uppercase = 0;
    int has_lowercase = 0;
    int has_number = 0;
    int has_symbol = 0;
    int ch;
    size_t length;

    printf("=== Password Strength Checker ===\n");
    printf("Enter a password (maximum %d characters): ", MAX_PASSWORD_LENGTH);

    if (fgets(password, sizeof password, stdin) == NULL) {
        fprintf(stderr, "Error: could not read the password.\n");
        return 1;
    }

    /* Reject overlong input instead of silently checking a truncated password. */
    if (strchr(password, '\n') == NULL) {
        ch = getchar();
        if (ch != '\n' && ch != EOF) {
            while (ch != '\n' && ch != EOF) {
                ch = getchar();
            }
            fprintf(stderr, "Error: password is too long. Maximum is %d characters.\n",
                    MAX_PASSWORD_LENGTH);
            return 1;
        }
    }

    password[strcspn(password, "\n")] = '\0';
    length = strlen(password);

    for (size_t i = 0; i < length; i++) {
        unsigned char current = (unsigned char) password[i];

        if (isupper(current)) {
            has_uppercase = 1;
        } else if (islower(current)) {
            has_lowercase = 1;
        }

        if (isdigit(current)) {
            has_number = 1;
        }

        if (ispunct(current)) {
            has_symbol = 1;
        }
    }

    printf("\n--- Password Requirements ---\n");
    printf("Length greater than 8: %s (length: %zu)\n",
           length > 8 ? "PASS" : "FAIL", length);
    printf("Contains uppercase letter: %s\n", has_uppercase ? "PASS" : "FAIL");
    printf("Contains lowercase letter: %s\n", has_lowercase ? "PASS" : "FAIL");
    printf("Contains a number: %s\n", has_number ? "PASS" : "FAIL");
    printf("Contains a symbol: %s\n", has_symbol ? "PASS" : "FAIL");

    if (length > 8 && has_uppercase && has_lowercase && has_number && has_symbol) {
        printf("\nResult: The password meets all requirements.\n");
    } else {
        printf("\nResult: The password does not meet all requirements.\n");
    }

    return 0;
}
