<?php
declare(strict_types=1);

require_once __DIR__.'/SessionSecurity.php';
SessionSecurity::configureAndStart();
SessionSecurity::issueComparisonCookies();

header('Content-Type: text/html; charset=UTF-8');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store, max-age=0');
header("Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'");

function htmlEscape(string $value): string
{
    return htmlspecialchars($value,ENT_QUOTES|ENT_SUBSTITUTE,'UTF-8');
}

function redirectTo(string $path): never
{
    header('Location: '.$path,true,303);
    exit;
}
