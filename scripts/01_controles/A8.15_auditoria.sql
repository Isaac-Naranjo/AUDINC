-- =====================================================================
-- A8.15 Registro (logging)                                    (PHVA: Hacer)
-- Riesgo: R-CONF-05 · Tareas: T-07, T-11 · Verificación: CO-14 / PT-21
-- Auditoría unificada (la instancia está en modo mixto; las políticas
-- unificadas funcionan igual). Complementa ORA_LOGON_FAILURES y
-- audit_sys_operations = TRUE, que ya estaban activas.
-- =====================================================================

-- ¿Quién consultó o modificó datos personales y comerciales?
CREATE AUDIT POLICY audinc_acceso_datos
  ACTIONS SELECT ON audinc_demo.clientes,
          SELECT ON audinc_demo.empleados,
          SELECT ON audinc_demo.ventas,
          INSERT ON audinc_demo.ventas,
          UPDATE ON audinc_demo.ventas,
          DELETE ON audinc_demo.ventas;

-- ¿Quién cambió identidades, privilegios o perfiles, o usó privilegios de exención?
CREATE AUDIT POLICY audinc_gestion_accesos
  PRIVILEGES SELECT ANY TABLE, EXEMPT REDACTION POLICY, EXEMPT ACCESS POLICY
  ACTIONS CREATE USER, ALTER USER, DROP USER,
          CREATE ROLE, ALTER ROLE, DROP ROLE,
          GRANT, REVOKE,
          CREATE PROFILE, ALTER PROFILE, DROP PROFILE;

-- ¿Quién lanzó cada evaluación desde la aplicación? (CLIENT_IDENTIFIER = usuario final)
CREATE AUDIT POLICY audinc_evaluaciones
  ACTIONS INSERT ON audinc_owner.evaluacion;

AUDIT POLICY audinc_acceso_datos;
AUDIT POLICY audinc_gestion_accesos;
AUDIT POLICY audinc_evaluaciones;
