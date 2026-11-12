<?php

declare(strict_types=1);

require_once __DIR__ . '/../src/Database.php';
require_once __DIR__ . '/../src/UserSearch.php';

use SqliDefense\Database;
use SqliDefense\UserSearch;

$passed = 0;
$failed = 0;

function check(string $name, bool $condition): void
{
    global $passed, $failed;

    if ($condition) {
        $passed++;
        echo "[PASS] {$name}" . PHP_EOL;
        return;
    }

    $failed++;
    echo "[FAIL] {$name}" . PHP_EOL;
}

try {
    $pdo = Database::create();

    check(
        'PDO is configured to throw exceptions',
        $pdo->getAttribute(PDO::ATTR_ERRMODE) === PDO::ERRMODE_EXCEPTION
    );

    $normal = UserSearch::safeSearch($pdo, 'alice');
    check(
        'Safe exact lookup returns only the alice record',
        count($normal) === 1 && $normal[0]['username'] === 'alice'
    );

    $payload = "' OR '1'='1' -- ";
    $safeAttack = UserSearch::safeSearch($pdo, $payload);
    check(
        'Prepared statement treats the injection payload as literal data',
        count($safeAttack) === 0
    );

    $unsafeAttack = UserSearch::unsafeSearch($pdo, $payload);
    check(
        'Unsafe concatenation demonstrates the injection against all seeded rows',
        count($unsafeAttack) === 5
    );

    $quotedUsername = UserSearch::safeSearch($pdo, "o'connor");
    check(
        'A legitimate username containing an apostrophe is handled as data',
        count($quotedUsername) === 1 && $quotedUsername[0]['username'] === "o'connor"
    );

    check(
        'Safe query returns only the explicitly selected columns',
        isset($normal[0]) && array_keys($normal[0]) === ['id', 'username', 'email', 'role']
    );
} catch (Throwable $exception) {
    $failed++;
    fwrite(STDERR, '[ERROR] Test runner exception: ' . $exception->getMessage() . PHP_EOL);
}

echo PHP_EOL;
echo sprintf("SUMMARY: %d passed, %d failed", $passed, $failed) . PHP_EOL;

exit($failed === 0 ? 0 : 1);
