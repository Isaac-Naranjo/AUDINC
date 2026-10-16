<?php
// Copiar como config.local.php (ignorado por git) y completar la contraseña.
// Nunca subir credenciales reales al repositorio (A5.17).
return [
    'db' => [
        'usuario'    => 'AUDINC_APP',
        'contrasena' => '',
        'dsn'        => '//localhost:1521/XEPDB1',
        'charset'    => 'AL32UTF8',
    ],
    // Cantidad máxima de filas de evidencia que se guardan por control
    'max_filas_evidencia' => 200,
];
