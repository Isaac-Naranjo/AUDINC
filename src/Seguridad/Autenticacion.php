<?php
declare(strict_types=1);

namespace Audinc\Seguridad;

/**
 * Autenticación delegada a Oracle (A5.16 / A5.17 / A8.5).
 * La aplicación NO guarda contraseñas: intenta abrir una sesión en Oracle con las
 * credenciales del usuario. Así aplican automáticamente los controles del perfil
 * (bloqueo tras 3 intentos, expiración, complejidad) y ORA_LOGON_FAILURES registra
 * cada intento fallido. Solo se admite a quien tenga el rol AUDITOR.
 */
final class Autenticacion
{
    public const ROL_REQUERIDO = 'AUDITOR';

    private const ORA_CONTRASENA_EXPIRADA = 28001;

    public function __construct(private readonly array $configDb)
    {
    }

    /** @return string usuario normalizado (mayúsculas) */
    public function validar(string $usuario, string $contrasena): string
    {
        $usuario = strtoupper(trim($usuario));
        if (!preg_match('/^[A-Z][A-Z0-9_$#]{0,127}$/', $usuario)
            || $contrasena === ''
            || strlen($contrasena) > 128) {
            throw new AutenticacionException(401, 'Usuario o contraseña inválidos, o cuenta bloqueada');
        }

        // oci_new_connect: conexión nueva, nunca reutiliza la de AUDINC_APP
        $conexion = @oci_new_connect(
            $usuario,
            $contrasena,
            $this->configDb['dsn'],
            $this->configDb['charset'] ?? 'AL32UTF8'
        );
        if ($conexion === false) {
            $codigo = (int) (oci_error()['code'] ?? 0);
            error_log("AUDINC: inicio de sesión fallido de {$usuario} (ORA-{$codigo})");
            if ($codigo === self::ORA_CONTRASENA_EXPIRADA) {
                throw new AutenticacionException(403, 'La contraseña expiró: cámbiela desde SQL Developer o SQL*Plus');
            }
            // Mismo mensaje para usuario inexistente, contraseña errónea o cuenta bloqueada
            throw new AutenticacionException(401, 'Usuario o contraseña inválidos, o cuenta bloqueada');
        }

        try {
            $sentencia = oci_parse($conexion, 'SELECT COUNT(*) FROM session_roles WHERE role = :rol');
            $rol = self::ROL_REQUERIDO;
            oci_bind_by_name($sentencia, ':rol', $rol);
            oci_execute($sentencia);
            $tieneRol = (int) oci_fetch_row($sentencia)[0] > 0;
            oci_free_statement($sentencia);
        } finally {
            oci_close($conexion);
        }

        if (!$tieneRol) {
            error_log("AUDINC: {$usuario} se autenticó pero no tiene el rol " . self::ROL_REQUERIDO);
            throw new AutenticacionException(403, 'Acceso restringido a usuarios con el rol ' . self::ROL_REQUERIDO);
        }
        return $usuario;
    }
}
