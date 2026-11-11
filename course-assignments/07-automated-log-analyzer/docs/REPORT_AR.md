# التقرير العملي — التكليف السابع
## أداة تحليل السجلات الأمنية المؤتمتة (Automated Log Analyzer)

**اللغة:** Python  
**المجال:** Security Operations Center (SOC) / Web Log Analysis  
**بيئة التحقق الفعلية:** Windows PowerShell  
**تاريخ التحقق:** 12 نوفمبر 2026  
**مصدر البيانات:** ملف سجل اصطناعي مرفق بالمشروع، وليس سجلات إنتاج حقيقية.

## 1. الهدف

إنشاء أداة تقرأ سجل خادم ويب سطراً بسطر وتبحث عن مؤشرات محددة لهجمات SQL Injection وPath Traversal باستخدام التعبيرات النمطية. عند العثور على مؤشر، تطبع تنبيهاً يتضمن نوع الهجوم ورقم السطر وعنوان IP المسجل والدليل المطابق. وفي النهاية تعرض ملخصاً بعدد الأسطر المفحوصة والتنبيهات حسب الفئة.

## 2. آلية التنفيذ

### 2.1 القراءة المتدفقة

يستخدم البرنامج مدير السياق with مع Path.open()، ثم يمر على كائن الملف مباشرة. لا يستدعي read() لتحميل كامل الملف، بل يعالج كل سطر على حدة.

### 2.2 قواعد الكشف

تُعرّف القواعد باستخدام re.compile(..., re.IGNORECASE) وتُطبق بواسطة Pattern.search().

| الفئة | المؤشرات التي يغطيها الإصدار |
|---|---|
| SQL Injection | UNION SELECT، مقارنات Boolean من نوع OR/AND، الدوال SLEEP() وBENCHMARK()، LOAD_FILE() وINTO OUTFILE. |
| Path Traversal | التسلسل ../ أو ..\ وصيغ URL-encoded الشائعة مثل %2e%2e%2f و%2e%2e%5c. |

يفحص البرنامج السطر الأصلي ونسخة URL-decoded منه بواسطة unquote_plus للمساعدة على اكتشاف بعض الحمولات المشفرة. وتُحفظ عينة السجل الأصلية في التنبيه للمراجعة.

### 2.3 استخراج عنوان المصدر

يفترض البرنامج أن الحقل الأول من السجل هو عنوان العميل، وهو تنسيق شائع في سجلات Apache/Nginx. يتحقق من القيمة باستخدام ipaddress.ip_address() ويدعم IPv4 وIPv6. إذا لم يكن الحقل الأول عنوان IP صالحاً، يستخدم UNKNOWN بدلاً من تخمين عنوان من بقية السطر.

### 2.4 التنبيهات والملخص

لكل فئة تطابق على السطر، يطبع البرنامج تنبيهاً يتضمن نوع الهجوم ورقم السطر وعنوان IP والنص المطابق ومقتطفاً من السجل. إذا طابق السطر نفسه أكثر من فئة، يصدر تنبيهاً مستقلاً لكل فئة. ويحسب الملخص عدد الأسطر المفحوصة، والأسطر المشبوهة المميزة، وإجمالي التنبيهات، وعدد التنبيهات لكل نوع.

## 3. ملفات المشروع

| الملف | الوظيفة |
|---|---|
| log_analyzer.py | البرنامج الرئيسي وقواعد Regex وتحليل السجلات والتقارير. |
| tests/test_log_analyzer.py | اختبارات كشف الهجمات واستخراج IP والملخص وأخطاء الملفات. |
| samples/sample_access.log | سجل اصطناعي يضم طلبات طبيعية ومؤشرات هجوم مع عناوين IP توثيقية. |
| docs/sample_report.json | تقرير JSON تم توليده من عينة السجل باستخدام البرنامج. |
| TASK_SPEC_AR.md | توثيق متطلبات التكليف بالعربية. |
| docs/TEST_RESULTS.md | نتائج التحقق الفعلية على Windows. |
| docs/TRACEABILITY.md | ربط متطلبات التكليف بالتنفيذ والاختبار. |

## 4. طريقة التشغيل على Windows

من مجلد التكليف:

    python log_analyzer.py --help
    python -m py_compile log_analyzer.py tests\test_log_analyzer.py
    python -m unittest discover -s tests -v
    python log_analyzer.py samples\sample_access.log
    python log_analyzer.py samples\sample_access.log --format json
    python log_analyzer.py samples\sample_access.log --format json --output docs\sample_report.json

ولتحليل سجل آخر، استخدم ملفاً تملكه أو لديك تصريح بتحليله:

    python log_analyzer.py "C:\Logs\access.log"

## 5. نتائج التشغيل الفعلية على Windows

تم تشغيل البرنامج على العينة samples\sample_access.log من PowerShell. أظهر الملخص:

| المؤشر | النتيجة |
|---|---:|
| Lines scanned | 6 |
| Suspicious lines | 4 |
| Total alerts | 4 |
| SQL Injection | 2 |
| Path Traversal | 2 |
| سجلات طبيعية تم تجاهلها | 2 |

التنبيهات المفصلة:

| رقم السطر | Source IP | النوع | الدليل |
|---:|---|---|---|
| 2 | 198.51.100.23 | SQL Injection | UNION SELECT |
| 3 | 203.0.113.7 | Path Traversal | ../../ |
| 4 | 198.51.100.81 | SQL Injection | ' OR '1'='1 |
| 6 | 192.0.2.45 | Path Traversal | %2e%2e%2f |

عناوين IP المستخدمة في ملف العينة من نطاقات توثيقية مخصصة للأمثلة، ولا تمثل مصادر حقيقية. السجل اصطناعي ولا يوثق حادثة أمنية فعلية.

### 5.1 إخراج JSON

تم تنفيذ الأمر:

    python log_analyzer.py samples\sample_access.log --format json

وأنتج مخرجات JSON صحيحة تتضمن lines_scanned وsuspicious_lines وtotal_alerts وcounts_by_type ومصفوفة alerts بالتفاصيل.

كما تم تنفيذ:

    python log_analyzer.py samples\sample_access.log --format json --output docs\sample_report.json

وأعاد البرنامج رسالة:

    Report saved to: docs\sample_report.json

## 6. نتائج فحص الصياغة واختبارات الوحدة على Windows

تم تنفيذ الأمر التالي دون ظهور أخطاء:

    python -m py_compile log_analyzer.py tests\test_log_analyzer.py

ثم نفذ الطالب:

    python -m unittest discover -s tests -v

النتيجة الفعلية:

    Ran 15 tests in 0.034s

    OK

- الاختبارات الناجحة: 15.
- الاختبارات الفاشلة: 0.
- الاختبارات المتخطاة: 0.

وتغطي الاختبارات كشف UNION SELECT وBoolean SQL Injection وSLEEP()، وكشف Path Traversal الصريح والمشفر، واستبعاد السجلات الطبيعية، واستخراج IPv4 وIPv6، والتعامل مع عناوين غير صالحة، وترقيم الأسطر، وتعدد أنواع التنبيهات، وقراءة الملف باستخدام context manager، ومعالجة الملف المفقود، وصحة التقرير النصي وJSON.

## 7. اعتبارات الدقة والحدود

- Regex-based detection تعتمد على مؤشرات محددة؛ لا تكشف كل أشكال الهجمات أو جميع طرق التمويه.
- وجود مؤشر في سجل HTTP لا يثبت نجاح الهجوم أو حدوث اختراق.
- بعض النصوص الشرعية قد تشبه الحمولات الهجومية؛ التنبيه يحتاج إلى مراجعة سياقية من محلل SOC.
- يفترض استخراج IP أن الحقل الأول هو عنوان العميل. تنسيقات السجلات المخصصة قد تتطلب parser مختلفاً.
- لا تقوم الأداة بإجراء اتصالات شبكية أو بتعديل ملفات السجل.
- لا تستخدم هذه الأداة كبديل عن SIEM أو WAF أو التحليل الجنائي الكامل.

## 8. الخلاصة

تم تنفيذ أداة تحليل سجلات الويب واختبارها فعلياً على Windows باستخدام عينة اصطناعية. نجحت في كشف مؤشري SQL Injection ومؤشري Path Traversal، وربط كل تنبيه برقم السطر وعنوان IP، واستبعاد السجلين الطبيعيين. اجتاز فحص الصياغة دون أخطاء، كما اجتازت اختبارات الوحدة الخمسة عشر جميعها. وتم إنشاء تقرير JSON وحفظه في مجلد docs. تمثل النتائج مؤشرات تحتاج إلى مراجعة محلل SOC، وليست حكماً بأن الهجوم نجح.
