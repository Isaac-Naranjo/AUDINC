<?php
declare(strict_types=1);

/**
 * AUDINC · punto de entrada.
 * Desarrollo:  php -S localhost:8000 -t public public/index.php
 * Solo la carpeta public/ queda expuesta; src/ y config/ no son accesibles por URL.
 */

// Con el servidor integrado, los archivos estáticos existentes se sirven tal cual
if (PHP_SAPI === 'cli-server') {
    $archivo = __DIR__ . parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    if ($archivo !== __DIR__ . '/' && is_file($archivo)) {
        return false;
    }
}

require dirname(__DIR__) . '/src/bootstrap.php';

use Audinc\BaseDatosException;
use Audinc\Database;
use Audinc\Repositorio\CatalogoRepositorio;
use Audinc\Repositorio\EvaluacionRepositorio;
use Audinc\Servicio\EvaluadorServicio;

ini_set('display_errors', '0');

header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store');

function responder(int $codigo, mixed $datos): never
{
    http_response_code($codigo);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($datos, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
    exit;
}

$metodo = $_SERVER['REQUEST_METHOD'];
$ruta   = rtrim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH), '/') ?: '/';

if ($ruta === '/') {
    responder(200, [
        'aplicacion' => 'AUDINC - Evaluador de confidencialidad ISO/IEC 27001:2022',
        'endpoints'  => [
            'GET  /api/riesgos',
            'GET  /api/tareas',
            'GET  /api/controles',
            'GET  /api/controles-observables',
            'GET  /api/pruebas',
            'GET  /api/matriz',
            'GET  /api/excepciones',
            'GET  /api/evaluaciones',
            'GET  /api/evaluaciones/{id}',
            'POST /api/evaluaciones   {"observaciones": "..."}',
        ],
    ]);
}

try {
    $config       = audinc_config();
    $db           = new Database($config['db']);
    $catalogo     = new CatalogoRepositorio($db);
    $evaluaciones = new EvaluacionRepositorio($db);

    $rutasGet = [
        '/api/riesgos'               => fn() => $catalogo->riesgos(),
        '/api/tareas'                => fn() => $catalogo->tareas(),
        '/api/controles'             => fn() => $catalogo->controlesIso(),
        '/api/controles-observables' => fn() => $catalogo->controlesObservables(),
        '/api/pruebas'               => fn() => $catalogo->pruebas(),
        '/api/matriz'                => fn() => $catalogo->matriz(),
        '/api/excepciones'           => fn() => $catalogo->excepciones(),
        '/api/evaluaciones'          => fn() => $evaluaciones->listar(),
    ];

    if ($metodo === 'GET' && isset($rutasGet[$ruta])) {
        responder(200, $rutasGet[$ruta]());
    }

    if ($metodo === 'GET' && preg_match('#^/api/evaluaciones/(\d{1,9})$#', $ruta, $m)) {
        $evaluacion = $evaluaciones->obtener((int) $m[1]);
        responder($evaluacion ? 200 : 404, $evaluacion ?? ['error' => 'Evaluación no encontrada']);
    }

    if ($metodo === 'POST' && $ruta === '/api/evaluaciones') {
        // Exigir JSON obliga al navegador a hacer preflight CORS: otra página
        // no puede disparar evaluaciones contra localhost (sin CORS habilitado).
        if (!str_starts_with($_SERVER['CONTENT_TYPE'] ?? '', 'application/json')) {
            responder(415, ['error' => 'Se requiere Content-Type: application/json']);
        }
        $cuerpo = json_decode(file_get_contents('php://input') ?: '{}', true);
        if (!is_array($cuerpo)) {
            responder(400, ['error' => 'El cuerpo debe ser JSON válido en UTF-8']);
        }
        $observaciones = isset($cuerpo['observaciones']) ? trim((string) $cuerpo['observaciones']) : null;
        if ($observaciones !== null && mb_strlen($observaciones) > 400) {
            responder(422, ['error' => 'Observaciones: máximo 400 caracteres']);
        }
        $servicio = new EvaluadorServicio($db, $catalogo, $evaluaciones, (int) ($config['max_filas_evidencia'] ?? 200));
        responder(201, $servicio->evaluar($observaciones ?: null));
    }

    responder(404, ['error' => 'Ruta no encontrada']);
} catch (BaseDatosException $e) {
    error_log('AUDINC: ' . $e->detalle());
    responder(503, ['error' => $e->getMessage(), 'codigo' => $e->codigoOra()]);
} catch (Throwable $e) {
    error_log('AUDINC: ' . $e);
    responder(500, ['error' => 'Error interno']);
}
