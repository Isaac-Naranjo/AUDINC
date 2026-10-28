-- =====================================================================
-- A5.17 Información de autenticación · A8.5 Autenticación segura (PHVA: Hacer)
-- Riesgo: R-CONF-02 · Tarea: T-03 · Verificación: CO-09 / PT-19
-- Pizarra: "Perfiles -> aspectos de seguridad adicionales: idle time"
-- =====================================================================

-- Personas
CREATE PROFILE audinc_seguro LIMIT
  FAILED_LOGIN_ATTEMPTS    3                 -- bloqueo tras 3 intentos fallidos
  PASSWORD_LOCK_TIME       1/24              -- ... durante 1 hora
  PASSWORD_LIFE_TIME       90                -- cambio obligatorio cada 90 días
  PASSWORD_GRACE_TIME      7
  PASSWORD_REUSE_TIME      365               -- no reutilizar en un año
  PASSWORD_REUSE_MAX       5                 -- ... ni las últimas 5
  PASSWORD_VERIFY_FUNCTION ora12c_strong_verify_function
  IDLE_TIME                15                -- cierra sesiones inactivas (min)
  SESSIONS_PER_USER        3;

-- Cuentas de servicio (aplicación). La contraseña no expira sola para no
-- detener el evaluador; se rota manualmente y queda auditado (A8.15).
CREATE PROFILE audinc_servicio LIMIT
  FAILED_LOGIN_ATTEMPTS    5
  PASSWORD_LOCK_TIME       1/24
  PASSWORD_LIFE_TIME       UNLIMITED
  PASSWORD_REUSE_TIME      365
  PASSWORD_REUSE_MAX       5
  PASSWORD_VERIFY_FUNCTION ora12c_strong_verify_function
  IDLE_TIME                30
  SESSIONS_PER_USER        10;

ALTER USER juan       PROFILE audinc_seguro;
ALTER USER pedro      PROFILE audinc_seguro;
ALTER USER isaac      PROFILE audinc_seguro;
ALTER USER luis       PROFILE audinc_seguro;
ALTER USER temporal   PROFILE audinc_seguro;
ALTER USER audinc_app PROFILE audinc_servicio;
