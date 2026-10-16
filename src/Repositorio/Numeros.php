<?php
declare(strict_types=1);

namespace Audinc\Repositorio;

/** OCI8 devuelve los NUMBER como texto; esto los convierte a int conservando NULL. */
final class Numeros
{
    public static function enteros(array $filas, array $campos): array
    {
        foreach ($filas as &$fila) {
            foreach ($campos as $campo) {
                if (isset($fila[$campo])) {
                    $fila[$campo] = (int) $fila[$campo];
                }
            }
        }
        return $filas;
    }
}
