<?php
declare(strict_types=1);

final class AuditLogger
{
    private readonly AuditChain $chain;

    public function __construct(
        private readonly string $logPath,
        string $hmacKey
    ) {
        $directory = dirname($this->logPath);
        if (!is_dir($directory) && !mkdir($directory, 0700, true) && !is_dir($directory)) {
            throw new RuntimeException('Could not create the audit directory.');
        }
        $this->chain = new AuditChain($this->logPath, $hmacKey);
    }

    public function record(
        string $requestId,
        string $method,
        string $path,
        int $status,
        string $clientIp
    ): void {
        $this->chain->append([
            'request_id' => $requestId,
            'method' => $method,
            'path' => $path,
            'status' => $status,
            'client_ip' => $clientIp,
        ]);
    }
}
