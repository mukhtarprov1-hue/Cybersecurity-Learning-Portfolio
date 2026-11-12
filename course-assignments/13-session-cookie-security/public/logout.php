<?php
declare(strict_types=1);
require_once dirname(__DIR__).'/src/bootstrap.php';
if(($_SERVER['REQUEST_METHOD']??'GET')!=='POST'){header('Allow: POST');http_response_code(405);echo 'Method Not Allowed';exit;}
if(!SessionSecurity::verifyCsrf($_POST['csrf_token']??null)){http_response_code(403);echo 'CSRF validation failed.';exit;}
SessionSecurity::destroySession();
redirectTo('/index.php');
