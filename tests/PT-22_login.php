<?php
declare(strict_types=1);

/**
 * PT-22 · Funcional · Autenticación y autorización de la aplicación (A5.15, A5.16, A8.5, A8.15)
 * Requiere el evaluador corriendo (php -S localhost:8000 -t public public/index.php).
 *
 * Uso:  php tests/PT-22_login.php [url_base]
 *       Pide la contraseña de los usuarios de prueba (ANA, LUIS) por teclado.
 * Salida: evidencias/salidas/PT-22_login.txt
 *
 * Nota: NO prueba contraseñas incorrectas contra ANA para no acercarla al bloqueo
 * (FAILED_LOGIN_ATTEMPTS = 3); eso ya lo demuestra PT-19 con PEDRO.
 */

date_default_timezone_set('America/Costa_Rica');
$base = rtrim($argv[1] ?? 'http://localhost:8000', '/');
fwrite(STDOUT, 'Contraseña de los usuarios de prueba: ');
$contrasena = trim((string) fgets(STDIN));

$cookie = null;
$lineas = [];
$fallos = 0;

function peticion(string $metodo, string $ruta, ?array $json = null, bool $conCookie = true): array
{
    global $base, $cookie;
    $cabeceras = [];
    if ($json !== null) {
        $cabeceras[] = 'Content-Type: application/json';
    }
    if ($conCookie && $cookie !== null) {
        $cabeceras[] = "Cookie: {$cookie}";
    }
    $contexto = stream_context_create(['http' => [
        'method'        => $metodo,
        'header'        => implode("\r\n", $cabeceras),
        'content'       => $json === null ? '' : json_encode($json),
        'ignore_errors' => true,
    ]]);
    $cuerpo = file_get_contents($base . $ruta, false, $contexto);
    $codigo = (int) explode(' ', $http_response_header[0] ?? 'HTTP/1.1 0')[1];
    $setCookie = null;
    foreach ($http_response_header as $h) {
        if (stripos($h, 'Set-Cookie: AUDINC_SESION=') === 0) {
            $setCookie = substr($h, 12);
        }
    }
    return [$codigo, json_decode((string) $cuerpo, true), $setCookie];
}

function caso(string $descripcion, int $esperado, int $obtenido, string $detalle = ''): void
{
    global $lineas, $fallos;
    $ok = $esperado === $obtenido;
    $fallos += $ok ? 0 : 1;
    $lineas[] = sprintf('[%s] %-55s esperado %d, obtenido %d %s', $ok ? 'OK' : 'FALLA', $descripcion, $esperado, $obtenido, $detalle);
}

$lineas[] = 'PT-22 · Login de la aplicación AUDINC · ' . date('Y-m-d H:i:s');
$lineas[] = str_repeat('-', 100);

[$c] = peticion('GET', '/api/resumen', null, false);
caso('Sin sesión: GET /api/resumen', 401, $c);

[$c] = peticion('POST', '/api/sesion', ['usuario' => 'LUIS', 'contrasena' => $contrasena], false);
caso('LUIS (SUPERVISOR, sin rol AUDITOR) inicia sesión', 403, $c);

[$c, , $sc] = peticion('POST', '/api/sesion', ['usuario' => 'ANA', 'contrasena' => $contrasena], false);
caso('ANA (rol AUDITOR) inicia sesión', 200, $c);
$cookie = $sc ? explode(';', $sc)[0] : null;
caso('Cookie de sesión con HttpOnly y SameSite=Strict', 1,
    (int) ($sc !== null && stripos($sc, 'HttpOnly') !== false && stripos($sc, 'SameSite=Strict') !== false));

[$c, $actividad] = peticion('GET', '/api/mi-actividad');
caso('ANA consulta su propia actividad', 200, $c,
    '(acceso anterior: ' . ($actividad['acceso_anterior'] ?? '-') . ')');

[$c, $ev] = peticion('POST', '/api/evaluaciones', ['observaciones' => 'PT-22: evaluación lanzada por ANA']);
caso('ANA lanza una evaluación', 201, $c);
caso('La evaluación queda a nombre de ANA (CLIENT_IDENTIFIER)', 1, (int) (($ev['usuario_bd'] ?? '') === 'ANA'),
    '(usuario_bd = ' . ($ev['usuario_bd'] ?? '-') . ')');

[$c] = peticion('DELETE', '/api/sesion');
caso('Cierre de sesión', 204, $c);

[$c] = peticion('GET', '/api/resumen');
caso('Con la cookie anterior tras cerrar sesión', 401, $c);

$lineas[] = str_repeat('-', 100);
$lineas[] = $fallos === 0 ? 'RESULTADO: todos los casos OK' : "RESULTADO: {$fallos} caso(s) fallaron";

$salida = implode(PHP_EOL, $lineas) . PHP_EOL;
echo PHP_EOL . $salida;
file_put_contents(dirname(__DIR__) . '/evidencias/salidas/PT-22_login.txt', $salida);
exit($fallos === 0 ? 0 : 1);
