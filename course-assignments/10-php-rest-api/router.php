<?php
declare(strict_types=1);

$publicRoot = __DIR__ . DIRECTORY_SEPARATOR . 'public';
$requestedPath = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$requestedPath = is_string($requestedPath) ? rawurldecode($requestedPath) : '/';
$staticCandidate = realpath($publicRoot . DIRECTORY_SEPARATOR . ltrim($requestedPath, '/\\'));
$resolvedRoot = realpath($publicRoot);

if ($staticCandidate !== false
    && $resolvedRoot !== false
    && str_starts_with($staticCandidate, $resolvedRoot . DIRECTORY_SEPARATOR)
    && is_file($staticCandidate)) {
    return false;
}

require $publicRoot . DIRECTORY_SEPARATOR . 'index.php';
