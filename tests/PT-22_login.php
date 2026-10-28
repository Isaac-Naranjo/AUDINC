<?php
declare(strict_types=1);

/**
 * PT-22 · Funcional · Autenticación y autorización de la aplicación (A5.15, A5.16, A8.5, A8.15)
 * Requiere el evaluador corriendo (php -S localhost:8000 -t public public/index.php).
 *
 * Uso:  php tests/PT-22_login.php [url_base]
 *       Pide la contraseña de los usuarios de prueba (ISAAC, LUIS) por teclado.
 * Salida: evidencias/salidas/PT-22_login.txt
 *
 * Nota: NO prueba contraseñas incorrectas contra ISAAC para no acercarla al bloqueo
 * (FAILED_LOGIN_ATTEMPTS = 3); eso ya lo demuestra PT-19 con PEDRO.
 */

require __DIR__ . '/lib_pruebas.php';

$api = new ClienteApi(rtrim($argv[1] ?? 'http://localhost:8000', '/'));
$registro = new Registro('PT-22 · Login de la aplicación AUDINC');
$contrasena = leerContrasena('Contraseña de los usuarios de prueba: ');

[$c] = $api->peticion('GET', '/api/resumen', null, false);
$registro->caso('Sin sesión: GET /api/resumen', 401, $c);

[$c] = (new ClienteApi(rtrim($argv[1] ?? 'http://localhost:8000', '/')))->iniciarSesion('LUIS', $contrasena);
$registro->caso('LUIS (SUPERVISOR, sin rol AUDITOR) inicia sesión', 403, $c);

[$c, , $sc] = $api->iniciarSesion('ISAAC', $contrasena);
$registro->caso('ISAAC (rol AUDITOR) inicia sesión', 200, $c);
$registro->caso('Cookie de sesión con HttpOnly y SameSite=Strict', true,
    $sc !== null && stripos($sc, 'HttpOnly') !== false && stripos($sc, 'SameSite=Strict') !== false);

[$c, $actividad] = $api->peticion('GET', '/api/mi-actividad');
$registro->caso('ISAAC consulta su propia actividad', 200, $c,
    '(acceso anterior: ' . ($actividad['acceso_anterior'] ?? '-') . ')');

[$c, $ev] = $api->peticion('POST', '/api/evaluaciones', ['observaciones' => 'PT-22: evaluación lanzada por ISAAC']);
$registro->caso('ISAAC lanza una evaluación', 201, $c);
$registro->caso('La evaluación queda a nombre de ISAAC (CLIENT_IDENTIFIER)', 'ISAAC', $ev['usuario_bd'] ?? null);

[$c] = $api->peticion('DELETE', '/api/sesion');
$registro->caso('Cierre de sesión', 204, $c);

[$c] = $api->peticion('GET', '/api/resumen');
$registro->caso('Con la cookie anterior tras cerrar sesión', 401, $c);

exit($registro->cerrar('PT-22_login.txt'));
