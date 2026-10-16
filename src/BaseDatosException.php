<?php
declare(strict_types=1);

namespace Audinc;

use RuntimeException;

/**
 * Error de Oracle. El mensaje público es genérico; el detalle ORA-xxxxx
 * solo se usa en el log del servidor y en la evidencia interna.
 */
final class BaseDatosException extends RuntimeException
{
    public function __construct(string $mensaje, private readonly string $detalle = '')
    {
        parent::__construct($mensaje);
    }

    public function detalle(): string
    {
        return $this->detalle;
    }

    /** Solo el código ORA-xxxxx, sin el texto (no expone nombres de objetos). */
    public function codigoOra(): string
    {
        return preg_match('/ORA-\d{5}/', $this->detalle, $m) ? $m[0] : 'desconocido';
    }
}
