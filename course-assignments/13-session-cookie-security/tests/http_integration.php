<?php
declare(strict_types=1);

/** Real HTTP integration test for Set-Cookie flags, CSRF, session rotation and logout. */
$projectRoot=dirname(__DIR__);$publicRoot=$projectRoot.DIRECTORY_SEPARATOR.'public';
$sessionPath=sys_get_temp_dir().DIRECTORY_SEPARATOR.'assignment13-http-'.bin2hex(random_bytes(8));
if(!mkdir($sessionPath,0700,true)&&!is_dir($sessionPath)){fwrite(STDERR,"Unable to create HTTP integration session directory.\n");exit(2);}
$serverSocket=stream_socket_server('tcp://127.0.0.1:0',$errno,$errstr);
if($serverSocket===false){fwrite(STDERR,"Unable to reserve local test port: {$errstr} ({$errno})\n");exit(2);}
$address=stream_socket_get_name($serverSocket,false);fclose($serverSocket);
$port=(int)substr(strrchr((string)$address,':'),1);$baseUrl="http://127.0.0.1:{$port}";
$environment=getenv();$environment['APP_SESSION_SECURE']='1';
$command=[PHP_BINARY,'-d','session.save_path='.$sessionPath,'-d','session.cookie_secure=1','-S','127.0.0.1:'.$port,'-t',$publicRoot];
$serverStdoutLog=$sessionPath.DIRECTORY_SEPARATOR.'server-stdout.log';
$serverStderrLog=$sessionPath.DIRECTORY_SEPARATOR.'server-stderr.log';
$descriptorSpec=[0=>['pipe','r'],1=>['file',$serverStdoutLog,'a'],2=>['file',$serverStderrLog,'a']];
$process=proc_open($command,$descriptorSpec,$pipes,$projectRoot,$environment);
if(!is_resource($process)){fwrite(STDERR,"Unable to start PHP HTTP test server.\n");exit(2);}
$passed=0;$failed=0;$cookies=[];

function integrationTest(string $name,callable $test):void{global $passed,$failed;try{$test();$passed++;echo "[PASS] {$name}\n";}catch(Throwable $exception){$failed++;echo "[FAIL] {$name}: {$exception->getMessage()}\n";}}
function expect(bool $condition,string $message):void{if(!$condition)throw new RuntimeException($message);}

/** @return array{status:int,body:string,headers:array,setCookies:array} */
function httpRequest(string $url,string $method='GET',?string $body=null):array{
global $cookies;$headers=['Connection: close'];if($cookies!==[]){$pairs=[];foreach($cookies as $name=>$value){if($value!=='')$pairs[]=$name.'='.$value;}if($pairs!==[])$headers[]='Cookie: '.implode('; ',$pairs);}
if($body!==null)$headers[]='Content-Type: application/x-www-form-urlencoded';
$context=stream_context_create(['http'=>['method'=>$method,'header'=>implode("\r\n",$headers),'content'=>$body??'','ignore_errors'=>true,'timeout'=>5,'follow_location'=>0,'max_redirects'=>0]]);
$responseBody=@file_get_contents($url,false,$context);$responseHeaders=$http_response_header??[];
if($responseBody===false&&$responseHeaders===[])throw new RuntimeException('HTTP request failed: '.$url);
$status=0;if(isset($responseHeaders[0])&&preg_match('/\s([0-9]{3})\s/',$responseHeaders[0],$match))$status=(int)$match[1];
$setCookies=[];foreach($responseHeaders as $header){if(stripos($header,'Set-Cookie:')===0){$setCookie=trim(substr($header,strlen('Set-Cookie:')));$setCookies[]=$setCookie;if(preg_match('/^([^=;]+)=([^;]*)/',$setCookie,$match)){$cookieName=trim($match[1]);$cookieValue=trim($match[2]);if($cookieValue===''||preg_match('/(?:^|;)\s*Max-Age=0(?:;|$)/i',$setCookie))unset($cookies[$cookieName]);else $cookies[$cookieName]=$cookieValue;}}}
return ['status'=>$status,'body'=>is_string($responseBody)?$responseBody:'','headers'=>$responseHeaders,'setCookies'=>$setCookies];
}
function cookieHeader(array $setCookies,string $name):?string{foreach($setCookies as $cookie){if(preg_match('/^'.preg_quote($name,'/').'=[^;]*/i',$cookie))return $cookie;}return null;}
function hasCookieFlag(string $header,string $flag):bool{return(bool)preg_match('/(?:^|;)\s*'.preg_quote($flag,'/').'(?:;|$)/i',$header);}

try{
$ready=false;for($i=0;$i<40;$i++){$socket=@fsockopen('127.0.0.1',$port,$connectErrno,$connectError,0.2);if(is_resource($socket)){fclose($socket);$ready=true;break;}usleep(150000);}
if(!$ready){
$serverDiagnostic=is_file($serverStderrLog)?(string)file_get_contents($serverStderrLog):'no server stderr log';
throw new RuntimeException('PHP development server did not become ready: '.$serverDiagnostic);
}

$home=httpRequest($baseUrl.'/');
integrationTest('Home page responds with HTTP 200',static function()use($home,$serverStderrLog):void{
if($home['status']!==200){
$diagnostic=is_file($serverStderrLog)?(string)file_get_contents($serverStderrLog):'no server stderr log';
throw new RuntimeException('Expected HTTP 200, got '.$home['status'].'; body='.substr($home['body'],0,1200).'; server stderr='.$diagnostic);
}
});
$sessionCookie=cookieHeader($home['setCookies'],'CYBERSESSID');
integrationTest('Session Set-Cookie contains HttpOnly, Secure, and SameSite=Strict',static function()use($sessionCookie):void{expect(is_string($sessionCookie),'Session Set-Cookie missing');expect(hasCookieFlag($sessionCookie,'HttpOnly'),'HttpOnly missing');expect(hasCookieFlag($sessionCookie,'Secure'),'Secure missing');expect((bool)preg_match('/SameSite=Strict/i',$sessionCookie),'SameSite=Strict missing');});
$safeCookie=cookieHeader($home['setCookies'],'DEMO_SAFE');
integrationTest('Protected demo cookie is HttpOnly, Secure, and SameSite=Strict',static function()use($safeCookie):void{expect(is_string($safeCookie),'DEMO_SAFE missing');expect(hasCookieFlag($safeCookie,'HttpOnly'),'DEMO_SAFE HttpOnly missing');expect(hasCookieFlag($safeCookie,'Secure'),'DEMO_SAFE Secure missing');expect((bool)preg_match('/SameSite=Strict/i',$safeCookie),'DEMO_SAFE SameSite missing');});
$unsafeCookie=cookieHeader($home['setCookies'],'DEMO_UNSAFE');
integrationTest('Unprotected demo cookie intentionally exposes missing flags for comparison',static function()use($unsafeCookie):void{expect(is_string($unsafeCookie),'DEMO_UNSAFE missing');expect(!hasCookieFlag($unsafeCookie,'HttpOnly'),'DEMO_UNSAFE should not have HttpOnly');expect(!hasCookieFlag($unsafeCookie,'Secure'),'DEMO_UNSAFE should not have Secure');expect((bool)preg_match('/SameSite=Lax/i',$unsafeCookie),'DEMO_UNSAFE should use SameSite=Lax');});
integrationTest('Page includes JavaScript document.cookie probe and CSRF token',static function()use($home):void{expect(str_contains($home['body'],'cookie-probe.js'),'Cookie probe missing');expect((bool)preg_match('/name="csrf_token"\s+value="[a-f0-9]{64}"/',$home['body']),'CSRF input missing');});
integrationTest('Login POST without CSRF token is rejected with HTTP 403',static function()use($baseUrl):void{$response=httpRequest($baseUrl.'/login.php','POST','action=login');expect($response['status']===403,'Expected 403, got '.$response['status']);});
$homeForLogin=httpRequest($baseUrl.'/');preg_match('/name="csrf_token"\s+value="([a-f0-9]{64})"/',$homeForLogin['body'],$tokenMatch);$csrf=$tokenMatch[1]??'';$oldSessionId=$cookies['CYBERSESSID']??'';
integrationTest('Valid login POST rotates session ID and redirects',static function()use($baseUrl,$csrf,$oldSessionId):void{expect($csrf!=='','Could not extract CSRF token');$response=httpRequest($baseUrl.'/login.php','POST',http_build_query(['csrf_token'=>$csrf]));expect($response['status']===303,'Expected 303, got '.$response['status']);expect(in_array('Location: /dashboard.php',$response['headers'],true),'Dashboard redirect missing');global $cookies;expect(isset($cookies['CYBERSESSID']),'Rotated session cookie missing');expect($cookies['CYBERSESSID']!==$oldSessionId,'Session ID did not change');});
$dashboard=httpRequest($baseUrl.'/dashboard.php');
integrationTest('Authenticated session survives navigation to dashboard',static function()use($dashboard):void{expect($dashboard['status']===200,'Expected HTTP 200, got '.$dashboard['status']);expect(str_contains($dashboard['body'],'Demo Analyst'),'Authenticated user missing');expect(str_contains($dashboard['body'],'Session ID regenerated'),'Rotation confirmation missing');});
$activeSessionCookieValue=$cookies['CYBERSESSID']??'';
integrationTest('Dashboard shows a short fingerprint, not the session cookie value',static function()use($dashboard,$activeSessionCookieValue):void{expect((bool)preg_match('/[a-f0-9]{16}/',$dashboard['body']),'Fingerprint missing');expect($activeSessionCookieValue!==''&&!str_contains($dashboard['body'],$activeSessionCookieValue),'Raw session cookie value appears in HTML');});
preg_match('/name="csrf_token"\s+value="([a-f0-9]{64})"/',$dashboard['body'],$logoutMatch);$logoutToken=$logoutMatch[1]??'';
$logout=httpRequest($baseUrl.'/logout.php','POST',http_build_query(['csrf_token'=>$logoutToken]));
integrationTest('Logout destroys session and expires session cookie',static function()use($logout):void{expect($logout['status']===303,'Expected 303, got '.$logout['status']);$expiry=cookieHeader($logout['setCookies'],'CYBERSESSID');expect(is_string($expiry),'Session expiry Set-Cookie missing');expect((bool)preg_match('/Max-Age=0|Expires=/i',$expiry),'Session cookie was not expired');});
$afterLogout=httpRequest($baseUrl.'/dashboard.php');
integrationTest('Dashboard refuses access after logout',static function()use($afterLogout):void{expect($afterLogout['status']===303,'Expected redirect after logout, got '.$afterLogout['status']);});
echo sprintf("\nHTTP integration tests: %d | Passed: %d | Failed: %d\n",$passed+$failed,$passed,$failed);
}catch(Throwable $exception){$failed++;echo '[FAIL] HTTP integration harness: '.$exception->getMessage()."\n";}
finally{
if(is_resource($process)){if(isset($pipes[0])&&is_resource($pipes[0]))fclose($pipes[0]);proc_terminate($process);proc_close($process);}
foreach(glob($sessionPath.DIRECTORY_SEPARATOR.'*')?:[] as $file){if(is_file($file))@unlink($file);}
@rmdir($sessionPath);
}
exit($failed===0?0:1);
