<?php


echo json_encode([
    'version' => PHP_VERSION,
    'drivers' => PDO::getAvailableDrivers(),
    'pdo_sqlite' => extension_loaded('pdo_sqlite'),
    'sqlite3' => extension_loaded('sqlite3'),
], JSON_PRETTY_PRINT), PHP_EOL;