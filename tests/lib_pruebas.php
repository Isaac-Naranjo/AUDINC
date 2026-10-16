<?php
declare(strict_types=1);

/**
 * Utilidades compartidas por las pruebas funcionales que usan la API (PT-22, PT-23).
 */

date_default_timezone_set('America/Costa_Rica');

final class ClienteApi
{
    private ?string $cookie = null;

    public function __construct(private readonly string $base)
    {
    }

    /** @return array{0: int, 1: mixed, 2: ?string} [código HTTP, cuerpo JSON, Set-Cookie] */
    public function peticion(string $metodo, string $ruta, ?array $json = null, bool $conCookie = true): array
    {
        $cabeceras = [];
        if ($json !== null) {
            $cabeceras[] = 'Content-Type: application/json';
        }
        if ($conCookie && $this->cookie !== null) {
            $cabeceras[] = "Cookie: {$this->cookie}";
        }
        $contexto = stream_context_create(['http' => [
            'method'        => $metodo,
            'header'        => implode("\r\n", $cabeceras),
            'content'       => $json === null ? '' : json_encode($json),
            'ignore_errors' => true,
            'timeout'       => 120,
        ]]);
        $cuerpo = @file_get_contents($this->base . $ruta, false, $contexto);
        if ($cuerpo === false && !isset($http_response_header)) {
            throw new RuntimeException("No se pudo conectar con {$this->base}. ¿Está corriendo el servidor PHP?");
        }
        $codigo = (int) explode(' ', $http_response_header[0] ?? 'HTTP/1.1 0')[1];
        $setCookie = null;
        foreach ($http_response_header as $h) {
            if (stripos($h, 'Set-Cookie: AUDINC_SESION=') === 0) {
                $setCookie = substr($h, 12);
            }
        }
        return [$codigo, json_decode((string) $cuerpo, true), $setCookie];
    }

    public function iniciarSesion(string $usuario, string $contrasena): array
    {
        [$codigo, $cuerpo, $setCookie] = $this->peticion('POST', '/api/sesion',
            ['usuario' => $usuario, 'contrasena' => $contrasena], false);
        if ($codigo === 200 && $setCookie !== null) {
            $this->cookie = explode(';', $setCookie)[0];
        }
        return [$codigo, $cuerpo, $setCookie];
    }
}

final class Registro
{
    private array $lineas = [];
    private int $fallos = 0;

    public function __construct(string $titulo)
    {
        $this->lineas[] = $titulo . ' · ' . date('Y-m-d H:i:s');
        $this->lineas[] = str_repeat('-', 100);
    }

    public function nota(string $texto): void
    {
        $this->lineas[] = $texto;
    }

    public function caso(string $descripcion, mixed $esperado, mixed $obtenido, string $detalle = ''): bool
    {
        $ok = $esperado === $obtenido;
        $this->fallos += $ok ? 0 : 1;
        $this->lineas[] = sprintf('[%s] %-58s esperado %s, obtenido %s %s', $ok ? 'OK' : 'FALLA', $descripcion,
            self::texto($esperado), self::texto($obtenido), $detalle);
        return $ok;
    }

    private static function texto(mixed $valor): string
    {
        return is_array($valor) ? json_encode($valor, JSON_UNESCAPED_UNICODE) : var_export($valor, true);
    }

    /** Escribe la evidencia y devuelve el código de salida del proceso. */
    public function cerrar(string $archivo): int
    {
        $this->lineas[] = str_repeat('-', 100);
        $this->lineas[] = $this->fallos === 0 ? 'RESULTADO: todos los casos OK' : "RESULTADO: {$this->fallos} caso(s) fallaron";
        $salida = implode(PHP_EOL, $this->lineas) . PHP_EOL;
        echo PHP_EOL . $salida;
        file_put_contents(dirname(__DIR__) . '/evidencias/salidas/' . $archivo, $salida);
        return $this->fallos === 0 ? 0 : 1;
    }
}

function leerContrasena(string $pregunta): string
{
    fwrite(STDOUT, $pregunta);
    return trim((string) fgets(STDIN));
}

/**
 * Ejecuta una sentencia como SYSDBA en XEPDB1 (autenticación del sistema operativo,
 * sin contraseña). Requiere ejecutar la prueba en el servidor de base de datos.
 */
function comoSysdba(string $sentencia): void
{
    $archivo = tempnam(sys_get_temp_dir(), 'audinc') . '.sql';
    file_put_contents($archivo, "WHENEVER SQLERROR EXIT 1\nALTER SESSION SET CONTAINER = XEPDB1;\n{$sentencia};\nEXIT\n");
    putenv('ORACLE_SID=XE');
    exec('sqlplus -S -L "/ as sysdba" @"' . $archivo . '"', $salida, $codigo);
    unlink($archivo);
    if ($codigo !== 0) {
        throw new RuntimeException("Falló como SYSDBA: {$sentencia}\n" . implode("\n", $salida));
    }
}
