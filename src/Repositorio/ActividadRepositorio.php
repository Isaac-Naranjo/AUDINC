<?php
declare(strict_types=1);

namespace Audinc\Repositorio;

use Audinc\Database;

/**
 * "Mi actividad": el usuario ve sus propios accesos fallidos y evaluaciones,
 * para detectar el uso indebido de su cuenta. Solo lectura (A5.33).
 */
final class ActividadRepositorio
{
    public function __construct(private readonly Database $db)
    {
    }

    /** Último inicio de sesión registrado por Oracle (se consulta ANTES de validar el nuevo). */
    public function ultimoAcceso(string $usuario): ?string
    {
        $fila = $this->db->consultarUno(
            "SELECT TO_CHAR(CAST(last_login AT TIME ZONE SESSIONTIMEZONE AS TIMESTAMP), 'YYYY-MM-DD HH24:MI:SS') AS ultimo
               FROM dba_users WHERE username = :u",
            [':u' => $usuario]
        );
        return $fila['ultimo'] ?? null;
    }

    public function de(string $usuario, ?string $accesoAnterior): array
    {
        $cuenta = $this->db->consultarUno(
            "SELECT account_status, profile, TO_CHAR(expiry_date, 'YYYY-MM-DD') AS vence_contrasena
               FROM dba_users WHERE username = :u",
            [':u' => $usuario]
        );

        // EVENT_TIMESTAMP_UTC (no EVENT_TIMESTAMP, que ya viene en hora local de la base)
        // se convierte a la zona horaria de la sesión
        $fallidos = Numeros::enteros($this->db->consultar(
            "SELECT TO_CHAR(CAST(FROM_TZ(event_timestamp_utc, '+00:00') AT TIME ZONE SESSIONTIMEZONE AS TIMESTAMP),
                            'YYYY-MM-DD HH24:MI:SS') AS hora,
                    return_code AS codigo_ora,
                    userhost AS equipo
               FROM unified_audit_trail
              WHERE dbusername = :u
                AND action_name = 'LOGON'
                AND return_code <> 0
                AND event_timestamp_utc > SYS_EXTRACT_UTC(SYSTIMESTAMP) - INTERVAL '30' DAY
              ORDER BY event_timestamp_utc DESC
              FETCH FIRST 20 ROWS ONLY",
            [':u' => $usuario]
        ), ['codigo_ora']);

        $evaluaciones = Numeros::enteros($this->db->consultar(
            'SELECT id_evaluacion, fecha, observaciones
               FROM audinc_owner.evaluacion
              WHERE usuario_bd = :u
              ORDER BY id_evaluacion DESC
              FETCH FIRST 20 ROWS ONLY',
            [':u' => $usuario]
        ), ['id_evaluacion']);

        return [
            'usuario'                       => $usuario,
            'cuenta'                        => $cuenta,
            'acceso_anterior'               => $accesoAnterior,
            'intentos_fallidos_desde_ultimo_acceso' => count(array_filter(
                $fallidos,
                static fn(array $f): bool => $accesoAnterior === null || $f['hora'] > $accesoAnterior
            )),
            'intentos_fallidos_30_dias'     => $fallidos,
            'evaluaciones_lanzadas'         => $evaluaciones,
        ];
    }
}
