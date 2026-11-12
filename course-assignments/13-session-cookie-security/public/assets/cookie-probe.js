'use strict';

(() => {
    const output = document.getElementById('cookie-probe-result');
    const analysis = document.getElementById('cookie-probe-analysis');
    if (!output || !analysis) return;
    const visibleCookies = document.cookie.split(';').map(part => part.trim()).filter(Boolean);
    const names = visibleCookies.map(part => part.split('=', 1)[0]);
    output.textContent = visibleCookies.length > 0 ? visibleCookies.join('\n') : '(لا توجد كوكيز قابلة للقراءة من JavaScript)';
    const safeVisible = names.includes('DEMO_SAFE') || names.includes('CYBERSESSID');
    const unsafeVisible = names.includes('DEMO_UNSAFE');
    analysis.textContent = unsafeVisible && !safeVisible
        ? 'النتيجة المتوقعة: يمكن قراءة DEMO_UNSAFE، بينما يمنع HttpOnly قراءة DEMO_SAFE وCYBERSESSID من JavaScript.'
        : 'تأكد من أن المتصفح قبل الكوكيز. استخدم HTTPS أو localhost عند اختبار Secure cookie.';
})();
