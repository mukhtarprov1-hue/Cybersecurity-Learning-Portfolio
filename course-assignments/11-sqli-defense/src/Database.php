<?php

declare(strict_types=1);

namespace SqliDefense;

use PDO;
use RuntimeException;

final class Database
{
    /**
     * Create a fresh SQLite database in memory and seed synthetic demo users.
     *
     * The database is recreated for every HTTP request and is never persisted.
     */
    public static function create(): PDO
    {
        if (!in_array('sqlite', PDO::getAvailableDrivers(), true)) {
            throw new RuntimeException('PDO_SQLITE is not enabled in this PHP runtime.');
        }

        $pdo = new PDO('sqlite::memory:', null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);

        $pdo->exec(
            'CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                email TEXT NOT NULL,
                role TEXT NOT NULL
            )'
        );

        $insert = $pdo->prepare(
            'INSERT INTO users (username, email, role)
             VALUES (:username, :email, :role)'
        );

        $demoUsers = [
            ['admin', 'admin@example.test', 'administrator'],
            ['alice', 'alice@example.test', 'analyst'],
            ['bob', 'bob@example.test', 'user'],
            ['charlie', 'charlie@example.test', 'auditor'],
            ["o'connor", 'oconnor@example.test', 'user'],
        ];

        foreach ($demoUsers as [$username, $email, $role]) {
            $insert->execute([
                ':username' => $username,
                ':email' => $email,
                ':role' => $role,
            ]);
        }

        return $pdo;
    }
}
