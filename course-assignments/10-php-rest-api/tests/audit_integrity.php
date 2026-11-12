<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/src/AuditChain.php';
require_once dirname(__DIR__) . '/src/AuditLogger.php';

$passed = 0;
$failed = 0;
$root = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'assignment10-audit-tests-' . bin2hex(random_bytes(6));
if (!mkdir($root, 0700, true) && !is_dir($root)) {
    fwrite(STDERR, "Could not create audit test directory.\n");
    exit(2);
}

register_shutdown_function(static function () use ($root): void {
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS),
        RecursiveIteratorIterator::CHILD_FIRST
    );
    foreach ($iterator as $item) {
        $item->isDir() ? @rmdir($item->getPathname()) : @unlink($item->getPathname());
    }
    @rmdir($root);
});

function auditTest(string $name, callable $callback): void
{
    global $passed, $failed;
    try {
        $callback();
        $passed++;
        echo "[PASS] {$name}" . PHP_EOL;
    } catch (Throwable $exception) {
        $failed++;
        echo "[FAIL] {$name}: {$exception->getMessage()}" . PHP_EOL;
    }
}

function auditExpect(bool $condition, string $message = 'Assertion failed'): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

function auditPath(string $name): string
{
    global $root;
    $directory = $root . DIRECTORY_SEPARATOR . $name;
    if (!mkdir($directory, 0700, true) && !is_dir($directory)) {
        throw new RuntimeException('Could not create fixture directory.');
    }
    return $directory . DIRECTORY_SEPARATOR . 'audit-chain.jsonl';
}

function auditEvent(string $suffix): array
{
    return [
        'request_id' => str_pad($suffix, 32, 'a'),
        'method' => 'GET',
        'path' => '/api/health',
        'status' => 200,
        'client_ip' => '127.0.0.1',
    ];
}

function auditReadEntries(string $path): array
{
    $lines = file($path, FILE_IGNORE_NEW_LINES);
    if ($lines === false) {
        throw new RuntimeException('Could not read fixture audit log.');
    }
    return array_map(
        static fn (string $line): array => json_decode($line, true, 512, JSON_THROW_ON_ERROR),
        $lines
    );
}

function auditWriteEntries(string $path, array $entries): void
{
    $lines = array_map(
        static fn (array $entry): string => json_encode($entry, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
        $entries
    );
    file_put_contents($path, implode(PHP_EOL, $lines) . PHP_EOL);
}

$key = bin2hex(random_bytes(32));

auditTest('Empty chain is valid', function () use ($key): void {
    $path = auditPath('empty');
    $result = (new AuditChain($path, $key))->verify();
    auditExpect($result['valid'] && $result['events'] === 0);
});

auditTest('Two appended events verify with sequence and previous-HMAC links', function () use ($key): void {
    $path = auditPath('valid');
    $chain = new AuditChain($path, $key);
    $first = $chain->append(auditEvent('1'));
    $second = $chain->append(auditEvent('2'));
    $result = $chain->verify();
    auditExpect($result['valid'] && $result['events'] === 2);
    auditExpect($first['sequence'] === 1 && $second['sequence'] === 2);
    auditExpect($second['previous_hmac'] === $first['hmac']);
});

auditTest('Modified event content is detected', function () use ($key): void {
    $path = auditPath('modified');
    $chain = new AuditChain($path, $key);
    $chain->append(auditEvent('3'));
    $chain->append(auditEvent('4'));
    $entries = auditReadEntries($path);
    $entries[0]['path'] = '/api/admin';
    auditWriteEntries($path, $entries);
    $result = $chain->verify();
    auditExpect(!$result['valid']);
    auditExpect(str_contains(implode(' ', $result['errors']), 'HMAC verification failed'));
});

auditTest('Deletion of an interior event is detected', function () use ($key): void {
    $path = auditPath('deleted');
    $chain = new AuditChain($path, $key);
    $chain->append(auditEvent('5'));
    $chain->append(auditEvent('6'));
    $chain->append(auditEvent('7'));
    $entries = auditReadEntries($path);
    unset($entries[1]);
    auditWriteEntries($path, array_values($entries));
    $result = $chain->verify();
    auditExpect(!$result['valid']);
    auditExpect(str_contains(implode(' ', $result['errors']), 'Sequence discontinuity'));
});

auditTest('Reordering events is detected', function () use ($key): void {
    $path = auditPath('reordered');
    $chain = new AuditChain($path, $key);
    $chain->append(auditEvent('8'));
    $chain->append(auditEvent('9'));
    $entries = auditReadEntries($path);
    [$entries[0], $entries[1]] = [$entries[1], $entries[0]];
    auditWriteEntries($path, $entries);
    $result = $chain->verify();
    auditExpect(!$result['valid']);
});

auditTest('Appending to a tampered chain is refused', function () use ($key): void {
    $path = auditPath('refuse');
    $chain = new AuditChain($path, $key);
    $chain->append(auditEvent('a'));
    $entries = auditReadEntries($path);
    $entries[0]['status'] = 500;
    auditWriteEntries($path, $entries);
    $refused = false;
    try {
        $chain->append(auditEvent('b'));
    } catch (RuntimeException) {
        $refused = true;
    }
    auditExpect($refused, 'The logger must not extend an invalid chain.');
});

auditTest('Verification fails with a different HMAC key', function () use ($key): void {
    $path = auditPath('wrong-key');
    (new AuditChain($path, $key))->append(auditEvent('c'));
    $result = (new AuditChain($path, bin2hex(random_bytes(32))))->verify();
    auditExpect(!$result['valid']);
});

auditTest('Keys shorter than 32 bytes are rejected', function (): void {
    $rejected = false;
    try {
        new AuditChain(auditPath('short-key'), 'too-short');
    } catch (InvalidArgumentException) {
        $rejected = true;
    }
    auditExpect($rejected);
});

auditTest('AuditLogger records metadata without request secrets or body', function () use ($key): void {
    $path = auditPath('logger');
    $logger = new AuditLogger($path, $key);
    $logger->record('request-safe-identifier', 'POST', '/api/items', 201, '127.0.0.1');
    $contents = file_get_contents($path);
    auditExpect(is_string($contents));
    auditExpect(!str_contains($contents, 'Bearer'));
    auditExpect(!str_contains($contents, 'secret-token'));
    auditExpect(!str_contains($contents, 'sensitive-body'));
    $result = (new AuditChain($path, $key))->verify();
    auditExpect($result['valid'] && $result['events'] === 1);
});

echo PHP_EOL . sprintf(
    "Audit integrity tests: %d | Passed: %d | Failed: %d",
    $passed + $failed,
    $passed,
    $failed
) . PHP_EOL;

exit($failed === 0 ? 0 : 1);
