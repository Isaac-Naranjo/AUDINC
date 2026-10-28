<?php
declare(strict_types=1);

namespace Audinc\Repositorio;

use Audinc\Database;

/**
 * Auditoría por cuenta: cada usuario de Oracle (no mantenido por Oracle) se revisa
 * contra los requisitos de confidencialidad que aplican a una cuenta. Los criterios
 * son los mismos de los controles observables (CO-03, CO-04, CO-05, CO-07, CO-09),
 * pero vistos cuenta por cuenta, más la política de contraseñas de su perfil y la
 * cobertura de la auditoría unificada. Las excepciones vigentes de esos controles
 * sobre la cuenta se respetan (el hallazgo queda visible como "Exceptuado").
 * Todo se calcula en vivo desde el diccionario: solo lectura.
 */
final class CuentasRepositorio
{
    public const CUMPLE        = 'Cumple';
    public const CON_EXCEPCION = 'Cumple con excepción';
    public const NO_CUMPLE     = 'No cumple';

    private const R_CUMPLE     = 'Cumple';
    private const R_NO_CUMPLE  = 'No cumple';
    private const R_EXCEPTUADO = 'Exceptuado';
    private const R_NO_APLICA  = 'No aplica';

    private const PERFILES_SEGUROS   = ['AUDINC_SEGURO', 'AUDINC_SERVICIO'];
    private const PERFIL_SERVICIO    = 'AUDINC_SERVICIO';
    private const DIAS_INACTIVIDAD   = 90;
    private const MAX_INTENTOS       = 5;
    private const MAX_VIDA_DIAS      = 180;
    private const DIAS_FALLIDOS      = 30;
    private const PARAMETROS_PERFIL  = [
        'FAILED_LOGIN_ATTEMPTS', 'PASSWORD_LOCK_TIME', 'PASSWORD_LIFE_TIME', 'PASSWORD_GRACE_TIME',
        'PASSWORD_REUSE_TIME', 'PASSWORD_REUSE_MAX', 'PASSWORD_VERIFY_FUNCTION', 'IDLE_TIME', 'SESSIONS_PER_USER',
    ];

    private const USUARIOS_PROPIOS = "SELECT username FROM dba_users WHERE oracle_maintained = 'N'";

    public function __construct(
        private readonly Database $db,
        private readonly CatalogoRepositorio $catalogo
    ) {
    }

    /** @return array{totales: array, cuentas: array[]} */
    public function auditar(): array
    {
        $cuentas = $this->evaluarCuentas();
        return ['totales' => self::contar($cuentas), 'cuentas' => $cuentas];
    }

    /** Conteos para la pantalla de inicio. */
    public function totales(): array
    {
        return self::contar($this->evaluarCuentas());
    }

    /** Una cuenta con su detalle (incluye los intentos fallidos recientes). */
    public function cuenta(string $usuario): ?array
    {
        foreach ($this->evaluarCuentas() as $cuenta) {
            if ($cuenta['usuario'] === $usuario) {
                $cuenta['intentos_fallidos'] = Numeros::enteros($this->db->consultar(
                    "SELECT TO_CHAR(CAST(FROM_TZ(event_timestamp_utc, '+00:00') AT TIME ZONE SESSIONTIMEZONE AS TIMESTAMP),
                                    'YYYY-MM-DD HH24:MI:SS') AS hora,
                            return_code AS codigo_ora,
                            userhost AS equipo
                       FROM unified_audit_trail
                      WHERE dbusername = :u
                        AND action_name = 'LOGON'
                        AND return_code <> 0
                        AND event_timestamp_utc > SYS_EXTRACT_UTC(SYSTIMESTAMP) - NUMTODSINTERVAL(:dias, 'DAY')
                      ORDER BY event_timestamp_utc DESC
                      FETCH FIRST 20 ROWS ONLY",
                    [':u' => $usuario, ':dias' => self::DIAS_FALLIDOS]
                ), ['codigo_ora']);
                return $cuenta;
            }
        }
        return null;
    }

    private static function contar(array $cuentas): array
    {
        $contar = static fn(string $estado): int =>
            count(array_filter($cuentas, static fn(array $c): bool => $c['estado'] === $estado));
        return [
            'auditadas'     => count($cuentas),
            'cumplen'       => $contar(self::CUMPLE),
            'con_excepcion' => $contar(self::CON_EXCEPCION),
            'no_cumplen'    => $contar(self::NO_CUMPLE),
            'abiertas'      => count(array_filter($cuentas, static fn(array $c): bool => $c['account_status'] === 'OPEN')),
        ];
    }

    private function evaluarCuentas(): array
    {
        $usuarios = Numeros::enteros($this->db->consultar(
            "SELECT u.username AS usuario, u.account_status, u.profile, u.authentication_type, u.common,
                    TO_CHAR(u.created, 'YYYY-MM-DD') AS creada,
                    TO_CHAR(CAST(u.last_login AT TIME ZONE SESSIONTIMEZONE AS TIMESTAMP), 'YYYY-MM-DD HH24:MI:SS') AS ultimo_acceso,
                    CASE WHEN u.last_login >= SYSTIMESTAMP - NUMTODSINTERVAL(:dias, 'DAY') THEN 1 ELSE 0 END AS uso_reciente,
                    TO_CHAR(u.expiry_date, 'YYYY-MM-DD') AS vence_contrasena,
                    TO_CHAR(u.lock_date, 'YYYY-MM-DD') AS bloqueada_desde,
                    u.password_versions,
                    CASE WHEN EXISTS (SELECT 1 FROM dba_users_with_defpwd d WHERE d.username = u.username)
                         THEN 1 ELSE 0 END AS contrasena_defecto
               FROM dba_users u
              WHERE u.oracle_maintained = 'N'
              ORDER BY u.username",
            [':dias' => self::DIAS_INACTIVIDAD]
        ), ['uso_reciente', 'contrasena_defecto']);

        $roles = self::agrupar($this->db->consultar(
            'SELECT grantee AS usuario, granted_role AS valor FROM dba_role_privs
              WHERE grantee IN (' . self::USUARIOS_PROPIOS . ') ORDER BY granted_role'
        ));

        // Mismo criterio que CO-07 (A8.2)
        $privilegiosCriticos = self::agrupar($this->db->consultar(
            "SELECT grantee AS usuario, privilege AS valor FROM dba_sys_privs
              WHERE privilege LIKE '%ANY%' AND grantee IN (" . self::USUARIOS_PROPIOS . ")
             UNION ALL
             SELECT grantee, 'Rol ' || granted_role FROM dba_role_privs
              WHERE granted_role = 'DBA' AND grantee IN (" . self::USUARIOS_PROPIOS . ")
             UNION ALL
             SELECT username,
                    'Administrativo: ' || RTRIM(DECODE(sysdba, 'TRUE', 'SYSDBA ') || DECODE(sysoper, 'TRUE', 'SYSOPER ') ||
                                               DECODE(sysbackup, 'TRUE', 'SYSBACKUP ') || DECODE(sysdg, 'TRUE', 'SYSDG ') ||
                                               DECODE(syskm, 'TRUE', 'SYSKM '))
               FROM v\$pwfile_users
              WHERE username IN (" . self::USUARIOS_PROPIOS . ")"
        ));

        // Mismo criterio que CO-05 (A5.18)
        $privilegiosDirectos = self::agrupar($this->db->consultar(
            "SELECT grantee AS usuario, privilege || ' ON ' || owner || '.' || table_name AS valor
               FROM dba_tab_privs
              WHERE owner = 'AUDINC_DEMO' AND grantee IN (" . self::USUARIOS_PROPIOS . ')'
        ));

        $perfiles = $this->parametrosPerfiles();
        $politicas = $this->db->consultar(
            'SELECT policy_name, enabled_option, entity_name, success, failure FROM audit_unified_enabled_policies'
        );
        $fallidos = array_column(Numeros::enteros($this->db->consultar(
            "SELECT dbusername AS usuario, COUNT(*) AS total
               FROM unified_audit_trail
              WHERE action_name = 'LOGON'
                AND return_code <> 0
                AND event_timestamp_utc > SYS_EXTRACT_UTC(SYSTIMESTAMP) - NUMTODSINTERVAL(:dias, 'DAY')
              GROUP BY dbusername",
            [':dias' => self::DIAS_FALLIDOS]
        ), ['total']), 'total', 'usuario');
        $excepciones = $this->catalogo->excepcionesVigentes();

        $cuentas = [];
        foreach ($usuarios as $u) {
            $nombre = $u['usuario'];
            $u['tipo']   = self::tipo($u);
            $u['roles']  = $roles[$nombre] ?? [];
            $u['privilegios_criticos'] = $privilegiosCriticos[$nombre] ?? [];
            $u['privilegios_directos'] = $privilegiosDirectos[$nombre] ?? [];
            $u['parametros_perfil']    = $perfiles[$u['profile']] ?? [];
            $u['politicas_auditoria']  = self::politicasQueAplican($politicas, $nombre, $u['roles']);
            $u['fallidos_30_dias']     = $fallidos[$nombre] ?? 0;

            $requisitos = $this->requisitos($u);
            // Una excepción vigente del control sobre esta cuenta convierte el incumplimiento en "Exceptuado"
            foreach ($requisitos as &$r) {
                if ($r['estado'] === self::R_NO_CUMPLE && $r['co'] !== null && isset($excepciones[$r['co']][$nombre])) {
                    $r['estado'] = self::R_EXCEPTUADO;
                    $r['detalle'] .= ' · Exceptuado: excepción vigente de ' . $r['co'] . ' sobre la cuenta.';
                }
            }
            unset($r);

            $estados = array_column($requisitos, 'estado');
            $u['requisitos'] = $requisitos;
            $u['aplicables'] = count(array_filter($estados, static fn(string $e): bool => $e !== self::R_NO_APLICA));
            $u['cumplidos']  = count(array_filter($estados, static fn(string $e): bool => $e === self::R_CUMPLE));
            $u['estado'] = match (true) {
                in_array(self::R_NO_CUMPLE, $estados, true)  => self::NO_CUMPLE,
                in_array(self::R_EXCEPTUADO, $estados, true) => self::CON_EXCEPCION,
                default                                      => self::CUMPLE,
            };
            $cuentas[] = $u;
        }
        return $cuentas;
    }

    private function requisitos(array $u): array
    {
        $conContrasena = $u['authentication_type'] === 'PASSWORD';
        $abierta = $u['account_status'] === 'OPEN';
        // Los controles de autenticación (CO-03, CO-04, CO-09) solo revisan cuentas que pueden iniciar sesión
        $motivoNoAplica = !$conContrasena
            ? 'Cuenta sin contraseña (' . $u['authentication_type'] . '): no puede iniciar sesión directamente.'
            : ($abierta ? null : "Cuenta {$u['account_status']}: no puede iniciar sesión.");

        $req = [];

        // A8.5 · CO-09
        $req[] = self::requisito('perfil', 'A8.5', 'CO-09', 'Perfil seguro asignado',
            'Perfil AUDINC_SEGURO (personas) o AUDINC_SERVICIO (aplicaciones)',
            $motivoNoAplica ?? (in_array($u['profile'], self::PERFILES_SEGUROS, true)
                ? [true, "Perfil {$u['profile']}."]
                : [false, "Perfil {$u['profile']}: no aplica bloqueo por intentos ni complejidad de AUDINC."]));

        // A5.17 · política de contraseñas del perfil (se exceptúa junto con CO-09: es el mismo perfil)
        $req[] = self::requisito('politica', 'A5.17', 'CO-09', 'Política de contraseñas del perfil',
            'Bloqueo tras ≤ ' . self::MAX_INTENTOS . ' intentos, función de complejidad, sin reutilización y vigencia ≤ '
                . self::MAX_VIDA_DIAS . ' días (cuentas de servicio: rotación manual)',
            $motivoNoAplica ?? self::evaluarPolitica($u['profile'], $u['parametros_perfil']));

        // A5.17 · CO-04
        $req[] = self::requisito('contrasena', 'A5.17', 'CO-04', 'Sin contraseña por defecto ni hash 10G',
            'No figura en DBA_USERS_WITH_DEFPWD y PASSWORD_VERSIONS sin 10G',
            $motivoNoAplica ?? (function () use ($u): array {
                $fallas = [];
                if ($u['contrasena_defecto']) {
                    $fallas[] = 'usa una contraseña por defecto de Oracle';
                }
                if (str_contains((string) $u['password_versions'], '10G')) {
                    $fallas[] = 'conserva el hash débil 10G';
                }
                return $fallas === []
                    ? [true, 'Hashes: ' . trim((string) $u['password_versions']) . '.']
                    : [false, 'La cuenta ' . implode(' y ', $fallas) . '.'];
            })());

        // A5.16 · CO-03
        $req[] = self::requisito('uso', 'A5.16', 'CO-03', 'Cuenta en uso',
            'Cuenta abierta con inicio de sesión en los últimos ' . self::DIAS_INACTIVIDAD . ' días',
            $motivoNoAplica ?? ($u['uso_reciente']
                ? [true, "Último acceso: {$u['ultimo_acceso']}."]
                : [false, $u['ultimo_acceso']
                    ? "Sin uso desde {$u['ultimo_acceso']}: bloquearla o eliminarla."
                    : 'Nunca ha iniciado sesión en XEPDB1: bloquearla o eliminarla.']));

        // A8.2 · CO-07
        $req[] = self::requisito('privilegios', 'A8.2', 'CO-07', 'Sin privilegios críticos',
            'Sin rol DBA, privilegios ANY ni administrativos (SYSDBA, SYSBACKUP…)',
            $u['privilegios_criticos'] === []
                ? [true, 'Ningún privilegio crítico.']
                : [false, 'Tiene: ' . implode(', ', $u['privilegios_criticos']) . '.']);

        // A5.18 · CO-05
        $req[] = self::requisito('roles', 'A5.18', 'CO-05', 'Acceso a datos solo por roles',
            'Sin privilegios de objeto sobre AUDINC_DEMO otorgados directamente',
            $u['privilegios_directos'] === []
                ? [true, $u['roles'] === [] ? 'Sin privilegios directos ni roles.' : 'Acceso por roles: ' . implode(', ', $u['roles']) . '.']
                : [false, 'Privilegios directos: ' . implode(', ', $u['privilegios_directos']) . '.']);

        // A8.15 · auditoría unificada (sin excepciones: es transversal)
        $nombresPoliticas = array_column($u['politicas_auditoria'], 'policy_name');
        $tieneFallidos = in_array('ORA_LOGON_FAILURES', $nombresPoliticas, true);
        $tieneAudinc = (bool) array_filter($nombresPoliticas, static fn(string $p): bool => str_starts_with($p, 'AUDINC'));
        $req[] = self::requisito('auditoria', 'A8.15', null, 'Actividad auditada',
            'Cubierta por ORA_LOGON_FAILURES y por las políticas AUDINC_*',
            $tieneFallidos && $tieneAudinc
                ? [true, 'Políticas: ' . implode(', ', $nombresPoliticas) . '.']
                : [false, 'Falta: ' . implode(' y ', array_filter([
                    $tieneFallidos ? null : 'ORA_LOGON_FAILURES',
                    $tieneAudinc ? null : 'una política AUDINC_*',
                ])) . '.']);

        return $req;
    }

    /** @param string|array{0: bool, 1: string} $resultado texto = No aplica */
    private static function requisito(string $id, string $control, ?string $co, string $titulo, string $criterio, string|array $resultado): array
    {
        [$estado, $detalle] = is_string($resultado)
            ? [self::R_NO_APLICA, $resultado]
            : [$resultado[0] ? self::R_CUMPLE : self::R_NO_CUMPLE, $resultado[1]];
        return compact('id', 'control', 'co', 'titulo', 'criterio', 'estado', 'detalle');
    }

    /** @return array{0: bool, 1: string} */
    private static function evaluarPolitica(string $perfil, array $p): array
    {
        $fallas = [];
        $intentos = $p['FAILED_LOGIN_ATTEMPTS'] ?? 'UNLIMITED';
        if (!is_numeric($intentos) || (float) $intentos > self::MAX_INTENTOS) {
            $fallas[] = "intentos fallidos permitidos: {$intentos}";
        }
        if (($p['PASSWORD_VERIFY_FUNCTION'] ?? 'NULL') === 'NULL') {
            $fallas[] = 'sin función de complejidad';
        }
        if (($p['PASSWORD_REUSE_MAX'] ?? 'UNLIMITED') === 'UNLIMITED' && ($p['PASSWORD_REUSE_TIME'] ?? 'UNLIMITED') === 'UNLIMITED') {
            $fallas[] = 'permite reutilizar contraseñas';
        }
        $vida = $p['PASSWORD_LIFE_TIME'] ?? 'UNLIMITED';
        $vidaOk = is_numeric($vida) ? (float) $vida <= self::MAX_VIDA_DIAS : $perfil === self::PERFIL_SERVICIO;
        if (!$vidaOk) {
            $fallas[] = "vigencia de la contraseña: {$vida}";
        }
        return $fallas === []
            ? [true, "Perfil {$perfil}: bloqueo tras {$intentos} intentos, complejidad " . $p['PASSWORD_VERIFY_FUNCTION']
                . ", vigencia {$vida}" . (is_numeric($vida) ? ' días' : ' (cuenta de servicio, rotación manual)') . '.']
            : [false, "Perfil {$perfil}: " . implode('; ', $fallas) . '.'];
    }

    /** Parámetros por perfil, resolviendo los valores DEFAULT con el perfil DEFAULT. */
    private function parametrosPerfiles(): array
    {
        $binds = [];
        foreach (self::PARAMETROS_PERFIL as $i => $nombre) {
            $binds[":p{$i}"] = $nombre;
        }
        $perfiles = [];
        foreach ($this->db->consultar(
            'SELECT profile, resource_name, limit FROM dba_profiles
              WHERE resource_name IN (' . implode(', ', array_keys($binds)) . ')',
            $binds
        ) as $fila) {
            $perfiles[$fila['profile']][$fila['resource_name']] = $fila['limit'];
        }
        foreach ($perfiles as $perfil => &$parametros) {
            foreach ($parametros as $nombre => &$valor) {
                if ($valor === 'DEFAULT') {
                    $valor = $perfiles['DEFAULT'][$nombre] ?? 'DEFAULT';
                }
                // Los días fraccionarios (1/24 = 1 hora) se muestran legibles
                // (el separador decimal depende de NLS: ".0416" o ",0416")
                if (preg_match('/^[.,]\d+$/', (string) $valor)) {
                    $valor = '0.' . substr($valor, 1);
                }
            }
            unset($valor);
        }
        unset($parametros);
        return $perfiles;
    }

    /** Políticas de auditoría habilitadas que alcanzan a la cuenta (por usuario, por rol o para todos). */
    private static function politicasQueAplican(array $politicas, string $usuario, array $roles): array
    {
        $excluida = [];
        foreach ($politicas as $p) {
            if ($p['enabled_option'] === 'EXCEPT USER' && $p['entity_name'] === $usuario) {
                $excluida[$p['policy_name']] = true;
            }
        }
        $aplican = [];
        foreach ($politicas as $p) {
            $alcanza = match ($p['enabled_option']) {
                'BY USER'         => in_array($p['entity_name'], ['ALL USERS', $usuario], true),
                'BY GRANTED ROLE' => in_array($p['entity_name'], $roles, true),
                'EXCEPT USER'     => $p['entity_name'] !== $usuario,
                default           => false,
            };
            if ($alcanza && !isset($excluida[$p['policy_name']]) && !isset($aplican[$p['policy_name']])) {
                $aplican[$p['policy_name']] = [
                    'policy_name' => $p['policy_name'],
                    'exitosos'    => $p['success'] === 'YES',
                    'fallidos'    => $p['failure'] === 'YES',
                ];
            }
        }
        ksort($aplican);
        return array_values($aplican);
    }

    private static function tipo(array $u): string
    {
        return match (true) {
            $u['authentication_type'] === 'NONE' => 'Esquema (sin contraseña)',
            $u['common'] === 'YES'               => 'Usuario común (CDB)',
            $u['profile'] === self::PERFIL_SERVICIO => 'Cuenta de servicio',
            default                              => 'Usuario',
        };
    }

    /** @return array<string, string[]> usuario => valores */
    private static function agrupar(array $filas): array
    {
        $resultado = [];
        foreach ($filas as $fila) {
            $resultado[$fila['usuario']][] = $fila['valor'];
        }
        return $resultado;
    }
}
