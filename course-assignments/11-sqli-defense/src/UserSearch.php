<?php

declare(strict_types=1);

namespace SqliDefense;

use PDO;

/**
 * Search helpers for the SQL injection training exercise.
 */
final class UserSearch
{
    /**
     * Intentionally vulnerable demonstration.
     *
     * Never use string concatenation with untrusted values in SQL.
     * This method is retained only so the local lab can demonstrate SQLi.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function unsafeSearch(PDO $pdo, string $username): array
    {
        $sql = "SELECT id, username, email, role
                FROM users
                WHERE username = '" . $username . "'
                ORDER BY id ASC";

        $statement = $pdo->query($sql);

        return $statement->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * Safe search: the supplied username is bound as a value, not SQL code.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function safeSearch(PDO $pdo, string $username): array
    {
        $statement = $pdo->prepare(
            'SELECT id, username, email, role
             FROM users
             WHERE username = :username
             ORDER BY id ASC'
        );

        $statement->bindValue(':username', $username, PDO::PARAM_STR);
        $statement->execute();

        return $statement->fetchAll(PDO::FETCH_ASSOC);
    }
}
