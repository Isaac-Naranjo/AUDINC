<?php
declare(strict_types=1);

// Autocarga: Audinc\Servicio\EvaluadorServicio -> src/Servicio/EvaluadorServicio.php
spl_autoload_register(static function (string $clase): void {
    $prefijo = 'Audinc\\';
    if (strncmp($clase, $prefijo, strlen($prefijo)) !== 0) {
        return;
    }
    $ruta = __DIR__ . '/' . str_replace('\\', '/', substr($clase, strlen($prefijo))) . '.php';
    if (is_file($ruta)) {
        require $ruta;
    }
});

/**
 * Carga config/config.local.php. Falla si no existe para no arrancar con valores por defecto.
 */
function audinc_config(): array
{
    static $config = null;
    if ($config === null) {
        $ruta = dirname(__DIR__) . '/config/config.local.php';
        if (!is_file($ruta)) {
            throw new RuntimeException('Falta config/config.local.php (copiar desde config.example.php)');
        }
        $config = require $ruta;
    }
    return $config;
}
