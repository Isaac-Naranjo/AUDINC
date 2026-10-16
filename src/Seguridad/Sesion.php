<?php
declare(strict_types=1);

namespace Audinc\Seguridad;

/**
 * Sesión PHP del usuario autenticado (A8.5).
 * - Cookie HttpOnly + SameSite=Strict (no accesible desde JS ni enviada desde otros sitios).
 * - Expira por inactividad igual que IDLE_TIME del perfil AUDINC_SEGURO, y por duración máxima.
 * - El identificador se regenera al iniciar sesión (evita fijación de sesión).
 */
final class Sesion
{
    private const INACTIVIDAD_MAX = 15 * 60;   // segundos; = IDLE_TIME 15 del perfil AUDINC_SEGURO
    private const DURACION_MAX    = 8 * 3600;

    public static function iniciar(): void
    {
        if (session_status() === PHP_SESSION_ACTIVE) {
            return;
        }
        ini_set('session.use_strict_mode', '1');
        ini_set('session.use_only_cookies', '1');
        ini_set('session.use_trans_sid', '0');
        session_name('AUDINC_SESION');
        session_set_cookie_params([
            'lifetime' => 0,
            'path'     => '/',
            'httponly' => true,
            'samesite' => 'Strict',
            'secure'   => !empty($_SERVER['HTTPS']),
        ]);
        session_start();
    }

    /** Usuario autenticado, o null si no hay sesión o expiró. */
    public static function usuario(): ?string
    {
        $usuario = $_SESSION['usuario'] ?? null;
        if ($usuario === null) {
            return null;
        }
        $ahora = time();
        if ($ahora - ($_SESSION['ultimo'] ?? 0) > self::INACTIVIDAD_MAX
            || $ahora - ($_SESSION['inicio'] ?? 0) > self::DURACION_MAX) {
            self::cerrar();
            return null;
        }
        $_SESSION['ultimo'] = $ahora;
        return $usuario;
    }

    public static function abrir(string $usuario, array $datos = []): void
    {
        session_regenerate_id(true);
        $_SESSION = ['usuario' => $usuario, 'inicio' => time(), 'ultimo' => time()] + $datos;
    }

    public static function dato(string $clave): mixed
    {
        return $_SESSION[$clave] ?? null;
    }

    public static function info(): array
    {
        return [
            'usuario'           => $_SESSION['usuario'] ?? null,
            'inicio'            => isset($_SESSION['inicio']) ? date('Y-m-d H:i:s', $_SESSION['inicio']) : null,
            'expira_inactividad_seg' => self::INACTIVIDAD_MAX,
            'acceso_anterior'   => $_SESSION['acceso_anterior'] ?? null,
        ];
    }

    public static function cerrar(): void
    {
        $_SESSION = [];
        if (session_status() === PHP_SESSION_ACTIVE) {
            $p = session_get_cookie_params();
            setcookie(session_name(), '', [
                'expires'  => time() - 3600,
                'path'     => $p['path'],
                'httponly' => true,
                'samesite' => 'Strict',
            ]);
            session_destroy();
        }
    }
}
