# Requirements Traceability — Assignment 08

| Requirement | Implementation | Test |
|---|---|---|
| Generate passwords of requested length | generate_password(length) | test_generates_password_with_requested_length |
| Uppercase, lowercase, digits, symbols | One character sampled from each required group before filling remaining positions | Four character-class tests |
| Cryptographically secure randomness | secrets.choice() and secrets.SystemRandom().shuffle() | Password policy tests and code review |
| Validate length | Minimum 4, maximum 4096 | Length boundary and type tests |
| Generate multiple passwords | generate_passwords(length, count) | Count tests |
| Calculate SHA-256 | hashlib.sha256(text.encode("utf-8")).hexdigest() | Known vector, Unicode, empty string |
| Hexadecimal output | hexdigest() returns 64 hexadecimal characters | Known SHA-256 vector tests |
| Reject invalid input | Type and range checks | Invalid input tests |
