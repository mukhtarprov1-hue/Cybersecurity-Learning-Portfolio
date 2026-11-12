<?php

declare(strict_types=1);

require_once __DIR__ . '/src/Database.php';
require_once __DIR__ . '/src/UserSearch.php';

use SqliDefense\Database;
use SqliDefense\UserSearch;

header('Content-Type: text/html; charset=UTF-8');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: strict-origin-when-cross-origin');
header("Content-Security-Policy: default-src 'self'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'");

function e(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

$pdo = null;
$startupError = null;
$errorMessage = null;
$results = [];
$username = '';
$mode = 'safe';
$submitted = array_key_exists('username', $_GET);

try {
    $pdo = Database::create();
} catch (Throwable $exception) {
    error_log('[Assignment 11] Database initialization failed: ' . $exception->getMessage());
    $startupError = 'تعذر تهيئة قاعدة البيانات التجريبية. تحقق من تفعيل امتداد PDO_SQLITE.';
}

if ($submitted && $pdo instanceof PDO) {
    $rawUsername = $_GET['username'] ?? '';
    $rawMode = $_GET['mode'] ?? 'safe';

    $username = is_string($rawUsername) ? $rawUsername : '';
    $mode = is_string($rawMode) && in_array($rawMode, ['safe', 'unsafe'], true)
        ? $rawMode
        : 'safe';

    if (strlen($username) > 120) {
        $errorMessage = 'المدخل أطول من الحد المسموح (120 بايت).';
    } else {
        try {
            $results = $mode === 'unsafe'
                ? UserSearch::unsafeSearch($pdo, $username)
                : UserSearch::safeSearch($pdo, $username);
        } catch (Throwable $exception) {
            error_log('[Assignment 11] Search failed: ' . $exception->getMessage());
            $errorMessage = 'تعذّر تنفيذ البحث. لم يتم عرض تفاصيل قاعدة البيانات أو بنية الجدول.';
        }
    }
}

$modeLabel = $mode === 'unsafe'
    ? 'غير آمن — دمج النص داخل SQL'
    : 'آمن — PDO Prepared Statement';
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>SQLi Defense | Assignment 11</title>
    <style>
        :root { color-scheme: light; --ink:#172033; --muted:#5b667a; --line:#dce3ed; --panel:#f5f8fc; --blue:#155eef; --red:#b42318; --green:#067647; }
        * { box-sizing:border-box; }
        body { margin:0; background:#edf2f8; color:var(--ink); font-family:Tahoma,Arial,sans-serif; line-height:1.7; }
        main { width:min(980px, calc(100% - 32px)); margin:34px auto; }
        .hero,.panel { background:#fff; border:1px solid var(--line); border-radius:16px; padding:24px; margin-bottom:18px; box-shadow:0 8px 24px rgba(16,24,40,.05); }
        h1 { margin:0 0 6px; font-size:28px; }
        h2 { margin-top:0; font-size:20px; }
        .muted { color:var(--muted); }
        .tag { display:inline-block; border-radius:999px; padding:3px 11px; font-size:13px; background:#eaf1ff; color:#1849a9; }
        .warning { border-right:4px solid var(--red); background:#fff4f2; padding:12px 15px; border-radius:8px; color:#7a271a; }
        .success { border-right:4px solid var(--green); background:#ecfdf3; padding:12px 15px; border-radius:8px; color:#05603a; }
        label { display:block; font-weight:700; margin:12px 0 6px; }
        input[type=text],select { width:100%; padding:12px; border:1px solid #b8c4d6; border-radius:9px; font:inherit; background:#fff; }
        button { margin-top:14px; padding:11px 20px; border:0; border-radius:9px; background:var(--blue); color:#fff; font:inherit; font-weight:700; cursor:pointer; }
        button:hover { filter:brightness(.94); }
        code,pre { direction:ltr; text-align:left; background:#f3f5f9; border:1px solid var(--line); border-radius:8px; padding:3px 7px; overflow-wrap:anywhere; }
        pre { padding:14px; white-space:pre-wrap; }
        table { width:100%; border-collapse:collapse; margin-top:12px; font-size:14px; }
        th,td { border-bottom:1px solid var(--line); text-align:right; padding:10px; }
        th { background:var(--panel); }
        .result-count { font-weight:700; margin-top:16px; }
        footer { color:var(--muted); text-align:center; font-size:13px; margin:24px; }
        @media (max-width:600px) { .hero,.panel { padding:17px; } h1 { font-size:23px; } table { font-size:12px; } th,td { padding:7px; } }
    </style>
</head>
<body>
<main>
    <section class="hero">
        <span class="tag">Cybersecurity Programming · Web &amp; PHP</span>
        <h1>أداة الحماية من حقن قواعد البيانات</h1>
        <p class="muted">Assignment 11 — SQL Injection Defense (SQLi Defense)</p>
        <p>قارن بين استعلام يدمج مدخل المستخدم مباشرة داخل SQL واستعلام آمن يفصل البيانات عن كود الاستعلام باستخدام PDO.</p>
        <div class="warning"><strong>مختبر تعليمي محلي فقط:</strong> الوضع غير الآمن متعمد لإظهار الخلل، ويعمل على قاعدة SQLite مؤقتة ببيانات اصطناعية فقط. لا تستخدمه مع بيانات حقيقية أو في بيئة إنتاج.</div>
    </section>

    <section class="panel">
        <h2>اختبار البحث عن مستخدم</h2>
        <form method="get" action="">
            <label for="username">اسم المستخدم</label>
            <input
                id="username"
                name="username"
                type="text"
                maxlength="120"
                value="<?= e($username) ?>"
                placeholder="مثال: alice"
                autocomplete="off"
                required
            >

            <label for="mode">طريقة تنفيذ الاستعلام</label>
            <select id="mode" name="mode">
                <option value="safe" <?= $mode === 'safe' ? 'selected' : '' ?>>آمن — PDO Prepared Statement</option>
                <option value="unsafe" <?= $mode === 'unsafe' ? 'selected' : '' ?>>غير آمن — String Concatenation (للتوضيح فقط)</option>
            </select>

            <button type="submit">تنفيذ البحث</button>
        </form>

        <p class="muted">قيمة اختبار الحقن المقترحة:</p>
        <pre>' OR '1'='1' -- </pre>
        <p class="muted">انسخ القيمة أعلاه إلى حقل اسم المستخدم، ثم جرّبها في الوضعين.</p>
    </section>

    <?php if ($startupError !== null): ?>
        <section class="panel warning"><?= e($startupError) ?></section>
    <?php endif; ?>

    <?php if ($errorMessage !== null): ?>
        <section class="panel warning"><?= e($errorMessage) ?></section>
    <?php endif; ?>

    <?php if ($submitted && $errorMessage === null && $startupError === null): ?>
        <section class="panel">
            <h2>نتيجة الاختبار</h2>
            <p><strong>الوضع:</strong> <?= e($modeLabel) ?></p>
            <?php if ($mode === 'unsafe'): ?>
                <div class="warning">هذا المسار ضعيف عمداً: جرى دمج المدخل مباشرة في نص SQL. ظهور سجلات متعددة مع حمولة الحقن يثبت أثر تغيير منطق الشرط.</div>
            <?php else: ?>
                <div class="success">المسار الآمن يستخدم معاملاً مجهزاً؛ قيمة المستخدم تعامل كنص واحد ولا تتحول إلى تعليمة SQL.</div>
            <?php endif; ?>

            <p class="result-count">عدد السجلات المسترجعة: <?= count($results) ?></p>
            <?php if ($results === []): ?>
                <p class="muted">لا توجد سجلات مطابقة لاسم المستخدم المدخل.</p>
            <?php else: ?>
                <div style="overflow-x:auto">
                    <table>
                        <thead>
                            <tr><th>ID</th><th>Username</th><th>Email</th><th>Role</th></tr>
                        </thead>
                        <tbody>
                        <?php foreach ($results as $row): ?>
                            <tr>
                                <td><?= e((string) $row['id']) ?></td>
                                <td><?= e((string) $row['username']) ?></td>
                                <td><?= e((string) $row['email']) ?></td>
                                <td><?= e((string) $row['role']) ?></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </section>
    <?php endif; ?>

    <section class="panel">
        <h2>ما الذي يثبته المختبر؟</h2>
        <ul>
            <li>الدمج النصي يسمح للمدخل بتغيير منطق جملة <code>WHERE</code> في الوضع غير الآمن.</li>
            <li><code>prepare()</code> ينشئ الاستعلام بمعامل مستقل، و<code>execute()</code> يمرر قيمة المستخدم كبيانات.</li>
            <li>قاعدة البيانات مؤقتة داخل الذاكرة، وتُعاد تهيئتها عند كل طلب.</li>
            <li>تُهرب القيم المعروضة في HTML، ولا تُرسل تفاصيل أخطاء PDO إلى المتصفح.</li>
        </ul>
    </section>

    <footer>Assignment 11 · SQLi Defense · Synthetic data · Local training only</footer>
</main>
</body>
</html>
