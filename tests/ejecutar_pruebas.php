<?php
declare(strict_types=1);

// Pruebas unitarias de la lógica del evaluador (no requieren Oracle).
// Uso: php tests/ejecutar_pruebas.php

require dirname(__DIR__) . '/src/bootstrap.php';

use Audinc\Servicio\EvaluadorServicio as Evaluador;

$fallos = 0;
$total  = 0;

function verificar(bool $condicion, string $descripcion): void
{
    global $fallos, $total;
    $total++;
    if (!$condicion) {
        $fallos++;
        echo "FALLA: {$descripcion}\n";
    }
}

// --- calificar(hallazgos, anterior, lineaBase) -> [nivel, estado, justificación]
$casos = [
    // hallazgos, anterior, línea base, nivel, estado
    [null, null, null, 0, 'No cumple'],   // consulta falló
    [5,    null, null, 1, 'No cumple'],   // primera evaluación con hallazgos
    [5,    5,    5,    1, 'No cumple'],   // sin mejora
    [6,    5,    5,    1, 'No cumple'],   // empeoró
    [2,    5,    8,    2, 'Parcial'],     // mejoró respecto a la línea base
    [0,    3,    8,    3, 'Cumple'],      // cumple por primera vez
    [0,    null, null, 3, 'Cumple'],      // cumple en la primera evaluación
    [0,    0,    8,    4, 'Cumple'],      // sostenido
];
foreach ($casos as [$h, $a, $b, $nivel, $estado]) {
    [$n, $e] = Evaluador::calificar($h, $a, $b);
    verificar($n === $nivel && $e === $estado,
        sprintf('calificar(%s, %s, %s) = [%d, %s], esperado [%d, %s]',
            var_export($h, true), var_export($a, true), var_export($b, true), $n, $e, $nivel, $estado));
}

// Con excepciones el nivel máximo es 3 (riesgo aceptado != control implementado)
[$n, $e] = Evaluador::calificar(0, 0, 8, 2);
verificar($n === 3 && $e === 'Cumple', 'con excepciones no se otorga nivel 4');
[$n, , $j] = Evaluador::calificar(2, 5, 8, 1);
verificar($n === 2 && str_contains($j, 'exceptuado'), 'la justificación menciona las excepciones');

// --- aplicarExcepciones(tabla, objetosExceptuados)
$tabla = [
    'columnas' => ['username', 'profile'],
    'filas'    => [['PDBADMIN', 'DEFAULT'], ['C##BGBACKUP', 'DEFAULT'], ['JUAN', 'DEFAULT']],
    'total'    => 3,
];

$r = Evaluador::aplicarExcepciones($tabla, []);
verificar($r['total'] === 3 && $r['exceptuados'] === [], 'sin excepciones no cambia nada');

$r = Evaluador::aplicarExcepciones($tabla, ['C##BGBACKUP' => true, 'NO_EXISTE' => true]);
verificar($r['total'] === 2, 'una excepción descuenta un hallazgo');
verificar($r['exceptuados'] === [['C##BGBACKUP', 'DEFAULT']], 'el hallazgo exceptuado queda visible en la evidencia');
verificar(count($r['filas']) === 2, 'los demás hallazgos siguen en filas');

$r = Evaluador::aplicarExcepciones($tabla, ['DEFAULT' => true]);
verificar($r['total'] === 3, 'solo se compara la primera columna');

$r = Evaluador::aplicarExcepciones($tabla, ['PDBADMIN' => true, 'C##BGBACKUP' => true, 'JUAN' => true]);
verificar($r['total'] === 0, 'todas exceptuadas -> 0 hallazgos');

// Excepción por prefijo (respaldos con nombres que cambian)
$piezas = [
    'columnas' => ['objeto', 'hallazgo'],
    'filas'    => [
        ['C:\\BACKUPGUARD_RMAN\\XE\\EST010_XE_1.BKP', 'Pieza sin cifrar'],
        ['C:\\BACKUPGUARD_RMAN\\XE\\EST011_XE_2.BKP', 'Pieza sin cifrar'],
        ['C:\\OTRO\\XE_3.BKP', 'Pieza sin cifrar'],
    ],
    'total'    => 3,
];
$r = Evaluador::aplicarExcepciones($piezas, ['C:\\BACKUPGUARD_RMAN\\%' => true]);
verificar($r['total'] === 1 && count($r['exceptuados']) === 2, 'prefijo con % cubre todos los archivos de la carpeta');
verificar($r['filas'][0][0] === 'C:\\OTRO\\XE_3.BKP', 'el prefijo no cubre otras carpetas');

$r = Evaluador::aplicarExcepciones($piezas, ['%' => true]);
verificar($r['total'] === 3, 'un % solo no exceptúa todo');

echo ($fallos === 0 ? "OK" : "FALLARON {$fallos}") . ": {$total} verificaciones\n";
exit($fallos === 0 ? 0 : 1);
