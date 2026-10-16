<?php
declare(strict_types=1);

namespace Audinc;

/**
 * Envoltorio mínimo sobre OCI8.
 * - Todas las sentencias usan variables bind (sin concatenar entradas).
 * - Nada se confirma automáticamente: las escrituras requieren commit().
 */
final class Database
{
    /** @var resource */
    private $conexion;

    public function __construct(array $config)
    {
        $conexion = @oci_connect(
            $config['usuario'],
            $config['contrasena'],
            $config['dsn'],
            $config['charset'] ?? 'AL32UTF8'
        );
        if ($conexion === false) {
            throw new BaseDatosException('No se pudo conectar a la base de datos', oci_error()['message'] ?? '');
        }
        $this->conexion = $conexion;
        $this->ejecutar("ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'");
        $this->ejecutar("ALTER SESSION SET NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'");
    }

    /** Filas como arreglos asociativos con claves en minúscula. */
    public function consultar(string $sql, array $binds = []): array
    {
        $sentencia = $this->ejecutarSentencia($sql, $binds);
        $filas = [];
        while (($fila = oci_fetch_array($sentencia, OCI_ASSOC | OCI_RETURN_NULLS | OCI_RETURN_LOBS)) !== false) {
            $filas[] = array_change_key_case($fila, CASE_LOWER);
        }
        oci_free_statement($sentencia);
        return $filas;
    }

    public function consultarUno(string $sql, array $binds = []): ?array
    {
        return $this->consultar($sql, $binds)[0] ?? null;
    }

    /**
     * Ejecuta una consulta y conserva el orden de columnas (para guardar evidencia).
     * @return array{columnas: string[], filas: array[], total: int}
     */
    public function consultarTabla(string $sql, int $maxFilas): array
    {
        $sentencia = $this->ejecutarSentencia($sql, []);
        $columnas = [];
        for ($i = 1, $n = oci_num_fields($sentencia); $i <= $n; $i++) {
            $columnas[] = strtolower(oci_field_name($sentencia, $i));
        }
        $filas = [];
        $total = 0;
        while (($fila = oci_fetch_array($sentencia, OCI_NUM | OCI_RETURN_NULLS | OCI_RETURN_LOBS)) !== false) {
            if (++$total <= $maxFilas) {
                $filas[] = $fila;
            }
        }
        oci_free_statement($sentencia);
        return ['columnas' => $columnas, 'filas' => $filas, 'total' => $total];
    }

    public function ejecutar(string $sql, array $binds = []): void
    {
        oci_free_statement($this->ejecutarSentencia($sql, $binds));
    }

    /** INSERT ... RETURNING <columna> INTO :id */
    public function insertarRetornandoId(string $sql, array $binds): int
    {
        $sentencia = oci_parse($this->conexion, $sql);
        foreach ($binds as $nombre => $valor) {
            $binds[$nombre] = $valor;
            oci_bind_by_name($sentencia, $nombre, $binds[$nombre]);
        }
        $id = '';
        oci_bind_by_name($sentencia, ':id', $id, 32);
        $this->ejecutarParseada($sentencia);
        oci_free_statement($sentencia);
        return (int) $id;
    }

    /** Sentencia con un parámetro CLOB (texto mayor a 4000 bytes). */
    public function ejecutarConClob(string $sql, array $binds, string $nombreClob, string $contenido): void
    {
        $sentencia = oci_parse($this->conexion, $sql);
        foreach ($binds as $nombre => $valor) {
            $binds[$nombre] = $valor;
            oci_bind_by_name($sentencia, $nombre, $binds[$nombre]);
        }
        $clob = oci_new_descriptor($this->conexion, OCI_D_LOB);
        oci_bind_by_name($sentencia, $nombreClob, $clob, -1, OCI_B_CLOB);
        $clob->writeTemporary($contenido, OCI_TEMP_CLOB);
        try {
            $this->ejecutarParseada($sentencia);
        } finally {
            $clob->close();
            $clob->free();
            oci_free_statement($sentencia);
        }
    }

    public function commit(): void
    {
        oci_commit($this->conexion);
    }

    public function rollback(): void
    {
        oci_rollback($this->conexion);
    }

    /** @return resource */
    private function ejecutarSentencia(string $sql, array $binds)
    {
        $sentencia = @oci_parse($this->conexion, $sql);
        if ($sentencia === false) {
            throw new BaseDatosException('Error al preparar la consulta', oci_error($this->conexion)['message'] ?? '');
        }
        foreach ($binds as $nombre => $valor) {
            $binds[$nombre] = $valor;
            oci_bind_by_name($sentencia, $nombre, $binds[$nombre]);
        }
        $this->ejecutarParseada($sentencia);
        return $sentencia;
    }

    /** @param resource $sentencia */
    private function ejecutarParseada($sentencia): void
    {
        if (!@oci_execute($sentencia, OCI_NO_AUTO_COMMIT)) {
            $detalle = oci_error($sentencia)['message'] ?? '';
            oci_free_statement($sentencia);
            throw new BaseDatosException('Error al ejecutar la consulta', $detalle);
        }
    }
}
