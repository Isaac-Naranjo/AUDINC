<?php
declare(strict_types=1);

namespace Audinc\Seguridad;

use RuntimeException;

final class AutenticacionException extends RuntimeException
{
    public function __construct(private readonly int $codigoHttp, string $mensaje)
    {
        parent::__construct($mensaje);
    }

    public function codigoHttp(): int
    {
        return $this->codigoHttp;
    }
}
