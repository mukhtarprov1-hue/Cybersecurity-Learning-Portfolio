<?php
declare(strict_types=1);

final class AuditLogger
{
    public function __construct(private readonly string $logPath)
    {
        $directory = dirname($this->logPath);
        if (!is_dir($directory) && !mkdir($directory, 0700, true) && !is_dir($directory)) {
            throw new RuntimeException('Could not create the audit directory.');
        }
    }

    public function record(
        string $requestId,
        string $method,
        string $path,
        int $status,
        string $clientIp
    ): void {
        $entry = [
            'timestamp_utc' => gmdate('Y-m-d\TH:i:s\Z'),
            'request_id' => $requestId,
            'method' => $method,
            'path' => $path,
            'status' => $status,
            'client_ip' => $clientIp,
        ];
        $line = json_encode($entry, JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR) . PHP_EOL;
        $written = file_put_contents($this->logPath, $line, FILE_APPEND | LOCK_EX);
        if ($written === false) {
            error_log('FIM-style API audit logger: failed to append an audit event.');
        }
    }
}
