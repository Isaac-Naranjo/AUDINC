<?php
// Copiar como config.local.php (ignorado por git) y completar la contraseña.
// Nunca subir credenciales reales al repositorio (A5.17).
return [
    'db' => [
        'usuario'    => 'AUDINC_APP',
        'contrasena' => '',
        'dsn'        => '//localhost:1521/XEPDB1',
        'charset'    => 'AL32UTF8',
        'timeout_ms' => 30000,   // tiempo máximo por llamada a Oracle
        'zona_horaria' => '-06:00', // Costa Rica (sin horario de verano)
    ],
    'zona_horaria_php' => 'America/Costa_Rica',
    // Cantidad máxima de filas de evidencia que se guardan por control
    'max_filas_evidencia' => 200,
];
