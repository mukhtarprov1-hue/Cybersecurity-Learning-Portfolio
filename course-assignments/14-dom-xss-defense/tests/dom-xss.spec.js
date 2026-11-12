'use strict';

const { test, expect } = require('@playwright/test');

const SAMPLE = '<img src="data:image/png;base64,AA==" onerror="parent.postMessage(\'DOM_XSS_PROOF\', \'*\')">';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
});

test('lab loads with required input and both rendering controls', async ({ page }) => {
  await expect(page).toHaveTitle(/DOM-XSS Defense Lab/);
  await expect(page.locator('#payload-input')).toHaveValue(SAMPLE);
  await expect(page.getByRole('button', { name: /تشغيل العرض غير الآمن/ })).toBeVisible();
  await expect(page.getByRole('button', { name: /تشغيل العرض الآمن/ })).toBeVisible();
});

test('safe rendering treats the payload as literal text and creates no HTML element', async ({ page }) => {
  await page.getByRole('button', { name: /تشغيل العرض الآمن/ }).click();
  const output = page.locator('#safe-result pre');
  await expect(output).toHaveText(SAMPLE);
  await expect(page.locator('#safe-result img')).toHaveCount(0);
  await expect(page.locator('#safe-status')).toContainText('SAFE');
});

test('unsafe innerHTML sink executes only inside a sandboxed unique-origin iframe', async ({ page }) => {
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error.message));

  await page.getByRole('button', { name: /تشغيل العرض غير الآمن/ }).click();
  await page.waitForFunction(() => window.__domXssProof === true, null, { timeout: 8000 });

  await expect(page.locator('#unsafe-status')).toContainText('DOM-XSS PROOF');
  await expect(page.locator('#unsafe-frame')).toHaveAttribute('sandbox', 'allow-scripts');
  await expect(page.locator('#safe-result img')).toHaveCount(0);
  const mainDocumentImages = await page.locator('body > img').count();
  expect(mainDocumentImages).toBe(0);
  expect(pageErrors).toEqual([]);
});

test('safe and unsafe paths remain independent when executed in sequence', async ({ page }) => {
  await page.getByRole('button', { name: /تشغيل العرض الآمن/ }).click();
  await expect(page.locator('#safe-result pre')).toHaveText(SAMPLE);

  await page.getByRole('button', { name: /تشغيل العرض غير الآمن/ }).click();
  await page.waitForFunction(() => window.__domXssProof === true, null, { timeout: 8000 });

  await expect(page.locator('#safe-result pre')).toHaveText(SAMPLE);
  await expect(page.locator('#safe-result img')).toHaveCount(0);
  await expect(page.locator('#unsafe-status')).toContainText('DOM-XSS PROOF');
});

test('clear button resets the output and proof state', async ({ page }) => {
  await page.getByRole('button', { name: /تشغيل العرض غير الآمن/ }).click();
  await page.waitForFunction(() => window.__domXssProof === true, null, { timeout: 8000 });
  await page.getByRole('button', { name: /مسح النتائج/ }).click();
  await expect(page.locator('#unsafe-status')).toContainText('تم مسح');
  await expect(page.locator('#safe-status')).toContainText('تم مسح');
  expect(await page.evaluate(() => window.__domXssProof)).toBe(false);
});

test('ordinary user text is rendered literally by the safe sink', async ({ page }) => {
  const text = '<b>not markup</b> & "quoted"';
  await page.locator('#payload-input').fill(text);
  await page.getByRole('button', { name: /تشغيل العرض الآمن/ }).click();
  await expect(page.locator('#safe-result pre')).toHaveText(text);
  await expect(page.locator('#safe-result b')).toHaveCount(0);
});