-- =====================================================================
-- AUDINC · 99_limpieza.sql
-- Elimina todo lo creado por el proyecto y deja XEPDB1 como estaba.
-- Ejecutar como SYS AS SYSDBA. Los errores "no existe" se ignoran.
-- =====================================================================
WHENEVER SQLERROR CONTINUE
ALTER SESSION SET CONTAINER = XEPDB1;

-- Controles (01_controles/)
NOAUDIT POLICY audinc_acceso_datos;
NOAUDIT POLICY audinc_gestion_accesos;
NOAUDIT POLICY audinc_evaluaciones;
DROP AUDIT POLICY audinc_acceso_datos;
DROP AUDIT POLICY audinc_gestion_accesos;
DROP AUDIT POLICY audinc_evaluaciones;

-- Restituye los grants originales de Oracle revocados por A8.12
GRANT EXECUTE ON sys.utl_file TO PUBLIC;
GRANT EXECUTE ON sys.utl_http TO PUBLIC;
GRANT EXECUTE ON sys.utl_tcp  TO PUBLIC;
GRANT EXECUTE ON sys.utl_smtp TO PUBLIC;

-- AC-02: PDBADMIN vuelve a su estado original
ALTER USER pdbadmin ACCOUNT UNLOCK;

DROP USER audinc_sec CASCADE;

DROP USER audinc_app   CASCADE;
DROP USER juan         CASCADE;
DROP USER pedro        CASCADE;
DROP USER ana          CASCADE;
DROP USER luis         CASCADE;
DROP USER temporal     CASCADE;
DROP USER audinc_demo  CASCADE;
DROP USER audinc_owner CASCADE;

DROP ROLE audinc_evaluador;
DROP ROLE vendedor;
DROP ROLE supervisor;
DROP ROLE auditor;

-- Perfiles (después de borrar los usuarios que los usan)
DROP PROFILE audinc_seguro   CASCADE;
DROP PROFILE audinc_servicio CASCADE;

PROMPT === Limpieza AUDINC completada ===
