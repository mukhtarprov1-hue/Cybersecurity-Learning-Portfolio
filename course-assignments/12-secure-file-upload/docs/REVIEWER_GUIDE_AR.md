# دليل المدرب — مراجعة التكليف 12 خلال خمس دقائق

1. افتح public/index.php وتأكد من أن اسم الحقل file_uploaded وأن النموذج يستخدم multipart/form-data.
2. افتح src/SecureUploadService.php وراجع الترتيب: upload error → is_uploaded_file() → size → pathinfo() allow-list → Fileinfo MIME → signature/structure → random name → move_uploaded_file().
3. تحقق من أن مسار storage/private/ خارج مجلد public/ ولا يوجد endpoint لتنزيل المحتوى.
4. شغّل php tests/run.php وتحقق من 14 اختباراً، خاصة PHP renamed .jpg، PNG renamed .jpg، الحجم الكبير، وPath Traversal.
5. شغّل الموقع محلياً وارفع PNG/JPEG/PDF اختبارياً، ثم أعد تسمية ملف نص PHP إلى .jpg وتحقق من الرفض.
6. راجع docs/REPORT_AR.md وdocs/SECURITY_NOTES_AR.md لمعرفة حدود Fileinfo والفحص البنيوي.

## قرارات تنفيذية معلنة

- حد 2 MiB وقائمة PDF/PNG/JPG/JPEG اختيارات تنفيذية لأن نص التكليف لم يحدد رقماً نهائياً أو قائمة نهائية.
- صور التنفيذ المحلية ونتيجة CI لا توصف بأنها مكتملة حتى يُرفق الطالب الأدلة الفعلية ويتحقق من حالة workflow.
- هذا مشروع تعليمي وليس خدمة رفع ملفات جاهزة للإنتاج.
