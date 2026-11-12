<?php
declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "This verifier is a command-line tool only.\n");
    exit(2);
}

require_once dirname(__DIR__) . '/src/AuditChain.php';

$key = getenv('AUDIT_HMAC_KEY') ?: '';
if (strlen($key) < 32) {
    fwrite(STDERR, "AUDIT_HMAC_KEY is missing or too short. Load the original key before verification.\n");
    exit(2);
}

$logPath = $argv[1] ?? dirname(__DIR__) . '/storage/audit-chain.jsonl';

try {
    $chain = new AuditChain($logPath, $key);
    $result = $chain->verify();
} catch (Throwable $exception) {
    fwrite(STDERR, "VERIFIER ERROR: " . $exception->getMessage() . "\n");
    exit(2);
}

if ($result['valid']) {
    echo "AUDIT CHAIN: VALID\n";
    echo "Events verified: " . $result['events'] . "\n";
    echo "Last HMAC: " . ($result['last_hmac'] ?? 'GENESIS (empty chain)') . "\n";
    echo "Integrity check completed successfully.\n";
    exit(0);
}

echo "AUDIT CHAIN: INVALID\n";
echo "Valid prefix events: " . $result['events'] . "\n";
foreach ($result['errors'] as $error) {
    echo "[INTEGRITY FAILURE] {$error}\n";
}
exit(1);
