<?php
declare(strict_types=1);

final class ApiApplication
{
    private const MAX_BODY_BYTES = 65536;
    private const COLLECTION_METHODS = ['GET', 'POST', 'OPTIONS'];
    private const ITEM_METHODS = ['GET', 'PUT', 'DELETE', 'OPTIONS'];
    private const PRIORITIES = ['low', 'normal', 'high'];

    public function __construct(
        private readonly ItemRepository $repository,
        private readonly string $apiToken,
        private readonly string $allowedOrigin = '',
        private readonly int $maxBodyBytes = self::MAX_BODY_BYTES,
    ) {
    }

    public function handle(
        string $method,
        string $uri,
        array $headers,
        string $body,
        string $requestId,
    ): ApiResponse {
        $method = strtoupper($method);
        $path = parse_url($uri, PHP_URL_PATH);
        if (!is_string($path)) {
            $path = '/';
        }
        $normalizedHeaders = [];
        foreach ($headers as $name => $value) {
            if (is_string($name) && is_scalar($value)) {
                $normalizedHeaders[strtolower($name)] = trim((string) $value);
            }
        }

        $baseHeaders = $this->baseHeaders($requestId);

        try {
            if (strlen($body) > $this->maxBodyBytes) {
                throw new ApiException(413, 'Request body exceeds the configured limit.', 'PAYLOAD_TOO_LARGE');
            }

            if ($path === '/api/health') {
                if ($method === 'OPTIONS') {
                    return new ApiResponse(204, $baseHeaders + $this->corsHeaders($normalizedHeaders), null);
                }
                if ($method !== 'GET') {
                    throw new ApiException(405, 'Method not allowed for this endpoint.', 'METHOD_NOT_ALLOWED', [
                        'allowed' => ['GET', 'OPTIONS'],
                    ]);
                }
                return $this->success(200, [
                    'service' => 'Assignment 10 Secure REST API',
                    'status' => 'ok',
                    'api_version' => '1.0.0',
                    'timestamp_utc' => gmdate('Y-m-d\TH:i:s\Z'),
                ], $requestId, $baseHeaders + $this->corsHeaders($normalizedHeaders));
            }

            if ($path === '/api/items') {
                if (!in_array($method, self::COLLECTION_METHODS, true)) {
                    throw new ApiException(405, 'Method not allowed for the collection endpoint.', 'METHOD_NOT_ALLOWED', [
                        'allowed' => self::COLLECTION_METHODS,
                    ]);
                }
                if ($method === 'OPTIONS') {
                    return new ApiResponse(204, $baseHeaders + $this->preflightHeaders($normalizedHeaders, self::COLLECTION_METHODS), null);
                }
                if ($method === 'GET') {
                    return $this->listItems($uri, $requestId, $baseHeaders, $normalizedHeaders);
                }
                $this->authorizeMutation($normalizedHeaders);
                $attributes = $this->parseAndValidateJson($body, $normalizedHeaders);
                $item = $this->repository->create($attributes);
                return $this->success(201, $item, $requestId,
                    $baseHeaders + $this->corsHeaders($normalizedHeaders),
                    ['Location' => '/api/items/' . $item['id']]);
            }

            if (preg_match('#^/api/items/([^/]+)$#D', $path, $matches) === 1) {
                if (!in_array($method, self::ITEM_METHODS, true)) {
                    throw new ApiException(405, 'Method not allowed for this item endpoint.', 'METHOD_NOT_ALLOWED', [
                        'allowed' => self::ITEM_METHODS,
                    ]);
                }
                if ($method === 'OPTIONS') {
                    return new ApiResponse(204, $baseHeaders + $this->preflightHeaders($normalizedHeaders, self::ITEM_METHODS), null);
                }
                $id = $matches[1];
                if (!$this->isUuid($id)) {
                    throw new ApiException(404, 'The requested resource was not found.', 'NOT_FOUND');
                }

                if ($method === 'GET') {
                    $item = $this->repository->find($id);
                    if ($item === null) {
                        throw new ApiException(404, 'The requested item was not found.', 'ITEM_NOT_FOUND');
                    }
                    return $this->success(200, $item, $requestId, $baseHeaders + $this->corsHeaders($normalizedHeaders));
                }

                $this->authorizeMutation($normalizedHeaders);
                if ($method === 'PUT') {
                    $attributes = $this->parseAndValidateJson($body, $normalizedHeaders);
                    $item = $this->repository->replace($id, $attributes);
                    if ($item === null) {
                        throw new ApiException(404, 'The requested item was not found.', 'ITEM_NOT_FOUND');
                    }
                    return $this->success(200, $item, $requestId, $baseHeaders + $this->corsHeaders($normalizedHeaders));
                }

                if (!$this->repository->delete($id)) {
                    throw new ApiException(404, 'The requested item was not found.', 'ITEM_NOT_FOUND');
                }
                return new ApiResponse(204, $baseHeaders + $this->corsHeaders($normalizedHeaders), null);
            }

            throw new ApiException(404, 'The requested API route does not exist.', 'ROUTE_NOT_FOUND');
        } catch (ApiException $exception) {
            $extraHeaders = [];
            if ($exception->httpStatus === 405 && isset($exception->details['allowed'])) {
                $extraHeaders['Allow'] = implode(', ', $exception->details['allowed']);
            }
            if ($exception->httpStatus === 401) {
                $extraHeaders['WWW-Authenticate'] = 'Bearer realm="assignment-10-api"';
            }
            return $this->failure(
                $exception->httpStatus,
                $exception->errorCode,
                $exception->getMessage(),
                $requestId,
                $baseHeaders + $this->corsHeaders($normalizedHeaders) + $extraHeaders,
                $exception->details
            );
        } catch (Throwable $exception) {
            error_log(sprintf('[%s] %s: %s', $requestId, get_class($exception), $exception->getMessage()));
            return $this->failure(500, 'INTERNAL_SERVER_ERROR', 'An unexpected server error occurred.',
                $requestId, $baseHeaders + $this->corsHeaders($normalizedHeaders));
        }
    }

    private function listItems(string $uri, string $requestId, array $headers, array $requestHeaders): ApiResponse
    {
        $queryString = parse_url($uri, PHP_URL_QUERY) ?: '';
        parse_str($queryString, $query);
        $limit = filter_var($query['limit'] ?? '100', FILTER_VALIDATE_INT);
        if ($limit === false || $limit < 1 || $limit > 100) {
            throw new ApiException(400, 'limit must be an integer between 1 and 100.', 'INVALID_LIMIT');
        }
        $search = $query['q'] ?? null;
        if ($search !== null && !is_string($search)) {
            throw new ApiException(400, 'q must be a string.', 'INVALID_QUERY');
        }
        $items = $this->repository->all($search, $limit);
        return $this->success(200, $items, $requestId,
            $headers + $this->corsHeaders($requestHeaders), [
                'X-Result-Count' => (string) count($items),
            ]);
    }

    private function authorizeMutation(array $headers): void
    {
        if ($this->apiToken === '') {
            throw new ApiException(503, 'Write operations are disabled until API_TOKEN is configured.', 'AUTH_NOT_CONFIGURED');
        }
        $authorization = $headers['authorization'] ?? '';
        if (preg_match('/^Bearer\s+(.+)$/i', $authorization, $matches) !== 1
            || !hash_equals($this->apiToken, trim($matches[1]))) {
            throw new ApiException(401, 'A valid Bearer token is required for this operation.', 'UNAUTHORIZED');
        }
    }

    private function parseAndValidateJson(string $body, array $headers): array
    {
        $contentType = strtolower(trim(explode(';', $headers['content-type'] ?? '')[0]));
        if ($contentType !== 'application/json') {
            throw new ApiException(415, 'Content-Type must be application/json.', 'UNSUPPORTED_MEDIA_TYPE');
        }
        if (trim($body) === '') {
            throw new ApiException(400, 'A JSON request body is required.', 'EMPTY_BODY');
        }
        try {
            $decoded = json_decode($body, false, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw new ApiException(400, 'The request body contains invalid JSON.', 'INVALID_JSON');
        }
        if (!$decoded instanceof stdClass) {
            throw new ApiException(400, 'The JSON body must be an object.', 'JSON_OBJECT_REQUIRED');
        }
        $data = get_object_vars($decoded);
        $unknown = array_values(array_diff(array_keys($data), ['title', 'description', 'priority']));
        if ($unknown !== []) {
            throw new ApiException(422, 'The request contains unsupported fields.', 'UNKNOWN_FIELDS', [
                'fields' => $unknown,
            ]);
        }
        if (!isset($data['title']) || !is_string($data['title'])) {
            throw new ApiException(422, 'title is required and must be a string.', 'INVALID_TITLE');
        }
        $title = trim($data['title']);
        if ($title === '' || self::unicodeLength($title) > 120) {
            throw new ApiException(422, 'title must contain between 1 and 120 characters.', 'INVALID_TITLE');
        }
        if (preg_match('//u', $title) !== 1) {
            throw new ApiException(422, 'title must contain valid UTF-8 text.', 'INVALID_TITLE_ENCODING');
        }

        $description = $data['description'] ?? '';
        if (!is_string($description) || self::unicodeLength($description) > 2000 || preg_match('//u', $description) !== 1) {
            throw new ApiException(422, 'description must be valid UTF-8 text of at most 2000 characters.', 'INVALID_DESCRIPTION');
        }
        $priority = $data['priority'] ?? 'normal';
        if (!is_string($priority) || !in_array($priority, self::PRIORITIES, true)) {
            throw new ApiException(422, 'priority must be low, normal, or high.', 'INVALID_PRIORITY');
        }

        return [
            'title' => $title,
            'description' => trim($description),
            'priority' => $priority,
        ];
    }

    private function baseHeaders(string $requestId): array
    {
        return [
            'Content-Type' => 'application/json; charset=utf-8',
            'Cache-Control' => 'no-store, max-age=0',
            'X-Content-Type-Options' => 'nosniff',
            'X-Frame-Options' => 'DENY',
            'Referrer-Policy' => 'no-referrer',
            'Cross-Origin-Resource-Policy' => 'same-origin',
            'X-Request-ID' => $requestId,
            'Vary' => 'Origin',
        ];
    }

    private function corsHeaders(array $requestHeaders): array
    {
        $origin = $requestHeaders['origin'] ?? '';
        if ($origin === '' || $this->allowedOrigin === '' || !hash_equals($this->allowedOrigin, $origin)) {
            return [];
        }
        return ['Access-Control-Allow-Origin' => $this->allowedOrigin];
    }

    private function preflightHeaders(array $requestHeaders, array $allowedMethods): array
    {
        $headers = $this->corsHeaders($requestHeaders);
        if ($headers === []) {
            return ['Allow' => implode(', ', $allowedMethods)];
        }
        return $headers + [
            'Access-Control-Allow-Methods' => implode(', ', $allowedMethods),
            'Access-Control-Allow-Headers' => 'Authorization, Content-Type, X-Request-ID',
            'Access-Control-Max-Age' => '600',
            'Allow' => implode(', ', $allowedMethods),
        ];
    }

    private function success(int $status, mixed $data, string $requestId, array $headers, array $extraHeaders = []): ApiResponse
    {
        $payload = [
            'success' => true,
            'request_id' => $requestId,
            'data' => $data,
        ];
        return new ApiResponse($status, $headers + $extraHeaders, $payload);
    }

    private function failure(
        int $status,
        string $code,
        string $message,
        string $requestId,
        array $headers,
        array $details = []
    ): ApiResponse {
        $error = ['code' => $code, 'message' => $message];
        if ($details !== []) {
            $error['details'] = $details;
        }
        return new ApiResponse($status, $headers, [
            'success' => false,
            'request_id' => $requestId,
            'error' => $error,
        ]);
    }

    private function isUuid(string $value): bool
    {
        return preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $value) === 1;
    }

    private static function unicodeLength(string $value): int
    {
        $count = preg_match_all('/./us', $value, $matches);
        return $count === false ? PHP_INT_MAX : $count;
    }
}
