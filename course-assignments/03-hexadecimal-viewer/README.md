# التكليف الثالث: عارض الملفات الثنائية بصيغة Hexadecimal Viewer

**معسكر الأمن السيبراني 2026 | C17 | CLI | Binary File Analysis**

أداة سطر أوامر بلغة C تقرأ ملفاً ثنائياً دون تحويله إلى نص، ثم تعرض كل بايت بصيغتين متوازيتين: القيمة السداسية عشرية (Hexadecimal) والتمثيل المقابل للأحرف القابلة للطباعة (ASCII). تقرأ الأداة 16 بايت في كل صف، وتعرض إزاحة البايت (Offset) لمعرفة موضعه داخل الملف.

## محتويات التكليف

```text
Hexadecimal_Viewer_C/
├── hex_viewer.c
├── README.md
├── .gitignore
├── samples/
│   ├── README.md
│   └── create_sample.py
├── tests/
│   └── run_tests.py
├── docs/
│   └── REPORT_AR.md
├── evidence/
│   ├── build-and-test.log
│   ├── sample-run.log
│   ├── missing-file.log
│   └── argument-validation.log
├── screenshots/
│   ├── 01-sample-output.svg
│   ├── 02-missing-file.svg
│   ├── 03-argument-validation.svg
│   └── 04-automated-tests.svg
└── tools/
    └── render_evidence.py
```

## المتطلبات التي ينفذها الحل

| متطلب التكليف | التنفيذ |
|---|---|
| استقبال الملف عبر argc وargv | يتحقق البرنامج من وجود وسيط واحد لاسم الملف |
| فتح الملف في وضع القراءة الثنائية | fopen(argv[1], "rb") |
| قراءة 16 بايت في كل دورة | fread(buffer, 1, sizeof buffer, file) داخل while |
| عرض Hex | printf("%02X", ...) لكل بايت |
| عرض ASCII | الأحرف من 32 إلى 126 كما هي، وما عداها يظهر كنقطة (.) |
| معالجة عدم وجود الملف | فحص file == NULL واستخدام perror() |
| إغلاق الملف | fclose() مع فحص نتيجة الإغلاق |
| التعامل مع الصف الأخير | حشو الخانات الناقصة للمحافظة على المحاذاة دون قراءة بيانات زائدة |

## البناء والتشغيل

### Windows — MSYS2 UCRT64

من داخل مجلد التكليف:

```bash
gcc -std=c17 -Wall -Wextra -Wpedantic -Werror -O2 hex_viewer.c -o hex_viewer.exe
python tests/run_tests.py ./hex_viewer.exe
python samples/create_sample.py
./hex_viewer.exe samples/signature_sample.bin
```

### Linux / Kali Linux

```bash
gcc -std=c17 -Wall -Wextra -Wpedantic -Werror -O2 hex_viewer.c -o hex_viewer
python3 tests/run_tests.py ./hex_viewer
python3 samples/create_sample.py
./hex_viewer samples/signature_sample.bin
```

> يتطلب البناء مترجم GCC متوافقاً مع C17، ويتطلب تشغيل الاختبارات Python 3. لا يحتاج البرنامج إلى مكتبات خارجية.

## مثال على توقيع ملف PNG

يبدأ ملف PNG المعتاد بالتوقيع:

```text
89 50 4E 47 0D 0A 1A 0A
```

في عمود ASCII، ستظهر البايتات غير القابلة للطباعة كنقاط؛ وهذا سلوك متوقع ولا يعني أن البيانات قد تغيرت. اكتشاف التوقيع مؤشر أولي على نوع الملف وليس إثباتاً كاملاً لسلامة الملف أو موثوقيته.

## صور توثيق التنفيذ

الصور أدناه تم إنشاؤها من مخرجات تشغيل حقيقية للبرنامج ومجموعة الاختبارات في بيئة البناء المستخدمة لهذا التسليم. وهي لقطات توثيقية مرسومة من سجل الطرفية، وليست صوراً ملتقطة من شاشة جهاز Windows المحلي. سجلات التنفيذ النصية الأصلية موجودة في evidence/، ويمكن إعادة توليد صور SVG باستخدام python tools/render_evidence.py.

### فحص العينة الثنائية

![Sample output](screenshots/01-sample-output.svg)

### التعامل مع ملف غير موجود

![Missing file](screenshots/02-missing-file.svg)

### التحقق من الوسائط

![Argument validation](screenshots/03-argument-validation.svg)

### نتائج الاختبارات الآلية

![Automated tests](screenshots/04-automated-tests.svg)

## الاختبارات

تنفذ tests/run_tests.py خمسة اختبارات تكاملية:

1. ملف ثنائي يحتوي على توقيع PNG، ومحارف ASCII، وبايتات غير قابلة للطباعة، وصف أخير غير مكتمل.
2. ملف غير موجود.
3. تشغيل البرنامج دون تمرير اسم ملف.
4. ملف فارغ.
5. ملف حجمه 16 بايتاً تماماً.

النتيجة الفعلية المسجلة عند إعداد هذا التسليم: **5/5 اختبارات ناجحة**، مع تجميع ناجح باستخدام تحذيرات GCC الصارمة. يمكن إعادة تشغيل الاختبارات محلياً بالأوامر أعلاه، كما يوجد GitHub Actions للتحقق عند الدفع أو فتح Pull Request.

## ملاحظات أمنية وحدود الأداة

- الأداة قارئ وعارض فقط؛ لا تعدّل الملف ولا تكتب إليه.
- لا تنفذ البرنامج أو تفسر محتوى الملف.
- لا تستنتج أن الملف آمن بناءً على التوقيع وحده؛ يمكن تزوير الامتداد أو التوقيع.
- لا ترفع ملفات شخصية أو حساسة للاختبار. استخدم العينة الاصطناعية المرفقة.
- لا توجد معالجة متخصصة لصيغ الملفات الضخمة؛ تتم القراءة المتتابعة مع استخدام مخزن بيانات ثابت تقريباً (16 بايت).

## موقع التكليف

course-assignments/03-hexadecimal-viewer/
