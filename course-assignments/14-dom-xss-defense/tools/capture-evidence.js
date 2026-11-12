'use strict';

const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const { spawn } = require('node:child_process');
const { chromium } = require('@playwright/test');

const root = process.cwd();
const evidence = path.join(root, 'evidence', 'local-verification');
const shots = path.join(root, 'screenshots', 'local-verification');
const reportPath = path.join(root, 'docs', 'LOCAL_VERIFICATION_REPORT.md');
const logPath = path.join(evidence, 'playwright-test-output.txt');
const url = 'http://127.0.0.1:4173';
const payload = '<img src="data:image/png;base64,AA==" onerror="parent.postMessage(\'DOM_XSS_PROOF\', \'*\')">';
const names = [
  '01-dom-xss-lab-interface.png',
  '02-safe-textcontent-result.png',
  '03-isolated-innerhtml-proof.png',
  '04-safe-unsafe-comparison.png',
  '05-reset-state.png'
];

function mkdir(p) { fs.mkdirSync(p, { recursive: true }); }
function hash(p) { return crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'); }

function waitForServer(child) {
  const started = Date.now();
  return new Promise((resolve, reject) => {
    const check = () => {
      if (child.exitCode !== null) return reject(new Error('Local server exited before startup.'));
      const request = http.get(url, response => {
        response.resume();
        if (response.statusCode === 200) return resolve();
        retry();
      });
      request.on('error', retry);
      function retry() {
        if (Date.now() - started > 12000) return reject(new Error('Local server startup timed out.'));
        setTimeout(check, 250);
      }
    };
    check();
  });
}

async function main() {
  mkdir(evidence);
  mkdir(shots);
  const server = spawn(process.execPath, ['tests/server.js'], {
    cwd: root, windowsHide: true, stdio: 'ignore'
  });
  let browser;
  try {
    await waitForServer(server);
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: { width: 1440, height: 1100 }, deviceScaleFactor: 1 });
    const pageErrors = [];
    page.on('pageerror', error => pageErrors.push(error.message));
    await page.goto(url, { waitUntil: 'networkidle' });

    if (await page.locator('#payload-input').inputValue() !== payload) {
      throw new Error('Unexpected default proof payload.');
    }
    const sandbox = await page.locator('#unsafe-frame').getAttribute('sandbox');
    if (sandbox !== 'allow-scripts' || sandbox.includes('allow-same-origin')) {
      throw new Error('Unexpected iframe sandbox configuration.');
    }
    const shot = async index => page.screenshot({
      path: path.join(shots, names[index]), fullPage: true, animations: 'disabled'
    });

    await shot(0);

    await page.locator('#run-safe').click();
    const safe = await page.evaluate(() => ({
      text: document.querySelector('#safe-result pre')?.textContent ?? null,
      images: document.querySelectorAll('#safe-result img').length,
      descendants: document.querySelector('#safe-result pre')?.querySelectorAll('*').length ?? -1
    }));
    if (safe.text !== payload || safe.images !== 0 || safe.descendants !== 0) {
      throw new Error('Safe text rendering check failed.');
    }
    await shot(1);

    await page.locator('#run-unsafe').click();
    await page.waitForFunction(() => window.__domXssProof === true, null, { timeout: 8000 });
    if (!(await page.locator('#unsafe-status').innerText()).includes('DOM-XSS PROOF')) {
      throw new Error('Sandbox proof message was not received.');
    }
    if (await page.locator('body > img').count() !== 0) {
      throw new Error('An injected image appeared in the main document.');
    }
    await shot(2);

    await page.locator('#run-safe').click();
    await page.locator('#run-unsafe').click();
    await page.waitForFunction(() => window.__domXssProof === true, null, { timeout: 8000 });
    const comparison = await page.evaluate(() => ({
      text: document.querySelector('#safe-result pre')?.textContent ?? null,
      imageCount: document.querySelectorAll('#safe-result img').length,
      proof: window.__domXssProof === true
    }));
    if (comparison.text !== payload || comparison.imageCount !== 0 || !comparison.proof) {
      throw new Error('Safe/unsafe independence check failed.');
    }
    await shot(3);

    await page.locator('#clear-results').click();
    const reset = await page.evaluate(() => ({
      children: document.querySelector('#safe-result').children.length,
      proof: window.__domXssProof,
      safe: document.querySelector('#safe-status').textContent,
      unsafe: document.querySelector('#unsafe-status').textContent
    }));
    if (reset.children !== 0 || reset.proof !== false ||
        !reset.safe.includes('تم مسح') || !reset.unsafe.includes('تم مسح')) {
      throw new Error('Reset check failed.');
    }
    await shot(4);

    if (pageErrors.length) throw new Error('Uncaught page errors: ' + pageErrors.join(' | '));
    const testOutput = fs.existsSync(logPath) ? fs.readFileSync(logPath, 'utf8') : '';
    if (!testOutput.includes('6 passed')) throw new Error('Test log does not confirm six passed tests.');

    const playwrightVersion = require('@playwright/test/package.json').version;
    const summary = {
      assignment: 14,
      local_status: 'PASS',
      captured_at_utc: new Date().toISOString(),
      runtime: {
        node: process.version,
        npm: process.env.LOCAL_NPM_VERSION || 'not-recorded',
        playwright: playwrightVersion,
        browser: 'Playwright Chromium (headless)'
      },
      tests: { passed: 6, failed: 0 },
      checks: {
        safe_text_rendering: 'PASS',
        safe_output_has_no_img_element: 'PASS',
        isolated_innerhtml_event_proof: 'PASS',
        iframe_sandbox: sandbox,
        allow_same_origin_absent: true,
        main_document_injected_images: 0,
        reset: 'PASS',
        browser_page_errors: 0
      },
      screenshots: names
    };
    const summaryPath = path.join(evidence, 'verification-summary.json');
    fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2) + '\n', 'utf8');

    const report = [
      '# تقرير التحقق المحلي — التكليف الرابع عشر',
      '',
      '## معلومات التنفيذ',
      '',
      '- النتيجة: PASS',
      '- Node.js: ' + process.version,
      '- npm: ' + (process.env.LOCAL_NPM_VERSION || 'غير مسجل'),
      '- Playwright: ' + playwrightVersion,
      '- المتصفح: Chromium عبر Playwright (Headless)',
      '- اختبارات المتصفح: 6/6 ناجحة، 0 إخفاقات',
      '- لقطات الشاشة: 5/5',
      '',
      '## فحوصات وقت التشغيل',
      '',
      '| الفحص | النتيجة |',
      '|---|---|',
      '| عرض المدخل حرفياً باستخدام textContent | PASS |',
      '| عدم إنشاء IMG في الناتج الآمن | PASS |',
      '| تنفيذ إثبات DOM-XSS داخل الإطار المعزول | PASS |',
      '| iframe sandbox يساوي allow-scripts دون allow-same-origin | PASS |',
      '| عدم حقن عناصر IMG في الصفحة الرئيسية | PASS |',
      '| مسح النتائج وإعادة حالة الإثبات | PASS |',
      '| أخطاء JavaScript غير المعالجة | 0 |',
      '',
      '## لقطات الأدلة',
      '',
      ...names.map((name, index) => (index + 1) + '. screenshots/local-verification/' + name),
      '',
      '## ملفات التحقق',
      '',
      '- evidence/local-verification/verification-summary.json',
      '- evidence/local-verification/playwright-test-output.txt',
      '- evidence/local-verification/SHA256SUMS.txt',
      '',
      '## ملاحظة أمنية',
      '',
      'اقتصر إثبات DOM-XSS على إرسال علامة ثابتة من داخل iframe sandbox ذي أصل معتم. لم تتضمن الحمولة قراءة cookies أو localStorage أو الاتصال بوجهة خارجية. ويعرض المسار الآمن المدخل كنص حرفي دون إنشاء عنصر IMG.',
      '',
      'هذه أدلة تحقق محلية للمختبر التعليمي، ولا تمثل فحصاً أمنياً شاملاً لتطبيقات الويب.',
      ''
    ].join('\n');
    fs.writeFileSync(reportPath, report, 'utf8');

    const readmePath = path.join(root, 'README.md');
    let readme = fs.readFileSync(readmePath, 'utf8');
    readme = readme.replace(
      '**Learner workstation evidence:** deferred until the GitHub-first submission phase is complete.',
      '**Learner workstation evidence:** PASS — local Playwright tests 6/6, runtime checks PASS, and five Chromium screenshots committed under screenshots/local-verification/.'
    );
    readme = readme.replace(
      '## Local browser run (deferred)\n\nFrom this directory:\n\n    node tests/server.js\n\nOpen http://127.0.0.1:4173. Do not expose this training server to a network.',
      '## Local workstation verification\n\nRun powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\tools\\verify-and-capture.ps1 from this project directory. The script installs the pinned Playwright dependency and Chromium, runs all six browser tests, captures five local screenshots, generates the Arabic verification report and SHA-256 manifest, then commits and pushes only Assignment 14 evidence. Use the NoPush switch to create the evidence commit locally without pushing.\n\nThe standalone preview remains available with node tests/server.js at http://127.0.0.1:4173. Do not expose this training server to a network.'
    );
    fs.writeFileSync(readmePath, readme, 'utf8');

    const hashFiles = [
      logPath, summaryPath, reportPath,
      ...names.map(name => path.join(shots, name))
    ];
    const manifest = hashFiles.map(file => {
      const relative = path.relative(root, file).split(path.sep).join('/');
      return hash(file) + '  ' + relative;
    }).join('\n') + '\n';
    fs.writeFileSync(path.join(evidence, 'SHA256SUMS.txt'), manifest, 'utf8');

    console.log('Chromium runtime checks: PASS');
    console.log('Sandbox attribute: ' + sandbox);
    console.log('Safe text rendering: PASS');
    console.log('Isolated DOM-XSS proof: PASS');
    console.log('Reset behavior: PASS');
    console.log('Browser page errors: 0');
    console.log('Screenshots: 5/5');
    console.log('Arabic report, JSON summary, and SHA-256 manifest: generated');
  } finally {
    if (browser) await browser.close().catch(() => {});
    if (server && server.exitCode === null) {
      server.kill();
      await new Promise(resolve => {
        const timer = setTimeout(resolve, 2000);
        server.once('exit', () => { clearTimeout(timer); resolve(); });
      });
    }
  }
}

main().catch(error => {
  console.error('Local evidence capture failed:', error && error.stack ? error.stack : error);
  process.exitCode = 1;
});
