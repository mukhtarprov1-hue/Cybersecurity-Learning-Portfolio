<?php
declare(strict_types=1);

/** A validation failure safe to report to the browser using its public code. */
final class UploadRejectedException extends RuntimeException
{
    public function __construct(public readonly string $errorCode)
    {
        parent::__construct($errorCode);
    }
}

/**
 * A small defence-in-depth upload service for the Assignment 12 lab.
 * Uploaded bytes are never stored under the original client-supplied name.
 */
final class SecureUploadService
{
    public const MAX_UPLOAD_BYTES = 2_097_152; // 2 MiB
    public const MAX_IMAGE_PIXELS = 40_000_000;

    /** @var array<string, string> extension => expected MIME type */
    private const ALLOWED_TYPES = [
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
    ];

    private string $storageDirectory;

    public function __construct(
        string $storageDirectory,
        string $publicDirectory,
        private readonly int $maxBytes = self::MAX_UPLOAD_BYTES
    ) {
        if ($this->maxBytes < 1) {
            throw new InvalidArgumentException('The upload size limit must be positive.');
        }

        if (!is_dir($storageDirectory) && !@mkdir($storageDirectory, 0700, true) && !is_dir($storageDirectory)) {
            throw new RuntimeException('Unable to initialize private upload storage.');
        }

        $storageReal = realpath($storageDirectory);
        $publicReal = realpath($publicDirectory);
        if ($storageReal === false || $publicReal === false || !is_dir($storageReal)) {
            throw new RuntimeException('Unable to resolve the upload storage directory.');
        }

        $storageNormalized = rtrim(str_replace('\\', '/', $storageReal), '/') . '/';
        $publicNormalized = rtrim(str_replace('\\', '/', $publicReal), '/') . '/';
        if (strcasecmp($storageNormalized, $publicNormalized) === 0
            || strncasecmp($storageNormalized, $publicNormalized, strlen($publicNormalized)) === 0) {
            throw new RuntimeException('Upload storage must be outside the public web root.');
        }

        if (!is_writable($storageReal)) {
            throw new RuntimeException('The private upload storage is not writable.');
        }

        // POSIX permissions restrict access to the PHP service account.
        // Windows access control is governed by the directory's NTFS ACL.
        if (DIRECTORY_SEPARATOR !== '\\' && !@chmod($storageReal, 0700)) {
            throw new RuntimeException('Unable to restrict upload storage permissions.');
        }

        $this->storageDirectory = $storageReal;
    }

    /**
     * Handle the actual PHP upload structure from $_FILES.
     * The is_uploaded_file() check prevents arbitrary local-path injection.
     *
     * @param array<string, mixed> $file
     * @return array{original_name:string,stored_name:string,size:int,mime:string,extension:string}
     */
    public function storeUploadedFile(array $file): array
    {
        $error = $file['error'] ?? UPLOAD_ERR_NO_FILE;
        if (!is_int($error)) {
            throw new UploadRejectedException('INVALID_UPLOAD');
        }

        if ($error !== UPLOAD_ERR_OK) {
            $code = match ($error) {
                UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE => 'FILE_TOO_LARGE',
                UPLOAD_ERR_NO_FILE => 'NO_FILE',
                UPLOAD_ERR_PARTIAL => 'PARTIAL_UPLOAD',
                UPLOAD_ERR_NO_TMP_DIR, UPLOAD_ERR_CANT_WRITE, UPLOAD_ERR_EXTENSION => 'UPLOAD_FAILED',
                default => 'INVALID_UPLOAD',
            };
            throw new UploadRejectedException($code);
        }

        $temporaryPath = $file['tmp_name'] ?? null;
        $originalName = $file['name'] ?? null;
        $reportedSize = $file['size'] ?? null;

        if (!is_string($temporaryPath) || $temporaryPath === '' || !is_uploaded_file($temporaryPath)) {
            throw new UploadRejectedException('INVALID_UPLOAD_SOURCE');
        }
        if (!is_string($originalName) || !is_int($reportedSize)) {
            throw new UploadRejectedException('INVALID_UPLOAD');
        }

        $metadata = $this->inspectTemporaryFile($temporaryPath, $originalName, $reportedSize);
        $storedName = self::generateStoredName($metadata['extension']);
        $destination = $this->storageDirectory . DIRECTORY_SEPARATOR . $storedName;

        // The random identifier makes collisions extraordinarily unlikely. Still
        // check the destination before move_uploaded_file() to avoid overwrites.
        if (file_exists($destination)) {
            throw new RuntimeException('A generated storage identifier already exists.');
        }

        if (!move_uploaded_file($temporaryPath, $destination)) {
            throw new RuntimeException('Unable to move the validated upload into private storage.');
        }

        if (DIRECTORY_SEPARATOR !== '\\' && !@chmod($destination, 0600)) {
            @unlink($destination);
            throw new RuntimeException('Unable to restrict uploaded-file permissions.');
        }

        return [
            'original_name' => self::safeDisplayName($originalName),
            'stored_name' => $storedName,
            'size' => $metadata['size'],
            'mime' => $metadata['mime'],
            'extension' => $metadata['extension'],
        ];
    }

    /**
     * Inspect a temporary file's real bytes. This method is also exposed for
     * deterministic tests; production uploads must enter through storeUploadedFile().
     *
     * @return array{size:int,mime:string,extension:string}
     */
    public function inspectTemporaryFile(string $temporaryPath, string $originalName, int $reportedSize): array
    {
        if (!is_file($temporaryPath) || !is_readable($temporaryPath)) {
            throw new UploadRejectedException('INVALID_TEMP_FILE');
        }

        $actualSize = filesize($temporaryPath);
        if ($actualSize === false || $actualSize < 1) {
            throw new UploadRejectedException('EMPTY_FILE');
        }
        if ($reportedSize < 0 || $reportedSize !== $actualSize) {
            throw new UploadRejectedException('INVALID_FILE_SIZE');
        }
        if ($actualSize > $this->maxBytes) {
            throw new UploadRejectedException('FILE_TOO_LARGE');
        }

        // Use only the extension as a policy selector; never use the client name
        // as a destination path or trust the browser's Content-Type header.
        $extension = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
        if (!isset(self::ALLOWED_TYPES[$extension])) {
            throw new UploadRejectedException('EXTENSION_NOT_ALLOWED');
        }

        if (!class_exists(finfo::class)) {
            throw new RuntimeException('PHP Fileinfo extension is required.');
        }
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $detectedMime = $finfo->file($temporaryPath);
        if (!is_string($detectedMime) || $detectedMime !== self::ALLOWED_TYPES[$extension]) {
            throw new UploadRejectedException('MIME_MISMATCH');
        }

        $this->validateFileSignature($temporaryPath, $extension, $actualSize);

        return [
            'size' => $actualSize,
            'mime' => $detectedMime,
            'extension' => $extension,
        ];
    }

    /** @return non-empty-string */
    public static function generateStoredName(string $extension): string
    {
        if (!isset(self::ALLOWED_TYPES[$extension])) {
            throw new InvalidArgumentException('Cannot generate a stored name for a disallowed extension.');
        }
        return bin2hex(random_bytes(16)) . '.' . $extension;
    }

    private function validateFileSignature(string $path, string $extension, int $size): void
    {
        if ($extension === 'png' || $extension === 'jpg' || $extension === 'jpeg') {
            $image = @getimagesize($path);
            if (!is_array($image)) {
                throw new UploadRejectedException('INVALID_IMAGE');
            }

            $expectedType = $extension === 'png' ? IMAGETYPE_PNG : IMAGETYPE_JPEG;
            if (($image[2] ?? null) !== $expectedType) {
                throw new UploadRejectedException('SIGNATURE_MISMATCH');
            }

            $width = (int) ($image[0] ?? 0);
            $height = (int) ($image[1] ?? 0);
            if ($width < 1 || $height < 1 || ($width * $height) > self::MAX_IMAGE_PIXELS) {
                throw new UploadRejectedException('IMAGE_DIMENSIONS_NOT_ALLOWED');
            }
            return;
        }

        if ($extension === 'pdf') {
            $handle = @fopen($path, 'rb');
            if ($handle === false) {
                throw new UploadRejectedException('INVALID_PDF');
            }
            try {
                $header = fread($handle, 8);
                $tailLength = min(1024, $size);
                if (fseek($handle, -$tailLength, SEEK_END) !== 0) {
                    throw new UploadRejectedException('INVALID_PDF');
                }
                $tail = fread($handle, $tailLength);
            } finally {
                fclose($handle);
            }
            if (!is_string($header) || !str_starts_with($header, '%PDF-')
                || !is_string($tail) || !str_contains($tail, '%%EOF')) {
                throw new UploadRejectedException('INVALID_PDF');
            }
            return;
        }

        throw new UploadRejectedException('EXTENSION_NOT_ALLOWED');
    }

    private static function safeDisplayName(string $name): string
    {
        $name = str_replace("\\", '/', $name);
        $base = basename($name);
        $base = preg_replace('/[\x00-\x1F\x7F]/u', '', $base) ?? 'uploaded-file';
        return function_exists('mb_substr') ? mb_substr($base, 0, 120, 'UTF-8') : substr($base, 0, 120);
    }
}
