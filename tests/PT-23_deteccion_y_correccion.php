<?php
declare(strict_types=1);

/**
 * PT-23 · Funcional · Ciclo Verificar → Actuar sobre A5.15 (CO-02)
 * Demuestra que el evaluador DETECTA una brecha real y registra su CORRECCIÓN:
 *   1. Se introduce la brecha: GRANT SELECT ON AUDINC_DEMO.CLIENTES TO PUBLIC
 *   2. Evaluación → CO-02 debe quedar "No cumple" con el permiso como evidencia
 *   3. Se corrige la brecha: REVOKE ... FROM PUBLIC
 *   4. Evaluación → CO-02 debe volver a "Cumple"
 * El REVOKE se ejecuta SIEMPRE (aunque falle algún paso): la brecha nunca queda abierta.
 * Ambas evaluaciones quedan guardadas en el histórico y el GRANT/REVOKE en la auditoría
 * (política AUDINC_GESTION_ACCESOS).
 *
 * Requisitos: evaluador corriendo (php -S localhost:8000 -t public public/index.php)
 *             y ejecutar en el servidor de Oracle (usa "sqlplus / as sysdba").
 * Uso:   php tests/PT-23_deteccion_y_correccion.php [url_base]
 * Salida: evidencias/salidas/PT-23_deteccion_y_correccion.txt
 */

require __DIR__ . '/lib_pruebas.php';

const BRECHA     = 'GRANT SELECT ON audinc_demo.clientes TO PUBLIC';
const CORRECCION = 'REVOKE SELECT ON audinc_demo.clientes FROM PUBLIC';

$api = new ClienteApi(rtrim($argv[1] ?? 'http://localhost:8000', '/'));
$registro = new Registro('PT-23 · Detección y corrección de una brecha (A5.15 / CO-02)');
$contrasena = leerContrasena('Contraseña de ANA: ');

/** Ejecuta una evaluación y devuelve el detalle de CO-02. */
function evaluarCo02(ClienteApi $api, Registro $registro, string $observacion): ?array
{
    [$codigo, $evaluacion] = $api->peticion('POST', '/api/evaluaciones', ['observaciones' => $observacion]);
    $registro->caso("Evaluación registrada ({$observacion})", 201, $codigo,
        isset($evaluacion['id_evaluacion']) ? "→ evaluación #{$evaluacion['id_evaluacion']}" : '');
    foreach ($evaluacion['detalles'] ?? [] as $detalle) {
        if ($detalle['id_co'] === 'CO-02') {
            return $detalle;
        }
    }
    return null;
}

try {
    [$codigo] = $api->iniciarSesion('ANA', $contrasena);
    if (!$registro->caso('Inicio de sesión como ANA (AUDITOR)', 200, $codigo)) {
        exit($registro->cerrar('PT-23_deteccion_y_correccion.txt'));
    }

    // 1-2. Brecha y detección
    comoSysdba(BRECHA);
    $registro->nota('Paso 1 · SYSDBA: ' . BRECHA);
    $co02 = evaluarCo02($api, $registro, 'PT-23 paso 1: brecha introducida (GRANT a PUBLIC)');
    $registro->caso('CO-02 detecta la brecha: estado', 'No cumple', $co02['estado'] ?? null);
    $registro->caso('CO-02 detecta la brecha: hallazgos', 1, $co02['hallazgos'] ?? null);
    $filas = $co02['evidencia']['filas'] ?? [];
    $registro->caso('La evidencia muestra el permiso concedido', ['CLIENTES', 'SELECT'], $filas[0] ?? null);
} catch (Throwable $e) {
    $registro->caso('Ejecución sin errores', 'sin error', $e->getMessage());
} finally {
    // 3. Corrección: se ejecuta siempre
    try {
        comoSysdba(CORRECCION);
        $registro->nota('Paso 3 · SYSDBA: ' . CORRECCION);
    } catch (Throwable $e) {
        $registro->caso('¡CORRECCIÓN NO APLICADA! Ejecutar manualmente: ' . CORRECCION, 'ok', $e->getMessage());
    }
}

try {
    // 4. Verificación de la corrección
    $co02 = evaluarCo02($api, $registro, 'PT-23 paso 2: brecha corregida (REVOKE a PUBLIC)');
    $registro->caso('CO-02 tras la corrección: estado', 'Cumple', $co02['estado'] ?? null);
    $registro->caso('CO-02 tras la corrección: hallazgos', 0, $co02['hallazgos'] ?? null,
        '(nivel ' . ($co02['nivel'] ?? '-') . ': ' . ($co02['justificacion'] ?? '') . ')');
} catch (Throwable $e) {
    $registro->caso('Ejecución sin errores', 'sin error', $e->getMessage());
} finally {
    $api->peticion('DELETE', '/api/sesion');
}

exit($registro->cerrar('PT-23_deteccion_y_correccion.txt'));
