# التحليل الأمني — DOM-based XSS

## مصدر البيانات ونقطة الإدراج

| العنصر | القيمة |
|---|---|
| Source | قيمة textarea عبر element.value |
| Unsafe sink | innerHTML |
| Safe sink | textContent |
| Safe element creation | document.createElement() |
| Safe insertion | appendChild() |
| Controlled execution proof | IMG onerror sends a fixed postMessage |
| Isolation | iframe sandbox with allow-scripts only |
| Parent isolation | no allow-same-origin; unique opaque origin |
| Network restriction | iframe CSP: connect-src 'none'; img-src data: |

## المخاطر

عندما تدمج بيانات غير موثوقة مع innerHTML، يقوم المتصفح بتحليلها كـ HTML وقد تنشأ عناصر أو سمات أحداث تؤدي إلى تنفيذ JavaScript. يمكن أن ينتج عن ذلك سرقة بيانات متاحة للسكريبت أو تنفيذ إجراءات ضمن سياق المستخدم، بحسب صلاحيات الصفحة ووجود ضوابط أخرى.

## الضابط الأساسي

لإدراج نص عادي، استخدم textContent. فهو ينشئ محتوى نصياً ولا يفسر السلسلة كـ HTML. إذا احتاج التطبيق HTML غنياً، فليستخدم منظف HTML معروفاً مع allow-list محددة، ولا ينفذ التعقيم اليدوي عبر regex.

## سبب استخدام iframe sandbox في المختبر

التكليف يطلب إثبات الخطر. بدلاً من تشغيل الحمولة داخل DOM الصفحة الرئيسية، تستخدم الأداة إطاراً ذا أصل معتم مع صلاحية scripts فقط. لا يسمح allow-same-origin، ولا توجد صلاحيات forms/popups/top-navigation، وتمنع CSP الاتصالات الخارجية. الدليل هو رسالة ثابتة من الإطار إلى الصفحة الأم بعد تنفيذ حدث onerror. لا تنقل الأداة بيانات ولا تحاول الوصول إلى الكوكيز.

## حدود الضوابط

- iframe sandbox لا يصلح تصميم تطبيق يستخدم innerHTML خارج المختبر.
- CSP وسيلة تخفيف وليست بديلاً عن معالجة المصدر إلى sink بشكل صحيح.
- DOM-XSS لا يتطلب دائماً علامة script؛ سمات الأحداث وسياقات HTML الأخرى قد تكون نقاط تنفيذ.
- لا يجب عرض بيانات حساسة في حمولات الاختبار أو لقطات الشاشة.