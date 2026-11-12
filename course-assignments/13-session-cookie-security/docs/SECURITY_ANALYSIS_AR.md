# التحليل الأمني — Session & Cookie Security

## نموذج تهديد مختصر

| الأصل | التهديد | الضابط |
|---|---|---|
| Session ID | سرقته عبر JavaScript في حال XSS | HttpOnly يمنع قراءة القيمة عبر document.cookie |
| Session ID | Session Fixation | session_regenerate_id(true) عند الدخول |
| Session ID | تمريره في URL أو قبول معرف غير موثوق | session.use_only_cookies وsession.use_trans_sid=0 وstrict mode |
| Cookie في الشبكة | التقاط الكوكي عبر اتصال غير مشفر | Secure=true وHTTPS |
| Cookie في طلب cross-site | إرسال الجلسة في سياق خارجي | SameSite=Strict إضافة إلى CSRF token |
| عمليات POST | CSRF | رمز عشوائي مرتبط بالجلسة، تحقق hash_equals، تدوير الرمز |
| واجهة العرض | XSS عند طباعة القيم | htmlspecialchars وCSP ومنع inline JavaScript |
| معلومات الجلسة | تسريب المعرف عبر HTML | عرض بصمة SHA-256 مختصرة فقط |

## لماذا الكوكي غير المحمي؟

الكوكي DEMO_UNSAFE قيمة تعليمية عامة وغير سرية، أُنشئت حصراً لإظهار أن الكوكي الذي لا يحمل HttpOnly يمكن أن يظهر في document.cookie. لا تحمل هذه القيمة Session ID أو بيانات اعتماد، ولا يستخدمها التطبيق للمصادقة.

## ملاحظات مهمة

- HttpOnly لا يزيل ثغرات XSS ولا يمنع المهاجم من استخدام المتصفح المصاب لإرسال طلبات مصادق عليها.
- SameSite Strict قد يؤثر في تدفقات دخول خارجية مثل OAuth أو روابط العودة؛ يجب اختيار السياسة بناءً على المتطلبات الفعلية.
- Secure يجب أن يظل مفعلاً في الإنتاج ويستلزم HTTPS. لا يستخدم تعطيل Secure كحل دائم لتسهيل HTTP المحلي.
- CSRF token يجب أن يكون عشوائياً وغير متوقع ومرتبطاً بالجلسة؛ لا يوضع في URL.
- تجديد Session ID بعد تسجيل الدخول يقلل Session Fixation، ويجب تكراره عند تغير مستوى الصلاحيات الحساسة.
- المختبر لا يقدم مصادقة مستخدمين حقيقية؛ يجب عدم وضع كلمات مرور حقيقية أو استخدامه كبوابة إنتاجية.