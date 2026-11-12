<?php
declare(strict_types=1);
require_once dirname(__DIR__).'/src/bootstrap.php';
$authenticated=($_SESSION['authenticated']??false)===true;
$csrf=SessionSecurity::csrfToken();
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Session &amp; Cookie Security Lab — Assignment 13</title>
<link rel="stylesheet" href="/assets/style.css"><script src="/assets/cookie-probe.js" defer></script>
</head>
<body><main class="container">
<header class="hero"><p class="eyebrow">CYBERSECURITY LEARNING PORTFOLIO · WEB &amp; PHP</p><h1>مختبر أمان الجلسات والكوكيز</h1><p class="muted">التكليف الثالث عشر — Session &amp; Cookie Security</p><div class="status-row"><span class="pill safe">Secure-by-default session</span><span class="pill">PHP <?=htmlEscape(PHP_VERSION)?></span></div></header>
<section class="card">
<h2>1. مقارنة خصائص الكوكيز</h2>
<p>يصدر الخادم كوكيين تجريبيين بقيم غير سرية للمقارنة. الكوكي الآمن لا يظهر في <code>document.cookie</code> لأنه يحمل HttpOnly، بينما الكوكي التعليمي غير المحمي قابل للقراءة JavaScript.</p>
<div class="comparison">
<article class="cookie-card safe-card"><h3>Protected cookie</h3><code>DEMO_SAFE</code><ul><li>HttpOnly: true</li><li>Secure: <?=SessionSecurity::secureCookiesEnabled()?'true':'false'?></li><li>SameSite: Strict</li></ul><span class="pill safe">Server-side only</span></article>
<article class="cookie-card unsafe-card"><h3>Unprotected demo cookie</h3><code>DEMO_UNSAFE</code><ul><li>HttpOnly: false</li><li>Secure: false</li><li>SameSite: Lax</li></ul><span class="pill warning">JavaScript-readable</span></article>
</div>
<div class="probe" aria-live="polite"><strong>نتيجة document.cookie:</strong><pre id="cookie-probe-result">جارٍ فحص الكوكيز من JavaScript...</pre><p id="cookie-probe-analysis" class="muted"></p></div>
<p class="note">الكوكي غير المحمي يحتوي علامة تجريبية عامة فقط، وليس رمز جلسة أو بيانات اعتماد.</p>
</section>
<section class="card"><h2>2. حالة الجلسة الحالية</h2>
<?php if($authenticated):?>
<p class="success-text">الجلسة مصادق عليها تجريبياً باسم <strong><?=htmlEscape((string)($_SESSION['username']??'Demo Analyst'))?></strong>.</p>
<p>تم تجديد معرف الجلسة بعد تسجيل الدخول: <strong><?=!empty($_SESSION['session_rotated_after_login'])?'نعم':'لا'?></strong></p>
<a class="button secondary" href="/dashboard.php">فتح لوحة الجلسة المحمية</a>
<?php else:?>
<p>لا توجد جلسة مصادق عليها حالياً. استخدم زر المحاكاة لإنشاء جلسة دخول تعليمية وتجديد معرفها.</p>
<form method="post" action="/login.php"><input type="hidden" name="csrf_token" value="<?=htmlEscape($csrf)?>"><button type="submit">محاكاة تسجيل الدخول وتجديد Session ID</button></form>
<?php endif;?>
</section>
<section class="card"><h2>3. إعدادات الجلسة التي يطبقها الخادم</h2>
<div class="settings-grid">
<span>Session cookie name</span><code>CYBERSESSID</code>
<span>HttpOnly</span><strong>true</strong>
<span>Secure</span><strong><?=SessionSecurity::secureCookiesEnabled()?'true':'false'?></strong>
<span>SameSite</span><strong>Strict</strong>
<span>session.use_strict_mode</span><strong><?=htmlEscape((string)ini_get('session.use_strict_mode'))?></strong>
<span>session.use_only_cookies</span><strong><?=htmlEscape((string)ini_get('session.use_only_cookies'))?></strong>
<span>session.use_trans_sid</span><strong><?=htmlEscape((string)ini_get('session.use_trans_sid'))?></strong>
</div>
<p class="note">SameSite ليس بديلاً عن رمز CSRF؛ يستخدم التطبيق كليهما مع التحقق من POST.</p>
</section>
<footer>مختبر تعليمي ببيانات اصطناعية. لا تستخدمه لإدارة حسابات حقيقية أو جلسات إنتاجية.</footer>
</main></body></html>
