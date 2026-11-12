<?php
declare(strict_types=1);

/**
 * HMAC-SHA256 chained audit log.
 *
 * This provides tamper evidence for modifications, insertion, reordering,
 * and interior deletion while the HMAC key remains secret. It is not
 * tamper-proof storage and cannot detect deletion of a valid trailing suffix
 * unless the latest chain hash is anchored outside this storage boundary.
 */
final class AuditChain
{
    private const GENESIS_HMAC = '0000000000000000000000000000000000000000000000000000000000000000';
    private const VERSION = 1;

    private const PAYLOAD_FIELDS = [
        'version',
        'sequence',
        'timestamp_utc',
        'request_id',
        'method',
        'path',
        'status',
        'client_ip',
        'previous_hmac',
    ];

    private const ENTRY_FIELDS = [
        'version',
        'sequence',
        'timestamp_utc',
        'request_id',
        'method',
        'path',
        'status',
        'client_ip',
        'previous_hmac',
        'hmac',
    ];

    public function __construct(
        private readonly string $logPath,
        private readonly string $hmacKey
    ) {
        if (strlen($this->hmacKey) < 32) {
            throw new InvalidArgumentException('AUDIT_HMAC_KEY must contain at least 32 bytes.');
        }

        $directory = dirname($this->logPath);
        if (!is_dir($directory) && !mkdir($directory, 0700, true) && !is_dir($directory)) {
            throw new RuntimeException('Could not create the audit-chain directory.');
        }
        if (is_link($this->logPath) || is_link($this->lockPath())) {
            throw new RuntimeException('Audit-chain files must not be symbolic links.');
        }
    }

    /**
     * Append one metadata-only event after verifying the existing chain.
     *
     * @param array{request_id:string,method:string,path:string,status:int,client_ip:string} $event
     * @return array<string, int|string>
     */
    public function append(array $event): array
    {
        $lock = $this->openLock();
        try {
            if (!flock($lock, LOCK_EX)) {
                throw new RuntimeException('Could not acquire the audit-chain lock.');
            }

            $state = $this->verifyUnlocked();
            if (!$state['valid']) {
                throw new RuntimeException(
                    'Existing audit chain failed verification; refusing to append: '
                    . implode('; ', $state['errors'])
                );
            }

            $payload = [
                'version' => self::VERSION,
                'sequence' => $state['events'] + 1,
                'timestamp_utc' => gmdate('Y-m-d\TH:i:s\Z'),
                'request_id' => $this->requiredString($event, 'request_id'),
                'method' => strtoupper($this->requiredString($event, 'method')),
                'path' => $this->requiredString($event, 'path'),
                'status' => $this->requiredInteger($event, 'status'),
                'client_ip' => $this->requiredString($event, 'client_ip'),
                'previous_hmac' => $state['last_hmac'] ?? self::GENESIS_HMAC,
            ];

            $entry = $payload + [
                'hmac' => hash_hmac('sha256', self::canonicalJson($payload), $this->hmacKey),
            ];
            $line = self::canonicalJson($entry) . "\n";
            $this->appendLine($line);
            return $entry;
        } finally {
            flock($lock, LOCK_UN);
            fclose($lock);
        }
    }

    /**
     * Verify every event in the chain.
     *
     * @return array{valid:bool,events:int,last_hmac:?string,errors:list<string>}
     */
    public function verify(): array
    {
        $lock = $this->openLock();
        try {
            if (!flock($lock, LOCK_SH)) {
                throw new RuntimeException('Could not acquire the audit-chain verification lock.');
            }
            return $this->verifyUnlocked();
        } finally {
            flock($lock, LOCK_UN);
            fclose($lock);
        }
    }

    /** @return resource */
    private function openLock()
    {
        $path = $this->lockPath();
        if (is_link($path)) {
            throw new RuntimeException('Audit-chain lock must not be a symbolic link.');
        }
        $handle = fopen($path, 'c+b');
        if ($handle === false) {
            throw new RuntimeException('Could not open the audit-chain lock file.');
        }
        @chmod($path, 0600);
        return $handle;
    }

    private function lockPath(): string
    {
        return $this->logPath . '.lock';
    }

    private function appendLine(string $line): void
    {
        if (is_link($this->logPath)) {
            throw new RuntimeException('Audit-chain log must not be a symbolic link.');
        }
        $handle = fopen($this->logPath, 'ab');
        if ($handle === false) {
            throw new RuntimeException('Could not open the audit-chain log for appending.');
        }

        try {
            $offset = 0;
            $length = strlen($line);
            while ($offset < $length) {
                $written = fwrite($handle, substr($line, $offset));
                if ($written === false || $written === 0) {
                    throw new RuntimeException('Could not append the complete audit-chain event.');
                }
                $offset += $written;
            }
            if (!fflush($handle)) {
                throw new RuntimeException('Could not flush the audit-chain event.');
            }
            @chmod($this->logPath, 0600);
        } finally {
            fclose($handle);
        }
    }

    /**
     * @return array{valid:bool,events:int,last_hmac:?string,errors:list<string>}
     */
    private function verifyUnlocked(): array
    {
        if (!file_exists($this->logPath)) {
            return ['valid' => true, 'events' => 0, 'last_hmac' => null, 'errors' => []];
        }
        if (!is_file($this->logPath) || is_link($this->logPath)) {
            return ['valid' => false, 'events' => 0, 'last_hmac' => null, 'errors' => ['Audit-chain path is not a regular file.']];
        }

        $contents = file_get_contents($this->logPath);
        if ($contents === false) {
            return ['valid' => false, 'events' => 0, 'last_hmac' => null, 'errors' => ['Could not read the audit-chain file.']];
        }
        if ($contents === '') {
            return ['valid' => true, 'events' => 0, 'last_hmac' => null, 'errors' => []];
        }

        $lines = explode("\n", $contents);
        if (end($lines) === '') {
            array_pop($lines);
        }

        $expectedSequence = 1;
        $expectedPrevious = self::GENESIS_HMAC;
        $errors = [];

        foreach ($lines as $index => $line) {
            $lineNumber = $index + 1;
            $line = rtrim($line, "\r");
            if ($line === '') {
                $errors[] = "Blank record at line {$lineNumber}.";
                break;
            }

            try {
                $decoded = json_decode($line, true, 512, JSON_THROW_ON_ERROR);
            } catch (JsonException) {
                $errors[] = "Invalid JSON at line {$lineNumber}.";
                break;
            }
            if (!is_array($decoded)) {
                $errors[] = "Record {$lineNumber} is not a JSON object.";
                break;
            }

            $actualKeys = array_keys($decoded);
            $expectedKeys = self::ENTRY_FIELDS;
            sort($actualKeys);
            sort($expectedKeys);
            if ($actualKeys !== $expectedKeys) {
                $errors[] = "Unexpected audit-record schema at line {$lineNumber}.";
                break;
            }

            if (($decoded['version'] ?? null) !== self::VERSION
                || !is_int($decoded['sequence'] ?? null)
                || !is_string($decoded['timestamp_utc'] ?? null)
                || !is_string($decoded['request_id'] ?? null)
                || !is_string($decoded['method'] ?? null)
                || !is_string($decoded['path'] ?? null)
                || !is_int($decoded['status'] ?? null)
                || !is_string($decoded['client_ip'] ?? null)
                || !is_string($decoded['previous_hmac'] ?? null)
                || !is_string($decoded['hmac'] ?? null)) {
                $errors[] = "Invalid field types at line {$lineNumber}.";
                break;
            }

            if ($decoded['sequence'] !== $expectedSequence) {
                $errors[] = "Sequence discontinuity at line {$lineNumber}.";
                break;
            }
            if (!hash_equals($expectedPrevious, $decoded['previous_hmac'])) {
                $errors[] = "Previous-HMAC link mismatch at line {$lineNumber}.";
                break;
            }
            if (preg_match('/^[a-f0-9]{64}$/D', $decoded['hmac']) !== 1) {
                $errors[] = "Malformed HMAC at line {$lineNumber}.";
                break;
            }

            $payload = [];
            foreach (self::PAYLOAD_FIELDS as $field) {
                $payload[$field] = $decoded[$field];
            }
            $computed = hash_hmac('sha256', self::canonicalJson($payload), $this->hmacKey);
            if (!hash_equals($computed, $decoded['hmac'])) {
                $errors[] = "HMAC verification failed at line {$lineNumber}.";
                break;
            }

            $expectedPrevious = $decoded['hmac'];
            $expectedSequence++;
        }

        $valid = $errors === [];
        return [
            'valid' => $valid,
            'events' => $valid ? $expectedSequence - 1 : max(0, $expectedSequence - 1),
            'last_hmac' => $valid && $expectedSequence > 1 ? $expectedPrevious : null,
            'errors' => $errors,
        ];
    }

    private static function canonicalJson(array $value): string
    {
        return json_encode(
            $value,
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR
        );
    }

    private function requiredString(array $event, string $field): string
    {
        if (!isset($event[$field]) || !is_string($event[$field])) {
            throw new InvalidArgumentException("Audit event field {$field} must be a string.");
        }
        return $event[$field];
    }

    private function requiredInteger(array $event, string $field): int
    {
        if (!isset($event[$field]) || !is_int($event[$field])) {
            throw new InvalidArgumentException("Audit event field {$field} must be an integer.");
        }
        return $event[$field];
    }
}
