<?php
declare(strict_types=1);
require_once dirname(__DIR__).'/src/SessionSecurity.php';

$sessionDirectory=sys_get_temp_dir().DIRECTORY_SEPARATOR.'assignment13-session-'.bin2hex(random_bytes(8));
if(!mkdir($sessionDirectory,0700,true)&&!is_dir($sessionDirectory)){fwrite(STDERR,"Unable to create isolated session test directory.\n");exit(2);}
session_save_path($sessionDirectory);
SessionSecurity::configureAndStart();

$passed=0;$failed=0;
// Regenerate before runner output; PHP cannot change session cookies after headers are sent.
$sessionIdBeforeRegeneration=session_id();
$sessionRegenerated=SessionSecurity::regenerateAfterLogin();
$sessionIdAfterRegeneration=session_id();

function testCase(string $name,callable $test):void{global $passed,$failed;try{$test();$passed++;echo "[PASS] {$name}\n";}catch(Throwable $exception){$failed++;echo "[FAIL] {$name}: {$exception->getMessage()}\n";}}
function assertTrue(bool $condition,string $message='Assertion failed'):void{if(!$condition)throw new RuntimeException($message);}

try{
testCase('Session cookie name is explicitly configured',function():void{assertTrue(session_name()===SessionSecurity::SESSION_NAME);assertTrue(session_name()==='CYBERSESSID');});
testCase('Session cookie is HttpOnly',function():void{$options=SessionSecurity::sessionCookieOptions(true);assertTrue($options['httponly']===true);});
testCase('Session cookie Secure flag is enabled by default policy',function():void{$options=SessionSecurity::sessionCookieOptions(true);assertTrue($options['secure']===true);});
testCase('Session cookie uses SameSite Strict',function():void{$options=SessionSecurity::sessionCookieOptions(true);assertTrue($options['samesite']==='Strict');});
testCase('Session strict mode is enabled',function():void{assertTrue(ini_get('session.use_strict_mode')==='1');});
testCase('Session cookies only are enabled and URL session IDs are disabled',function():void{assertTrue(ini_get('session.use_only_cookies')==='1');assertTrue(ini_get('session.use_trans_sid')==='0');});
testCase('CSRF token is a 256-bit hexadecimal value',function():void{$token=SessionSecurity::csrfToken();assertTrue((bool)preg_match('/^[a-f0-9]{64}$/',$token));});
testCase('Correct CSRF token is accepted',function():void{assertTrue(SessionSecurity::verifyCsrf(SessionSecurity::csrfToken()));});
testCase('Missing and incorrect CSRF tokens are rejected',function():void{assertTrue(!SessionSecurity::verifyCsrf(null));assertTrue(!SessionSecurity::verifyCsrf('not-the-token'));});
testCase('CSRF token rotation invalidates the previous token',function():void{$previous=SessionSecurity::csrfToken();SessionSecurity::rotateCsrfToken();$next=SessionSecurity::csrfToken();assertTrue($previous!==$next);assertTrue(!SessionSecurity::verifyCsrf($previous));assertTrue(SessionSecurity::verifyCsrf($next));});
testCase('Session identifier regeneration returns a new ID',function()use($sessionIdBeforeRegeneration,$sessionIdAfterRegeneration,$sessionRegenerated):void{assertTrue($sessionRegenerated===true);assertTrue($sessionIdBeforeRegeneration!==$sessionIdAfterRegeneration);assertTrue($_SESSION['session_rotated_after_login']===true);});
testCase('Only a SHA-256 fingerprint is recorded, not the raw session ID',function()use($sessionIdAfterRegeneration):void{$fingerprint=(string)($_SESSION['session_id_fingerprint']??'');assertTrue((bool)preg_match('/^[a-f0-9]{16}$/',$fingerprint));assertTrue($fingerprint!==$sessionIdAfterRegeneration);});
testCase('Protected comparison cookie is HttpOnly, Secure, and SameSite Strict',function():void{$options=SessionSecurity::safeDemoCookieOptions(true);assertTrue($options['httponly']===true);assertTrue($options['secure']===true);assertTrue($options['samesite']==='Strict');});
testCase('Unprotected comparison cookie deliberately lacks HttpOnly and Secure',function():void{$options=SessionSecurity::unsafeDemoCookieOptions();assertTrue($options['httponly']===false);assertTrue($options['secure']===false);assertTrue($options['samesite']==='Lax');});
testCase('Demonstration cookie names are distinct from the session cookie',function():void{assertTrue(SessionSecurity::SAFE_DEMO_COOKIE!==SessionSecurity::UNSAFE_DEMO_COOKIE);assertTrue(SessionSecurity::SAFE_DEMO_COOKIE!==SessionSecurity::SESSION_NAME);assertTrue(SessionSecurity::UNSAFE_DEMO_COOKIE!==SessionSecurity::SESSION_NAME);});
echo sprintf("\nTests: %d | Passed: %d | Failed: %d\n",$passed+$failed,$passed,$failed);
}finally{
if(session_status()===PHP_SESSION_ACTIVE)session_write_close();
foreach(glob($sessionDirectory.DIRECTORY_SEPARATOR.'*')?:[] as $file){if(is_file($file))@unlink($file);}
@rmdir($sessionDirectory);
}
exit($failed===0?0:1);
