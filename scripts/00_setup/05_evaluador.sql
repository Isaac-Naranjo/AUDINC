-- =====================================================================
-- AUDINC · 05_evaluador.sql                             (PHVA: Planificar)
-- Cuenta con la que se conecta la aplicación PHP.
-- Mínimo privilegio (A8.2): SELECT solo sobre las vistas del diccionario
-- que usan las consultas de evidencia, lectura del catálogo e inserción
-- de resultados. NO puede modificar las consultas del catálogo, así que
-- no puede alterar qué se evalúa.
-- =====================================================================
CREATE ROLE audinc_evaluador;

-- Vistas del diccionario usadas por CO-01 … CO-16
GRANT SELECT ON sys.dba_users                      TO audinc_evaluador;
GRANT SELECT ON sys.dba_users_with_defpwd          TO audinc_evaluador;
GRANT SELECT ON sys.dba_tab_columns                TO audinc_evaluador;
GRANT SELECT ON sys.dba_col_comments               TO audinc_evaluador;
GRANT SELECT ON sys.dba_tab_privs                  TO audinc_evaluador;
GRANT SELECT ON sys.dba_sys_privs                  TO audinc_evaluador;
GRANT SELECT ON sys.dba_role_privs                 TO audinc_evaluador;
GRANT SELECT ON sys.dba_policies                   TO audinc_evaluador;
GRANT SELECT ON sys.dba_profiles                   TO audinc_evaluador;
GRANT SELECT ON sys.dba_recyclebin                 TO audinc_evaluador;
GRANT SELECT ON sys.dba_tablespaces                TO audinc_evaluador;
GRANT SELECT ON sys.redaction_columns              TO audinc_evaluador;
GRANT SELECT ON sys.redaction_policies             TO audinc_evaluador;
GRANT SELECT ON sys.audit_unified_enabled_policies TO audinc_evaluador;
GRANT SELECT ON sys.v_$parameter                   TO audinc_evaluador;
GRANT SELECT ON sys.v_$rman_configuration          TO audinc_evaluador;
GRANT SELECT ON sys.v_$backup_piece                TO audinc_evaluador;
GRANT SELECT ON sys.v_$session_connect_info        TO audinc_evaluador;
GRANT SELECT ON sys.v_$encryption_wallet           TO audinc_evaluador;
GRANT SELECT ON sys.v_$version                     TO audinc_evaluador;
GRANT SELECT ON sys.v_$database                    TO audinc_evaluador;
GRANT SELECT ON sys.v_$option                      TO audinc_evaluador;
GRANT SELECT ON sys.v_$pwfile_users                TO audinc_evaluador;

-- Lectura del rastro de auditoría (PT-21)
GRANT audit_viewer TO audinc_evaluador;

-- Catálogo: solo lectura
GRANT SELECT ON audinc_owner.riesgo             TO audinc_evaluador;
GRANT SELECT ON audinc_owner.control_iso        TO audinc_evaluador;
GRANT SELECT ON audinc_owner.tarea              TO audinc_evaluador;
GRANT SELECT ON audinc_owner.tarea_riesgo       TO audinc_evaluador;
GRANT SELECT ON audinc_owner.tarea_control      TO audinc_evaluador;
GRANT SELECT ON audinc_owner.control_observable TO audinc_evaluador;
GRANT SELECT ON audinc_owner.prueba             TO audinc_evaluador;
GRANT SELECT ON audinc_owner.v_matriz           TO audinc_evaluador;
GRANT SELECT ON audinc_owner.excepcion          TO audinc_evaluador;

-- Resultados: lectura e inserción (sin UPDATE/DELETE: la evidencia no se reescribe)
GRANT SELECT, INSERT ON audinc_owner.evaluacion         TO audinc_evaluador;
GRANT SELECT, INSERT ON audinc_owner.evaluacion_detalle TO audinc_evaluador;

CREATE USER audinc_app IDENTIFIED BY "&pwd_app" DEFAULT TABLESPACE users;
GRANT CREATE SESSION   TO audinc_app;
GRANT audinc_evaluador TO audinc_app;
