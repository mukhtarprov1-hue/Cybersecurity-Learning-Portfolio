<?php
declare(strict_types=1);

final class ItemRepository
{
    public function __construct(private readonly string $storageDirectory)
    {
        if (!is_dir($this->storageDirectory)
            && !mkdir($this->storageDirectory, 0700, true)
            && !is_dir($this->storageDirectory)) {
            throw new RuntimeException('Could not create the storage directory.');
        }
    }

    /** @return list<array<string, mixed>> */
    public function all(?string $query = null, int $limit = 100): array
    {
        return $this->withLock(LOCK_SH, function () use ($query, $limit): array {
            $items = $this->readUnlocked();
            if ($query !== null && $query !== '') {
                $needle = self::lowerText($query);
                $items = array_values(array_filter(
                    $items,
                    static function (array $item) use ($needle): bool {
                        $haystack = self::lowerText(
                            (string) $item['title'] . ' ' . (string) $item['description']
                        );
                        return str_contains($haystack, $needle);
                    }
                ));
            }
            return array_slice($items, 0, $limit);
        });
    }

    public function find(string $id): ?array
    {
        return $this->withLock(LOCK_SH, function () use ($id): ?array {
            foreach ($this->readUnlocked() as $item) {
                if (($item['id'] ?? null) === $id) {
                    return $item;
                }
            }
            return null;
        });
    }

    public function create(array $attributes): array
    {
        return $this->withLock(LOCK_EX, function () use ($attributes): array {
            $items = $this->readUnlocked();
            $now = gmdate('Y-m-d\TH:i:s\Z');
            $item = [
                'id' => self::uuidV4(),
                'title' => $attributes['title'],
                'description' => $attributes['description'],
                'priority' => $attributes['priority'],
                'created_at' => $now,
                'updated_at' => $now,
            ];
            $items[] = $item;
            $this->writeUnlocked($items);
            return $item;
        });
    }

    public function replace(string $id, array $attributes): ?array
    {
        return $this->withLock(LOCK_EX, function () use ($id, $attributes): ?array {
            $items = $this->readUnlocked();
            foreach ($items as $index => $item) {
                if (($item['id'] ?? null) !== $id) {
                    continue;
                }
                $items[$index]['title'] = $attributes['title'];
                $items[$index]['description'] = $attributes['description'];
                $items[$index]['priority'] = $attributes['priority'];
                $items[$index]['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
                $this->writeUnlocked($items);
                return $items[$index];
            }
            return null;
        });
    }

    public function delete(string $id): bool
    {
        return $this->withLock(LOCK_EX, function () use ($id): bool {
            $items = $this->readUnlocked();
            $filtered = array_values(array_filter(
                $items,
                static fn (array $item): bool => ($item['id'] ?? null) !== $id
            ));
            if (count($filtered) === count($items)) {
                return false;
            }
            $this->writeUnlocked($filtered);
            return true;
        });
    }

    /** @template T @param callable():T $callback @return T */
    private function withLock(int $lockMode, callable $callback): mixed
    {
        $lockPath = rtrim($this->storageDirectory, DIRECTORY_SEPARATOR)
            . DIRECTORY_SEPARATOR . 'items.lock';
        $lock = fopen($lockPath, 'c');
        if ($lock === false) {
            throw new RuntimeException('Could not open the data-store lock.');
        }

        try {
            if (!flock($lock, $lockMode)) {
                throw new RuntimeException('Could not acquire the data-store lock.');
            }
            return $callback();
        } finally {
            flock($lock, LOCK_UN);
            fclose($lock);
        }
    }

    /** @return list<array<string, mixed>> */
    private function readUnlocked(): array
    {
        $path = $this->dataPath();
        if (!is_file($path)) {
            return [];
        }
        $contents = file_get_contents($path);
        if ($contents === false) {
            throw new RuntimeException('Could not read the data store.');
        }
        try {
            $decoded = json_decode($contents, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException $exception) {
            throw new RuntimeException('The data store contains invalid JSON.', 0, $exception);
        }
        if (!is_array($decoded) || !array_is_list($decoded)) {
            throw new RuntimeException('The data store has an invalid structure.');
        }
        return $decoded;
    }

    /** @param list<array<string, mixed>> $items */
    private function writeUnlocked(array $items): void
    {
        $path = $this->dataPath();
        $json = json_encode(
            $items,
            JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
        ) . PHP_EOL;
        $temporaryPath = tempnam($this->storageDirectory, '.items-');
        if ($temporaryPath === false) {
            throw new RuntimeException('Could not create a temporary data file.');
        }

        try {
            $written = file_put_contents($temporaryPath, $json, LOCK_EX);
            if ($written === false || $written !== strlen($json)) {
                throw new RuntimeException('Could not write the complete data file.');
            }
            @chmod($temporaryPath, 0600);
            if (!@rename($temporaryPath, $path)) {
                // Windows may not replace an existing destination with rename().
                if (DIRECTORY_SEPARATOR === '\\' && is_file($path)) {
                    $backupPath = $path . '.bak';
                    @unlink($backupPath);
                    if (!rename($path, $backupPath)) {
                        throw new RuntimeException('Could not preserve the previous data file.');
                    }
                    if (!rename($temporaryPath, $path)) {
                        @rename($backupPath, $path);
                        throw new RuntimeException('Could not replace the data file.');
                    }
                    @unlink($backupPath);
                } else {
                    throw new RuntimeException('Could not atomically replace the data file.');
                }
            }
        } finally {
            if (is_file($temporaryPath)) {
                @unlink($temporaryPath);
            }
        }
    }

    private static function lowerText(string $value): string
    {
        // Use full UTF-8 case folding when mbstring is installed; otherwise
        // PHP's built-in strtolower still provides ASCII case-insensitive search.
        return function_exists('mb_strtolower') ? mb_strtolower($value, 'UTF-8') : strtolower($value);
    }

    private function dataPath(): string
    {
        return rtrim($this->storageDirectory, DIRECTORY_SEPARATOR)
            . DIRECTORY_SEPARATOR . 'items.json';
    }

    private static function uuidV4(): string
    {
        $bytes = random_bytes(16);
        $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
        $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
        $hex = bin2hex($bytes);
        return sprintf(
            '%s-%s-%s-%s-%s',
            substr($hex, 0, 8),
            substr($hex, 8, 4),
            substr($hex, 12, 4),
            substr($hex, 16, 4),
            substr($hex, 20)
        );
    }
}
