# التقرير العملي — التكليف العاشر
## أداة معالجة طلبات HTTP وبناء REST API باستخدام PHP

**المجال:** Web & PHP / Cybersecurity Programming Track  
**المعيار:** REST over HTTP  
**الحد الأدنى للتشغيل:** PHP 8.2+  
**إصدار PHP المستهدف في CI:** 8.2 و8.5  
**الاعتماديات:** PHP JSON extension، دون مكتبات خارجية.

## 1. الملخص التنفيذي

يبني المشروع API فعلية لإدارة موارد بسيطة باستخدام نمط CRUD. يستقبل الخادم طلب HTTP، يقرأ الطريقة والترويسات والجسم، يتحقق من الهوية وصحة البيانات، ينفذ العملية المطلوبة، ثم يعيد JSON منسقاً مع حالة HTTP مناسبة. لا تقتصر الأداة على طباعة أمثلة؛ بل تحفظ عناصر فعلية في مخزن JSON محلي وتوفر سجل تدقيق.

## 2. البنية المعمارية

- `public/index.php`: نقطة دخول HTTP، قراءة `REQUEST_METHOD` والترويسات و`php://input` وإرسال الاستجابة.
- `router.php`: توجيه مسارات الخادم المدمج إلى نقطة الدخول.
- `src/ApiApplication.php`: المسارات، المصادقة، التحقق، وحالات HTTP.
- `src/ItemRepository.php`: CRUD والتخزين المقفل والكتابة المؤقتة.
- `src/AuditLogger.php`: سجل أحداث JSONL مع حجب بيانات الاعتماد.
- `src/ApiResponse.php` و`src/ApiException.php`: نماذج الاستجابة والأخطاء.

## 3. المسارات المدعومة

| Method | Endpoint | الوظيفة | النجاح |
|---|---|---|---:|
| GET | `/api/health` | حالة الخدمة | 200 |
| GET | `/api/items` | قائمة العناصر مع `q` و`limit` | 200 |
| POST | `/api/items` | إنشاء عنصر | 201 |
| GET | `/api/items/{uuid}` | قراءة عنصر | 200 |
| PUT | `/api/items/{uuid}` | تحديث بيانات عنصر | 200 |
| DELETE | `/api/items/{uuid}` | حذف عنصر | 204 |
| OPTIONS | المسارات | CORS preflight / Allow | 204 |

تتطلب عمليات POST وPUT وDELETE ترويسة `Authorization: Bearer <token>`. إذا لم يُضبط `API_TOKEN`، يرفض الخادم الكتابة بحالة 503 بدلاً من السماح غير المقصود.

## 4. التحقق والأمان

- التحقق من `Content-Type: application/json` قبل تحليل الجسم.
- استخدام `json_decode(..., JSON_THROW_ON_ERROR)` للكشف المنضبط عن JSON غير الصحيح.
- رفض الحقول غير المعروفة والتحقق من UTF-8 والأطوال والقيم المسموح بها.
- تحديد جسم الطلب إلى 64 KiB.
- مقارنة Bearer token باستخدام `hash_equals()`.
- إرجاع `405` مع `Allow` و`401` مع `WWW-Authenticate` و`201` مع `Location`.
- إضافة `X-Request-ID` و`X-Content-Type-Options` و`X-Frame-Options` و`Referrer-Policy` و`Cache-Control`.
- تطبيق CORS allow-list دون اعتباره بديلاً عن المصادقة.
- استخدام UUIDv4 للمعرفات، و`flock()` لحماية الكتابة المتزامنة، وملف مؤقت قبل تحديث مخزن البيانات.
- حفظ سجلات التدقيق دون تخزين Authorization أو JSON body.

## 5. طريقة التشغيل

في نافذة PowerShell أولى من مجلد المشروع:

    $env:API_TOKEN = 'Replace-This-With-A-Long-Unique-Local-Training-Token'
    php -S 127.0.0.1:8080 router.php

ثم من نافذة ثانية:

    Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:8080/api/health'

تُضبط قيمة التوكن نفسها في نافذة العميل عند تجربة عمليات الكتابة. راجع `README.md` و`scripts/demo.ps1` للتجربة المتكاملة.

## 6. الاختبارات

تشغل الاختبارات بواسطة:

    php -l public/index.php
    php -l router.php
    php tests/run.php

تغطي مجموعة الاختبارات CRUD، المصادقة، JSON غير الصحيح، نوع المحتوى، التحقق من الحقول، CORS، `OPTIONS`، رؤوس الأمان، معرف الطلب، وحد حجم الجسم. يتم تسجيل نتيجة التنفيذ الفعلية بعد تشغيل الطالب محلياً؛ لا تعتبر نتائج CI بديلاً عن توثيق تجربة Windows.

## 7. حدود المشروع

هذا مشروع تدريبي محلي. خادم PHP المدمج ليس خادم إنتاج. يستخدم المشروع ملف JSON بدلاً من قاعدة بيانات لتسهيل شرح البروتوكول ودورة حياة الطلب. في بيئة إنتاج، يلزم HTTPS، وإدارة أسرار، وهوية وصلاحيات لكل مستخدم، وقاعدة بيانات معاملاتية، ومراقبة مركزية، وسياسة تدوير للتوكن.
