<?php
declare(strict_types=1);

$secureCookie = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
session_set_cookie_params([
    'httponly' => true,
    'secure' => $secureCookie,
    'samesite' => 'Strict',
    'path' => '/',
]);
session_start();

require_once dirname(__DIR__) . '/src/SecureUploadService.php';

header('Content-Type: text/html; charset=UTF-8');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store, max-age=0');
header("Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'");

if (!isset($_SESSION['csrf_token']) || !is_string($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

function escapeHtml(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function publicUploadMessage(string $code): string
{
    return match ($code) {
        'NO_FILE' => 'اختر ملفاً قبل الإرسال.',
        'FILE_TOO_LARGE' => 'حجم الملف يتجاوز الحد المسموح (2 MiB).',
        'PARTIAL_UPLOAD' => 'لم يكتمل رفع الملف. أعد المحاولة.',
        'EXTENSION_NOT_ALLOWED' => 'امتداد الملف غير مسموح. الأنواع المقبولة: PDF وPNG وJPG.',
        'MIME_MISMATCH' => 'المحتوى الفعلي لا يطابق الامتداد المعلن؛ تم رفض الملف.',
        'INVALID_IMAGE', 'SIGNATURE_MISMATCH', 'INVALID_PDF' => 'بنية الملف أو توقيعه غير صالح.',
        'IMAGE_DIMENSIONS_NOT_ALLOWED' => 'أبعاد الصورة تتجاوز الحد الآمن المسموح.',
        'EMPTY_FILE' => 'الملف فارغ ولا يمكن تخزينه.',
        'INVALID_FILE_SIZE' => 'تعذر التحقق من حجم الملف بشكل موثوق.',
        'INVALID_UPLOAD_SOURCE' => 'مصدر الملف ليس رفعاً صالحاً عبر HTTP.',
        default => 'تعذر قبول الملف. تحقق منه ثم أعد المحاولة.',
    };
}

$success = null;
$error = null;
try {
    $service = new SecureUploadService(
        dirname(__DIR__) . DIRECTORY_SEPARATOR . 'storage' . DIRECTORY_SEPARATOR . 'private',
        __DIR__
    );

    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
        $submittedToken = $_POST['csrf_token'] ?? null;
        if (!is_string($submittedToken) || !hash_equals($_SESSION['csrf_token'], $submittedToken)) {
            http_response_code(403);
            $error = 'انتهت صلاحية نموذج الرفع أو لم يكن الطلب صالحاً. حدّث الصفحة وحاول مجدداً.';
        } else {
            try {
                $success = $service->storeUploadedFile($_FILES['file_uploaded'] ?? []);
                // Rotate the token after a successful state-changing request.
                $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
            } catch (UploadRejectedException $exception) {
                http_response_code(400);
                $error = publicUploadMessage($exception->errorCode);
            } catch (Throwable $exception) {
                error_log('Assignment 12 upload failure: ' . get_class($exception));
                http_response_code(500);
                $error = 'حدث خطأ داخلي أثناء معالجة الملف. لم يتم عرض تفاصيل الخادم.';
            }
        }
    } elseif (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
        header('Allow: GET, POST');
        http_response_code(405);
        $error = 'طريقة الطلب غير مدعومة.';
    }
} catch (Throwable $exception) {
    error_log('Assignment 12 initialization failure: ' . get_class($exception));
    http_response_code(500);
    $error = 'خدمة رفع الملفات غير متاحة حالياً.';
}

$csrfToken = (string) ($_SESSION['csrf_token'] ?? '');
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>نظام رفع الملفات الآمن | التكليف 12</title>
    <style>
        :root { color-scheme: light; font-family: Tahoma, Arial, sans-serif; }
        body { margin: 0; background: #f3f6fa; color: #172033; }
        main { width: min(760px, calc(100% - 32px)); margin: 48px auto; }
        .panel { background: #fff; border: 1px solid #dce4ef; border-radius: 16px; padding: 28px; box-shadow: 0 12px 34px rgb(22 35 58 / 7%); }
        h1 { margin-top: 0; font-size: 1.65rem; }
        p, li { line-height: 1.8; }
        .hint { color: #526078; }
        label { display: block; font-weight: 700; margin: 20px 0 8px; }
        input[type=file] { display: block; width: 100%; padding: 14px; border: 1px dashed #9aabc2; border-radius: 10px; background: #f8fafc; box-sizing: border-box; }
        button { margin-top: 18px; border: 0; background: #173e70; color: #fff; padding: 12px 22px; border-radius: 9px; font-size: 1rem; cursor: pointer; }
        .notice { margin-top: 20px; padding: 14px 16px; border-radius: 10px; border: 1px solid; }
        .error { color: #842029; background: #fff1f1; border-color: #f0b8bd; }
        .success { color: #155b38; background: #effbf4; border-color: #a9dfbf; }
        code { direction: ltr; unicode-bidi: plaintext; overflow-wrap: anywhere; }
        .layers { background: #f6f8fc; padding: 14px 20px; border-radius: 10px; }
        footer { margin-top: 18px; color: #66738a; font-size: .9rem; }
    </style>
</head>
<body>
<main>
    <section class="panel">
        <h1>نظام رفع الملفات الآمن</h1>
        <p class="hint">التكليف الثاني عشر — مسار البرمجة للأمن السيبراني / Web &amp; PHP</p>
        <p>ارفع ملفاً تعليمياً من الأنواع المسموحة. يفحص الخادم الملف قبل نقله إلى مساحة تخزين خاصة خارج مجلد الويب.</p>

        <ul class="layers">
            <li>الحد الأقصى للحجم: <strong>2 MiB</strong>.</li>
            <li>قائمة الامتدادات المسموحة: <strong>PDF, PNG, JPG, JPEG</strong>.</li>
            <li>فحص MIME الفعلي باستخدام PHP Fileinfo.</li>
            <li>التحقق من توقيع الملف وبنية الصور وأبعادها.</li>
            <li>اسم عشوائي باستخدام <code>bin2hex(random_bytes(16))</code>.</li>
            <li>تخزين خاص مع منع تنفيذ/عرض الملفات من هذا التطبيق.</li>
        </ul>

        <?php if ($error !== null): ?>
            <div class="notice error" role="alert"><?= escapeHtml($error) ?></div>
        <?php endif; ?>

        <?php if (is_array($success)): ?>
            <div class="notice success" role="status">
                <strong>تم قبول الملف وتخزينه بنجاح.</strong>
                <p>الاسم الأصلي: <code><?= escapeHtml($success['original_name']) ?></code></p>
                <p>الاسم المخزن: <code><?= escapeHtml($success['stored_name']) ?></code></p>
                <p>نوع MIME: <code><?= escapeHtml($success['mime']) ?></code></p>
                <p>الحجم: <code><?= (int) $success['size'] ?></code> bytes</p>
                <p>مكان التخزين غير مكشوف عبر رابط عام.</p>
            </div>
        <?php endif; ?>

        <form method="post" enctype="multipart/form-data">
            <input type="hidden" name="csrf_token" value="<?= escapeHtml($csrfToken) ?>">
            <label for="file_uploaded">اختر ملفاً (PDF / PNG / JPG)</label>
            <input id="file_uploaded" name="file_uploaded" type="file" accept=".pdf,.png,.jpg,.jpeg,application/pdf,image/png,image/jpeg" required>
            <button type="submit">فحص ورفع الملف</button>
        </form>
        <footer>ملاحظة: هذا نموذج تدريبي محلي. لا ترفع ملفات شخصية أو سرية.</footer>
    </section>
</main>
</body>
</html>
