<?php
declare(strict_types=1);

final class SessionSecurity
{
    public const SESSION_NAME = 'CYBERSESSID';
    public const SAFE_DEMO_COOKIE = 'DEMO_SAFE';
    public const UNSAFE_DEMO_COOKIE = 'DEMO_UNSAFE';

    public static function sessionCookieOptions(bool $secure = true): array
    {
        return ['lifetime'=>0,'path'=>'/','secure'=>$secure,'httponly'=>true,'samesite'=>'Strict'];
    }

    public static function safeDemoCookieOptions(bool $secure = true): array
    {
        return ['expires'=>time()+3600,'path'=>'/','secure'=>$secure,'httponly'=>true,'samesite'=>'Strict'];
    }

    public static function unsafeDemoCookieOptions(): array
    {
        return ['expires'=>time()+3600,'path'=>'/','secure'=>false,'httponly'=>false,'samesite'=>'Lax'];
    }

    public static function secureCookiesEnabled(): bool
    {
        $configured=getenv('APP_SESSION_SECURE');
        if ($configured===false || $configured==='') return true;
        return filter_var($configured,FILTER_VALIDATE_BOOL,FILTER_NULL_ON_FAILURE) ?? true;
    }

    public static function configureAndStart(): void
    {
        if (headers_sent($file,$line)) throw new RuntimeException("Session headers were already sent at {$file}:{$line}.");
        if (session_status()!==PHP_SESSION_NONE) throw new RuntimeException('Session must be configured before it is started.');
        session_name(self::SESSION_NAME);
        ini_set('session.use_strict_mode','1');
        ini_set('session.use_only_cookies','1');
        ini_set('session.use_trans_sid','0');
        ini_set('session.cookie_httponly','1');
        ini_set('session.cookie_secure',self::secureCookiesEnabled()?'1':'0');
        session_set_cookie_params(self::sessionCookieOptions(self::secureCookiesEnabled()));
        if (!session_start()) throw new RuntimeException('Unable to start the secure session.');
        if (!isset($_SESSION['csrf_token']) || !is_string($_SESSION['csrf_token'])) $_SESSION['csrf_token']=bin2hex(random_bytes(32));
        if (!isset($_SESSION['created_at'])) $_SESSION['created_at']=gmdate('c');
    }

    public static function issueComparisonCookies(): void
    {
        if (!headers_sent() && !isset($_COOKIE[self::SAFE_DEMO_COOKIE])) {
            setcookie(self::SAFE_DEMO_COOKIE,'server-only-demo-marker',self::safeDemoCookieOptions(self::secureCookiesEnabled()));
        }
        if (!headers_sent() && !isset($_COOKIE[self::UNSAFE_DEMO_COOKIE])) {
            setcookie(self::UNSAFE_DEMO_COOKIE,'javascript-readable-demo-marker',self::unsafeDemoCookieOptions());
        }
    }

    public static function regenerateAfterLogin(): bool
    {
        if (session_status()!==PHP_SESSION_ACTIVE) throw new RuntimeException('Cannot rotate an inactive session.');
        $oldId=session_id();
        if (!session_regenerate_id(true)) throw new RuntimeException('Session ID regeneration failed.');
        $newId=session_id();
        $rotated=$oldId!=='' && $newId!=='' && !hash_equals($oldId,$newId);
        $_SESSION['session_rotated_after_login']=$rotated;
        $_SESSION['session_id_fingerprint']=substr(hash('sha256',$newId),0,16);
        $_SESSION['authenticated_at']=gmdate('c');
        return $rotated;
    }

    public static function csrfToken(): string
    {
        if (session_status()!==PHP_SESSION_ACTIVE) throw new RuntimeException('No active session for CSRF token.');
        return (string)$_SESSION['csrf_token'];
    }

    public static function verifyCsrf(mixed $submitted): bool
    {
        return is_string($submitted) && $submitted!=='' && session_status()===PHP_SESSION_ACTIVE
            && isset($_SESSION['csrf_token']) && is_string($_SESSION['csrf_token'])
            && hash_equals($_SESSION['csrf_token'],$submitted);
    }

    public static function rotateCsrfToken(): void
    {
        if (session_status()!==PHP_SESSION_ACTIVE) throw new RuntimeException('Cannot rotate CSRF token without an active session.');
        $_SESSION['csrf_token']=bin2hex(random_bytes(32));
    }

    public static function destroySession(): void
    {
        if (session_status()!==PHP_SESSION_ACTIVE) return;
        $_SESSION=[];
        $params=session_get_cookie_params();
        setcookie(session_name(),'',[
            'expires'=>time()-42000,
            'path'=>$params['path'] ?: '/',
            'domain'=>$params['domain'],
            'secure'=>(bool)$params['secure'],
            'httponly'=>(bool)$params['httponly'],
            'samesite'=>$params['samesite'] ?: 'Strict',
        ]);
        session_destroy();
    }
}
