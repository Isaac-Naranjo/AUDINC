-- =====================================================================
-- A5.16 Gestión de identidad                                  (PHVA: Hacer)
-- Riesgo: R-CONF-02 · Tarea: T-01 · Verificación: CO-03
-- Las cuentas sin uso se bloquean y su contraseña se expira (baja lógica):
-- se conserva la identidad para la trazabilidad de auditoría.
-- =====================================================================
ALTER USER temporal ACCOUNT LOCK PASSWORD EXPIRE;
