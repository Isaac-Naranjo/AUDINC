<?php
declare(strict_types=1);

/**
 * AUDINC · punto de entrada.
 * Desarrollo:  php -S localhost:8000 -t public public/index.php
 * Solo la carpeta public/ queda expuesta; src/ y config/ no son accesibles por URL.
 */

// Con el servidor integrado, los archivos estáticos existentes se sirven tal cual,
// pero solo si están DENTRO de public/ (evita ../config/config.local.php)
if (PHP_SAPI === 'cli-server') {
    $archivo = realpath(__DIR__ . rawurldecode((string) parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH)));
    if ($archivo !== false
        && str_starts_with($archivo, __DIR__ . DIRECTORY_SEPARATOR)
        && is_file($archivo)
        && $archivo !== __FILE__) {
        return false;
    }
}

require dirname(__DIR__) . '/src/bootstrap.php';

use Audinc\BaseDatosException;
use Audinc\Database;
use Audinc\Repositorio\ActividadRepositorio;
use Audinc\Repositorio\CatalogoRepositorio;
use Audinc\Repositorio\CuentasRepositorio;
use Audinc\Repositorio\EvaluacionRepositorio;
use Audinc\Repositorio\ResumenRepositorio;
use Audinc\Seguridad\Autenticacion;
use Audinc\Seguridad\AutenticacionException;
use Audinc\Seguridad\Sesion;
use Audinc\Servicio\EvaluadorServicio;

ini_set('display_errors', '0');

header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store');
header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'");

function responder(int $codigo, mixed $datos = null): never
{
    http_response_code($codigo);
    if ($codigo !== 204) {
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($datos, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
    }
    exit;
}

/**
 * Cuerpo JSON de la petición. Exigir Content-Type: application/json obliga al
 * navegador a hacer preflight CORS: otra página no puede enviar estas peticiones
 * en nombre del usuario (CSRF), y la cookie además es SameSite=Strict.
 */
function cuerpoJson(): array
{
    if (!str_starts_with($_SERVER['CONTENT_TYPE'] ?? '', 'application/json')) {
        responder(415, ['error' => 'Se requiere Content-Type: application/json']);
    }
    $cuerpo = json_decode(file_get_contents('php://input') ?: '{}', true);
    if (!is_array($cuerpo)) {
        responder(400, ['error' => 'El cuerpo debe ser JSON válido en UTF-8']);
    }
    return $cuerpo;
}

$metodo = $_SERVER['REQUEST_METHOD'];
$ruta   = rtrim((string) parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH), '/') ?: '/';

// Interfaz web: se sirve desde src/Vista (fuera de public/) para enviarla con su propia CSP.
// Solo recursos propios: sin CDN, sin scripts ni estilos en línea.
if ($ruta === '/' && $metodo === 'GET') {
    header('Content-Type: text/html; charset=utf-8');
    header("Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; "
         . "connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'");
    readfile(dirname(__DIR__) . '/src/Vista/app.html');
    exit;
}

if ($ruta === '/api') {
    responder(200, [
        'aplicacion' => 'AUDINC - Evaluador de confidencialidad ISO/IEC 27001:2022',
        'autenticacion' => 'POST /api/sesion {"usuario","contrasena"} con una cuenta Oracle con rol AUDITOR',
        'endpoints'  => [
            'POST   /api/sesion',
            'GET    /api/sesion',
            'DELETE /api/sesion',
            'GET    /api/mi-actividad',
            'GET    /api/resumen',
            'GET    /api/cuentas',
            'GET    /api/cuentas/{usuario}',
            'GET    /api/riesgos',
            'GET    /api/tareas',
            'GET    /api/controles',
            'GET    /api/controles-observables',
            'GET    /api/pruebas',
            'GET    /api/matriz',
            'GET    /api/excepciones',
            'GET    /api/evaluaciones',
            'GET    /api/evaluaciones/{id}',
            'POST   /api/evaluaciones   {"observaciones": "..."}',
        ],
    ]);
}

if (!str_starts_with($ruta, '/api/')) {
    responder(404, ['error' => 'Ruta no encontrada']);
}

try {
    Sesion::iniciar();
    $config = audinc_config();

    // --- Sesión (única ruta accesible sin autenticar) -------------------
    if ($ruta === '/api/sesion') {
        if ($metodo === 'POST') {
            $cuerpo = cuerpoJson();
            $usuario = strtoupper(trim((string) ($cuerpo['usuario'] ?? '')));
            $contrasena = (string) ($cuerpo['contrasena'] ?? '');

            // El acceso anterior se lee ANTES de validar, porque la validación abre una
            // sesión en Oracle y actualiza LAST_LOGIN. Solo se devuelve si el login es exitoso.
            $accesoAnterior = (new ActividadRepositorio(new Database($config['db'])))->ultimoAcceso($usuario);

            $usuario = (new Autenticacion($config['db']))->validar($usuario, $contrasena);
            Sesion::abrir($usuario, ['acceso_anterior' => $accesoAnterior]);
            responder(200, Sesion::info());
        }
        if ($metodo === 'GET') {
            Sesion::usuario() !== null
                ? responder(200, Sesion::info())
                : responder(401, ['error' => 'Sin sesión']);
        }
        if ($metodo === 'DELETE') {
            Sesion::cerrar();
            responder(204);
        }
        responder(405, ['error' => 'Método no permitido']);
    }

    // --- A partir de aquí todo requiere sesión --------------------------
    $usuario = Sesion::usuario();
    if ($usuario === null) {
        responder(401, ['error' => 'Inicie sesión con una cuenta Oracle con rol ' . Autenticacion::ROL_REQUERIDO]);
    }

    $db = new Database($config['db']);
    $db->establecerUsuarioFinal($usuario);
    $catalogo     = new CatalogoRepositorio($db);
    $evaluaciones = new EvaluacionRepositorio($db);
    $cuentas      = new CuentasRepositorio($db, $catalogo);

    $rutasGet = [
        '/api/mi-actividad'          => fn() => (new ActividadRepositorio($db))->de($usuario, Sesion::dato('acceso_anterior')),
        '/api/resumen'               => fn() => (new ResumenRepositorio($db, $evaluaciones, $cuentas))->resumen(),
        '/api/cuentas'               => fn() => $cuentas->auditar(),
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

    // Los usuarios comunes llevan '#' (C##...), que llega codificado como %23
    if ($metodo === 'GET' && preg_match('#^/api/cuentas/([A-Za-z0-9_$%]{1,400})$#', $ruta, $m)) {
        $nombre = strtoupper(rawurldecode($m[1]));
        if (!preg_match('/^[A-Z][A-Z0-9_$#]{0,127}$/', $nombre)) {
            responder(404, ['error' => 'Cuenta no encontrada']);
        }
        $cuenta = $cuentas->cuenta($nombre);
        responder($cuenta ? 200 : 404, $cuenta ?? ['error' => 'Cuenta no encontrada']);
    }

    if ($metodo === 'POST' && $ruta === '/api/evaluaciones') {
        $cuerpo = cuerpoJson();
        $observaciones = isset($cuerpo['observaciones']) ? trim((string) $cuerpo['observaciones']) : null;
        if ($observaciones !== null && mb_strlen($observaciones) > 400) {
            responder(422, ['error' => 'Observaciones: máximo 400 caracteres']);
        }
        $servicio = new EvaluadorServicio($db, $catalogo, $evaluaciones, (int) ($config['max_filas_evidencia'] ?? 200));
        responder(201, $servicio->evaluar($observaciones ?: null));
    }

    responder(404, ['error' => 'Ruta no encontrada']);
} catch (AutenticacionException $e) {
    responder($e->codigoHttp(), ['error' => $e->getMessage()]);
} catch (BaseDatosException $e) {
    error_log('AUDINC: ' . $e->detalle());
    responder(503, ['error' => $e->getMessage(), 'codigo' => $e->codigoOra()]);
} catch (Throwable $e) {
    error_log('AUDINC: ' . $e);
    responder(500, ['error' => 'Error interno']);
}
