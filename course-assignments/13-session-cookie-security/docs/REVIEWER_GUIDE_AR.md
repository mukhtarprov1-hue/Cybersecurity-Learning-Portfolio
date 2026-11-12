# دليل المدرب — مراجعة التكليف 13 خلال خمس دقائق

1. افتح src/SessionSecurity.php وتحقق أن خيارات الكوكي تضبط قبل session_start() وأن HttpOnly/Secure/SameSite=Strict مفعلة.
2. افتح public/index.php وشاهد المقارنة بين DEMO_SAFE وDEMO_UNSAFE.
3. راجع public/assets/cookie-probe.js: يعرض ما يستطيع JavaScript قراءته من document.cookie، ومن المتوقع ألا تظهر الكوكيز المحمية HttpOnly.
4. نفّذ محاكاة تسجيل الدخول. راجع public/login.php وتأكد من session_regenerate_id(true) قبل وضع حالة المصادقة.
5. افتح لوحة التحكم، ولاحظ استمرار الجلسة وعرض بصمة مختصرة بدلاً من Session ID الخام.
6. سجّل الخروج ثم حاول فتح لوحة التحكم مباشرة؛ يجب أن يعود التطبيق إلى صفحة البداية.
7. راجع tests/http_integration.php لترى الفحص الآلي لترويسات Set-Cookie ورفض CSRF وتدوير المعرف واستمرار الجلسة.

## حد نطاقي صريح

زر تسجيل الدخول محاكاة تعليمية لاختبار Session Fixation. لا توجد مصادقة مستخدم حقيقية ولا يجب اعتبار المشروع نظام دخول إنتاجياً.