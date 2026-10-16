-- =====================================================================
-- PT-21 · Funcional · A8.15 Registro / A5.33 Protección de registros · CO-14
-- Procedimiento: ANA (rol AUDITOR -> AUDIT_VIEWER) consulta el rastro de
--   auditoría unificada generado por PT-17 … PT-20.
-- Resultado esperado: aparecen las consultas a CLIENTES/VENTAS, el INSERT
--   rechazado, los intentos fallidos de PEDRO y el desbloqueo; ANA puede
--   leer el rastro pero no tiene AUDIT_ADMIN para borrarlo.
-- =====================================================================
SET ECHO ON LINESIZE 200 PAGESIZE 100
WHENEVER SQLERROR CONTINUE
COLUMN hora        FORMAT A19
COLUMN usuario     FORMAT A10
COLUMN accion      FORMAT A16
COLUMN objeto      FORMAT A12
COLUMN politicas   FORMAT A40
SPOOL ../../evidencias/salidas/PT-21_auditoria.txt

-- Asegura que los registros en cola estén escritos
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = XEPDB1;
EXEC DBMS_AUDIT_MGMT.FLUSH_UNIFIED_AUDIT_TRAIL

CONNECT ana/"&pwd_demo"@&conexion
SELECT * FROM session_roles;

SELECT TO_CHAR(event_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS hora,
       dbusername        AS usuario,
       action_name       AS accion,
       object_name       AS objeto,
       return_code,
       unified_audit_policies AS politicas
FROM   unified_audit_trail
WHERE  event_timestamp > SYSTIMESTAMP - INTERVAL '30' MINUTE
AND    (unified_audit_policies LIKE '%AUDINC%' OR unified_audit_policies LIKE '%ORA_LOGON_FAILURES%')
ORDER  BY event_timestamp;

-- ANA no puede purgar el rastro (separación de funciones, A5.33): ORA-01031 / PLS-00201
EXEC DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED, FALSE)

SPOOL OFF
SET ECHO OFF
