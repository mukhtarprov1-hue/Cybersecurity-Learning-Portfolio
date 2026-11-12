'use strict';

(() => {
  const input = document.getElementById('payload-input');
  const safeResult = document.getElementById('safe-result');
  const safeStatus = document.getElementById('safe-status');
  const unsafeStatus = document.getElementById('unsafe-status');
  const overallStatus = document.getElementById('overall-status');
  const unsafeFrame = document.getElementById('unsafe-frame');
  const samplePayload = '<img src="data:image/png;base64,AA==" onerror="parent.postMessage(\'DOM_XSS_PROOF\', \'*\')">';
  let unsafeProof = false;

  if (!input || !safeResult || !unsafeFrame) {
    throw new Error('DOM-XSS lab initialization failed: required elements are missing.');
  }

  const setStatus = (element, message, kind) => {
    element.textContent = message;
    element.className = 'status status-' + kind;
  };

  const encodeBase64Utf8 = (value) => {
    const bytes = new TextEncoder().encode(value);
    let binary = '';
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return window.btoa(binary);
  };

  const renderSafe = () => {
    const untrustedInput = input.value;
    const output = document.createElement('pre');
    output.className = 'literal-output';
    output.textContent = untrustedInput;
    safeResult.replaceChildren();
    safeResult.appendChild(output);
    const createdElements = output.querySelectorAll('*').length;
    setStatus(
      safeStatus,
      'SAFE: input rendered as text. Descendant HTML elements created: ' + createdElements + '.',
      'success'
    );
    overallStatus.textContent = 'اكتمل العرض الآمن: لم يتم تفسير المدخل كـ HTML.';
  };

  const renderUnsafeInSandbox = () => {
    const untrustedInput = input.value;
    unsafeProof = false;
    setStatus(unsafeStatus, 'جارٍ تشغيل innerHTML داخل iframe معزول...', 'pending');
    overallStatus.textContent = 'يتم اختبار مسار innerHTML المعزول...';

    // Encode the input before embedding it in the iframe bootstrap script. This
    // avoids allowing the input to break out of a JavaScript or script context.
    const encoded = encodeBase64Utf8(untrustedInput);
    const srcdoc = [
      '<!doctype html>',
      '<html lang="en"><head><meta charset="utf-8">',
      '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; img-src data:; script-src \'unsafe-inline\'; connect-src \'none\'; form-action \'none\'; frame-src \'none\'; object-src \'none\'; base-uri \'none\'">',
      '<title>Isolated unsafe sink</title></head><body><div id="sink"></div>',
      '<script>',
      '(() => {',
      '  const encoded = \'' + encoded + '\';',
      '  const binary = atob(encoded);',
      '  const bytes = Uint8Array.from(binary, character => character.charCodeAt(0));',
      '  const untrustedInput = new TextDecoder().decode(bytes);',
      '  // INTENTIONALLY VULNERABLE SINK — constrained to a unique-origin sandbox.',
      '  document.getElementById("sink").innerHTML = untrustedInput;',
      '})();',
      '<\/script></body></html>'
    ].join('\n');

    unsafeFrame.srcdoc = srcdoc;
    window.__domXssProof = false;
    window.__domXssRun = true;
  };

  window.addEventListener('message', (event) => {
    if (event.source !== unsafeFrame.contentWindow || event.origin !== 'null') return;
    if (event.data !== 'DOM_XSS_PROOF') return;
    unsafeProof = true;
    window.__domXssProof = true;
    setStatus(
      unsafeStatus,
      'DOM-XSS PROOF: the injected event handler executed inside the isolated sandbox. The parent page remained isolated.',
      'danger'
    );
    overallStatus.textContent = 'تم إثبات تنفيذ الحدث في المسار غير الآمن المعزول؛ المسار الآمن يعرض الحمولة كنص.';
  });

  document.getElementById('run-safe').addEventListener('click', renderSafe);
  document.getElementById('run-unsafe').addEventListener('click', renderUnsafeInSandbox);
  document.getElementById('load-sample').addEventListener('click', () => {
    input.value = samplePayload;
    overallStatus.textContent = 'تم تحميل الحمولة التعليمية الجاهزة.';
  });
  document.getElementById('clear-results').addEventListener('click', () => {
    safeResult.replaceChildren();
    unsafeFrame.srcdoc = '<!doctype html><html><body></body></html>';
    setStatus(safeStatus, 'تم مسح النتيجة الآمنة.', 'neutral');
    setStatus(unsafeStatus, 'تم مسح النتيجة غير الآمنة.', 'neutral');
    overallStatus.textContent = 'تم مسح النتائج وإعادة المختبر إلى الحالة الابتدائية.';
    unsafeProof = false;
    window.__domXssProof = false;
    window.__domXssRun = false;
  });

  input.value = samplePayload;
  window.__domXssLab = Object.freeze({
    get unsafeProof() { return unsafeProof; },
    samplePayload
  });
})();
