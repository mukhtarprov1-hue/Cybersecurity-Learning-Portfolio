<?php
declare(strict_types=1);

ini_set('display_errors', '0');
error_reporting(E_ALL);

require_once dirname(__DIR__) . '/src/bootstrap.php';

header_remove('X-Powered-By');

$requestId = bin2hex(random_bytes(16));
$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
$uri = $_SERVER['REQUEST_URI'] ?? '/';
$path = parse_url($uri, PHP_URL_PATH);
$clientIp = $_SERVER['REMOTE_ADDR'] ?? 'unknown';

$headers = function_exists('getallheaders') ? getallheaders() : [];
if (!is_array($headers)) {
    $headers = [];
}
if (isset($_SERVER['HTTP_AUTHORIZATION']) && !isset($headers['Authorization'])) {
    $headers['Authorization'] = $_SERVER['HTTP_AUTHORIZATION'];
}
if (isset($_SERVER['CONTENT_TYPE']) && !isset($headers['Content-Type'])) {
    $headers['Content-Type'] = $_SERVER['CONTENT_TYPE'];
}

$maxBodyBytes = 65536;
$contentLength = isset($_SERVER['CONTENT_LENGTH']) ? (int) $_SERVER['CONTENT_LENGTH'] : 0;
$body = '';
if ($contentLength > $maxBodyBytes) {
    $body = str_repeat('x', $maxBodyBytes + 1);
} else {
    $rawBody = file_get_contents('php://input', false, null, 0, $maxBodyBytes + 1);
    $body = $rawBody === false ? '' : $rawBody;
}

$storagePath = dirname(__DIR__) . '/storage';
$apiToken = getenv('API_TOKEN') ?: '';
$allowedOrigin = getenv('API_ALLOWED_ORIGIN') ?: 'http://localhost:3000';
$auditHmacKey = getenv('AUDIT_HMAC_KEY') ?: '';

try {
    $repository = new ItemRepository($storagePath);
    $application = new ApiApplication($repository, $apiToken, $allowedOrigin, $maxBodyBytes);
    $response = $application->handle($method, $uri, $headers, $body, $requestId);
} catch (Throwable $exception) {
    error_log(sprintf('[%s] Bootstrap failure: %s', $requestId, $exception->getMessage()));
    $response = new ApiResponse(500, [
        'Content-Type' => 'application/json; charset=utf-8',
        'Cache-Control' => 'no-store',
        'X-Content-Type-Options' => 'nosniff',
        'X-Request-ID' => $requestId,
    ], [
        'success' => false,
        'request_id' => $requestId,
        'error' => [
            'code' => 'INTERNAL_SERVER_ERROR',
            'message' => 'The API could not initialize its services.',
        ],
    ]);
}

try {
    // Use a new HMAC-chained file so existing legacy audit.jsonl records remain untouched.
    $audit = new AuditLogger($storagePath . '/audit-chain.jsonl', $auditHmacKey);
    $audit->record($requestId, $method, is_string($path) ? $path : '/', $response->status, $clientIp);
} catch (Throwable $exception) {
    // API responses remain available, but failed audit writes are visible in the server log.
    error_log(sprintf('[%s] Audit-chain failure: %s', $requestId, $exception->getMessage()));
}

http_response_code($response->status);
foreach ($response->headers as $name => $value) {
    header($name . ': ' . $value);
}

if ($response->payload !== null) {
    try {
        echo json_encode(
            $response->payload,
            JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
        );
        echo PHP_EOL;
    } catch (JsonException $exception) {
        http_response_code(500);
        echo '{"success":false,"error":{"code":"RESPONSE_ENCODING_ERROR","message":"Could not encode response."}}';
    }
}
