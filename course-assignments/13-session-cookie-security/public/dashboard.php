<?php
declare(strict_types=1);
require_once dirname(__DIR__).'/src/bootstrap.php';
if(($_SESSION['authenticated']??false)!==true){redirectTo('/index.php');}
$csrf=SessionSecurity::csrfToken();
$fingerprint=(string)($_SESSION['session_id_fingerprint']??'not-recorded');
?>
<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>لوحة الجلسة المحمية — Assignment 13</title><link rel="stylesheet" href="/assets/style.css"></head>
<body><main class="container"><header class="hero"><p class="eyebrow">AUTHENTICATED DEMO SESSION</p><h1>لوحة الجلسة المحمية</h1><p class="muted">مرحباً <?=htmlEscape((string)($_SESSION['username']??'Demo Analyst'))?></p></header>
<section class="card"><h2>التحقق من استمرار الجلسة</h2><p class="success-text">نجح الانتقال إلى صفحة محمية مع الاحتفاظ بحالة الجلسة.</p>
<div class="settings-grid"><span>Session ID regenerated</span><strong><?=!empty($_SESSION['session_rotated_after_login'])?'YES':'NO'?></strong><span>Session fingerprint (SHA-256 prefix)</span><code><?=htmlEscape($fingerprint)?></code><span>Authenticated at (UTC)</span><code><?=htmlEscape((string)($_SESSION['authenticated_at']??''))?></code></div>
<p class="note">لا يعرض التطبيق Session ID الخام؛ يعرض بصمة مختصرة لأغراض التحقق فقط.</p>
<form method="post" action="/logout.php"><input type="hidden" name="csrf_token" value="<?=htmlEscape($csrf)?>"><button class="danger" type="submit">تسجيل الخروج وتدمير الجلسة</button></form>
<p><a href="/index.php">العودة إلى صفحة المقارنة</a></p></section></main></body></html>
