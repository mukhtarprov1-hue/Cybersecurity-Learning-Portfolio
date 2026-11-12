<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/src/SecureUploadService.php';

$passed = 0;
$failed = 0;
$testRoot = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'assignment12-' . bin2hex(random_bytes(8));
$publicDirectory = $testRoot . DIRECTORY_SEPARATOR . 'public';
$privateDirectory = $testRoot . DIRECTORY_SEPARATOR . 'private';
if (!mkdir($publicDirectory, 0700, true) && !is_dir($publicDirectory)) {
    fwrite(STDERR, "Unable to create temporary test directory." . PHP_EOL);
    exit(2);
}
$service = new SecureUploadService($privateDirectory, $publicDirectory, 1024);

function testCase(string $name, callable $callback): void
{
    global $passed, $failed;
    try {
        $callback();
        $passed++;
        echo "[PASS] {$name}" . PHP_EOL;
    } catch (Throwable $exception) {
        $failed++;
        echo "[FAIL] {$name}: {$exception->getMessage()}" . PHP_EOL;
    }
}

function assertTrue(bool $condition, string $message = 'Assertion failed'): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

function temporaryFixture(string $root, string $bytes): string
{
    $path = tempnam($root, 'fixture-');
    if ($path === false || file_put_contents($path, $bytes) !== strlen($bytes)) {
        throw new RuntimeException('Could not write fixture.');
    }
    return $path;
}

function expectRejected(callable $callback, string $expectedCode): void
{
    try {
        $callback();
    } catch (UploadRejectedException $exception) {
        assertTrue($exception->errorCode === $expectedCode,
            'Expected rejection ' . $expectedCode . ', received ' . $exception->errorCode);
        return;
    }
    throw new RuntimeException('Expected rejection ' . $expectedCode . ' but operation was accepted.');
}

$png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/pZsAAAAASUVORK5CYII=', true);
$jpeg = base64_decode('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAb/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAgEBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAgMBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAgIDBAEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAgMEBQEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAgMEBQEBPwF//9k=', true);
$pdf = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [] /Count 0 >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n";
if (!is_string($png) || !is_string($jpeg)) {
    fwrite(STDERR, "Test image fixture could not be decoded." . PHP_EOL);
    exit(2);
}

$files = [];
try {
    testCase('Valid PNG passes extension, MIME, signature, and dimensions checks', function () use ($service, $testRoot, $png, &$files): void {
        $path = temporaryFixture($testRoot, $png);
        $files[] = $path;
        $result = $service->inspectTemporaryFile($path, 'profile.png', strlen($png));
        assertTrue($result['extension'] === 'png');
        assertTrue($result['mime'] === 'image/png');
    });

    testCase('Valid JPEG passes extension, MIME, and image-structure checks', function () use ($service, $testRoot, $jpeg, &$files): void {
        $path = temporaryFixture($testRoot, $jpeg);
        $files[] = $path;
        $result = $service->inspectTemporaryFile($path, 'photo.jpg', strlen($jpeg));
        assertTrue($result['extension'] === 'jpg');
        assertTrue($result['mime'] === 'image/jpeg');
    });

    testCase('PDF with expected header, MIME, and EOF marker is accepted', function () use ($service, $testRoot, $pdf, &$files): void {
        $path = temporaryFixture($testRoot, $pdf);
        $files[] = $path;
        $result = $service->inspectTemporaryFile($path, 'document.pdf', strlen($pdf));
        assertTrue($result['extension'] === 'pdf');
        assertTrue($result['mime'] === 'application/pdf');
    });

    testCase('PHP web-shell renamed to JPG is rejected by MIME validation', function () use ($service, $testRoot, &$files): void {
        $bytes = "<?php echo 'training-shell'; ?>";
        $path = temporaryFixture($testRoot, $bytes);
        $files[] = $path;
        expectRejected(fn () => $service->inspectTemporaryFile($path, 'image.jpg', strlen($bytes)), 'MIME_MISMATCH');
    });

    testCase('Executable PHP extension is not allow-listed', function () use ($service, $testRoot, &$files): void {
        $bytes = "<?php echo 'x'; ?>";
        $path = temporaryFixture($testRoot, $bytes);
        $files[] = $path;
        expectRejected(fn () => $service->inspectTemporaryFile($path, 'shell.php', strlen($bytes)), 'EXTENSION_NOT_ALLOWED');
    });

    testCase('PNG bytes disguised with JPG extension are rejected', function () use ($service, $testRoot, $png, &$files): void {
        $path = temporaryFixture($testRoot, $png);
        $files[] = $path;
        expectRejected(fn () => $service->inspectTemporaryFile($path, 'photo.jpg', strlen($png)), 'MIME_MISMATCH');
    });

    testCase('Oversized file is rejected before MIME processing', function () use ($service, $testRoot, &$files): void {
        $bytes = str_repeat('A', 1025);
        $path = temporaryFixture($testRoot, $bytes);
        $files[] = $path;
        expectRejected(fn () => $service->inspectTemporaryFile($path, 'large.pdf', strlen($bytes)), 'FILE_TOO_LARGE');
    });

    testCase('Empty file is rejected', function () use ($service, $testRoot, &$files): void {
        $path = temporaryFixture($testRoot, '');
        $files[] = $path;
        expectRejected(fn () => $service->inspectTemporaryFile($path, 'empty.png', 0), 'EMPTY_FILE');
    });

    testCase('Client-reported size must match actual temporary file size', function () use ($service, $testRoot, $png, &$files): void {
        $path = temporaryFixture($testRoot, $png);
        $files[] = $path;
        expectRejected(fn () => $service->inspectTemporaryFile($path, 'photo.png', strlen($png) + 1), 'INVALID_FILE_SIZE');
    });

    testCase('Path traversal text is not used as the stored filename', function () use ($service, $testRoot, $png, &$files): void {
        $path = temporaryFixture($testRoot, $png);
        $files[] = $path;
        $service->inspectTemporaryFile($path, '../../avatar.png', strlen($png));
        $name = SecureUploadService::generateStoredName('png');
        assertTrue((bool) preg_match('/^[a-f0-9]{32}\.png$/', $name));
        assertTrue(!str_contains($name, '..') && !str_contains($name, '/') && !str_contains($name, '\\'));
    });

    testCase('Stored names use 128-bit random identifiers', function (): void {
        $first = SecureUploadService::generateStoredName('pdf');
        $second = SecureUploadService::generateStoredName('pdf');
        assertTrue((bool) preg_match('/^[a-f0-9]{32}\.pdf$/', $first));
        assertTrue($first !== $second);
    });

    testCase('Private storage is outside the public web root', function () use ($privateDirectory, $publicDirectory): void {
        $storage = realpath($privateDirectory);
        $public = realpath($publicDirectory);
        assertTrue(is_string($storage) && is_string($public));
        assertTrue(stripos($storage, $public . DIRECTORY_SEPARATOR) !== 0);
    });

    testCase('A local temporary path cannot bypass the HTTP upload-source check', function () use ($service, $testRoot, $png, &$files): void {
        $path = temporaryFixture($testRoot, $png);
        $files[] = $path;
        expectRejected(fn () => $service->storeUploadedFile([
            'name' => 'local.png',
            'tmp_name' => $path,
            'size' => strlen($png),
            'error' => UPLOAD_ERR_OK,
        ]), 'INVALID_UPLOAD_SOURCE');
    });

    testCase('PDF without EOF marker is rejected', function () use ($service, $testRoot, &$files): void {
        $bytes = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n";
        $path = temporaryFixture($testRoot, $bytes);
        $files[] = $path;
        expectRejected(fn () => $service->inspectTemporaryFile($path, 'broken.pdf', strlen($bytes)), 'INVALID_PDF');
    });

    echo PHP_EOL . sprintf("Tests: %d | Passed: %d | Failed: %d", $passed + $failed, $passed, $failed) . PHP_EOL;
} finally {
    foreach ($files as $file) {
        if (is_file($file)) {
            @unlink($file);
        }
    }
    foreach (glob($testRoot . DIRECTORY_SEPARATOR . '*') ?: [] as $entry) {
        if (is_file($entry)) {
            @unlink($entry);
        }
    }
    @rmdir($privateDirectory);
    @rmdir($publicDirectory);
    @rmdir($testRoot);
}

exit($failed === 0 ? 0 : 1);
