<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/src/bootstrap.php';

$passed = 0;
$failed = 0;
$temporaryDirectory = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'assignment10-tests-' . bin2hex(random_bytes(6));
$repository = new ItemRepository($temporaryDirectory);
$app = new ApiApplication($repository, 'test-secret-token', 'http://localhost:3000');

function test(string $name, callable $callback): void
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

function expect(bool $condition, string $message = 'Assertion failed'): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

function request(ApiApplication $app, string $method, string $uri, array $headers = [], string $body = ''): ApiResponse
{
    return $app->handle($method, $uri, $headers, $body, bin2hex(random_bytes(16)));
}

function jsonObject(ApiResponse $response): array
{
    expect(is_array($response->payload), 'Expected JSON payload');
    return $response->payload;
}

$authHeaders = ['Authorization' => 'Bearer test-secret-token', 'Content-Type' => 'application/json'];
$createdId = null;

try {
    test('GET health returns 200 JSON', function () use ($app): void {
        $response = request($app, 'GET', '/api/health');
        expect($response->status === 200);
        expect(jsonObject($response)['data']['status'] === 'ok');
    });

    test('GET collection starts empty', function () use ($app): void {
        $response = request($app, 'GET', '/api/items');
        expect($response->status === 200);
        expect(jsonObject($response)['data'] === []);
    });

    test('POST without bearer token returns 401', function () use ($app): void {
        $response = request($app, 'POST', '/api/items', ['Content-Type' => 'application/json'], '{"title":"Demo"}');
        expect($response->status === 401);
        expect(($response->headers['WWW-Authenticate'] ?? '') !== '');
    });

    test('POST creates item and returns 201 with Location', function () use ($app, $authHeaders, &$createdId): void {
        $response = request($app, 'POST', '/api/items', $authHeaders,
            json_encode(['title' => 'Security check', 'description' => 'Test record', 'priority' => 'high'], JSON_THROW_ON_ERROR));
        expect($response->status === 201);
        $data = jsonObject($response)['data'];
        $createdId = $data['id'];
        expect(is_string($createdId) && strlen($createdId) === 36);
        expect(($response->headers['Location'] ?? '') === '/api/items/' . $createdId);
    });

    test('GET item returns created resource', function () use ($app, &$createdId): void {
        $response = request($app, 'GET', '/api/items/' . $createdId);
        expect($response->status === 200);
        expect(jsonObject($response)['data']['title'] === 'Security check');
    });

    test('PUT replaces item fields', function () use ($app, $authHeaders, &$createdId): void {
        $response = request($app, 'PUT', '/api/items/' . $createdId, $authHeaders,
            json_encode(['title' => 'Updated security check', 'description' => 'Updated', 'priority' => 'normal'], JSON_THROW_ON_ERROR));
        expect($response->status === 200);
        expect(jsonObject($response)['data']['title'] === 'Updated security check');
    });

    test('GET collection supports q filter and limit', function () use ($app): void {
        $response = request($app, 'GET', '/api/items?q=Updated&limit=1');
        expect($response->status === 200);
        expect(count(jsonObject($response)['data']) === 1);
    });

    test('DELETE removes item and returns 204', function () use ($app, $authHeaders, &$createdId): void {
        $response = request($app, 'DELETE', '/api/items/' . $createdId, $authHeaders);
        expect($response->status === 204);
        expect($response->payload === null);
    });

    test('GET deleted item returns 404', function () use ($app, &$createdId): void {
        $response = request($app, 'GET', '/api/items/' . $createdId);
        expect($response->status === 404);
    });

    test('Malformed JSON returns 400', function () use ($app, $authHeaders): void {
        $response = request($app, 'POST', '/api/items', $authHeaders, '{bad-json');
        expect($response->status === 400);
    });

    test('Wrong content type returns 415', function () use ($app, $authHeaders): void {
        $headers = ['Authorization' => $authHeaders['Authorization'], 'Content-Type' => 'text/plain'];
        $response = request($app, 'POST', '/api/items', $headers, 'title=demo');
        expect($response->status === 415);
    });

    test('Missing title returns 422', function () use ($app, $authHeaders): void {
        $response = request($app, 'POST', '/api/items', $authHeaders, '{"description":"no title"}');
        expect($response->status === 422);
    });

    test('Unsupported property returns 422', function () use ($app, $authHeaders): void {
        $response = request($app, 'POST', '/api/items', $authHeaders, '{"title":"demo","admin":true}');
        expect($response->status === 422);
    });

    test('Unknown route returns 404', function () use ($app): void {
        $response = request($app, 'GET', '/api/not-a-route');
        expect($response->status === 404);
    });

    test('Unsupported method returns 405 with Allow header', function () use ($app): void {
        $response = request($app, 'PATCH', '/api/items');
        expect($response->status === 405);
        expect(str_contains($response->headers['Allow'] ?? '', 'GET'));
    });

    test('OPTIONS preflight returns 204 and allowed headers', function () use ($app): void {
        $response = request($app, 'OPTIONS', '/api/items', ['Origin' => 'http://localhost:3000']);
        expect($response->status === 204);
        expect(str_contains($response->headers['Access-Control-Allow-Methods'] ?? '', 'POST'));
    });

    test('Allowed CORS origin is reflected exactly', function () use ($app): void {
        $response = request($app, 'GET', '/api/health', ['Origin' => 'http://localhost:3000']);
        expect(($response->headers['Access-Control-Allow-Origin'] ?? '') === 'http://localhost:3000');
    });

    test('Untrusted CORS origin is not allowed', function () use ($app): void {
        $response = request($app, 'GET', '/api/health', ['Origin' => 'https://evil.example']);
        expect(!isset($response->headers['Access-Control-Allow-Origin']));
    });

    test('Request ID response header is present', function () use ($app): void {
        $response = request($app, 'GET', '/api/health');
        expect(strlen($response->headers['X-Request-ID'] ?? '') === 32);
    });

    test('Security headers are present', function () use ($app): void {
        $response = request($app, 'GET', '/api/health');
        expect(($response->headers['X-Content-Type-Options'] ?? '') === 'nosniff');
        expect(($response->headers['Cache-Control'] ?? '') === 'no-store, max-age=0');
    });

    test('Oversized request body returns 413', function () use ($app, $authHeaders): void {
        $large = str_repeat('x', 65537);
        $response = request($app, 'POST', '/api/items', $authHeaders, $large);
        expect($response->status === 413);
    });

    test('Bearer token comparison rejects invalid token', function () use ($app): void {
        $headers = ['Authorization' => 'Bearer wrong-token', 'Content-Type' => 'application/json'];
        $response = request($app, 'POST', '/api/items', $headers, '{"title":"demo"}');
        expect($response->status === 401);
    });

    test('PUT to collection returns 405', function () use ($app): void {
        $response = request($app, 'PUT', '/api/items');
        expect($response->status === 405);
    });

    echo PHP_EOL . sprintf("Tests: %d | Passed: %d | Failed: %d", $passed + $failed, $passed, $failed) . PHP_EOL;
} finally {
    $files = glob($temporaryDirectory . DIRECTORY_SEPARATOR . '*') ?: [];
    foreach ($files as $file) {
        if (is_file($file)) {
            unlink($file);
        }
    }
    @rmdir($temporaryDirectory);
}

exit($failed === 0 ? 0 : 1);
