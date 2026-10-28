-- =====================================================================
-- AC-03 · Acción correctiva: cuenta nominal del auditor  (PHVA: Actuar)
-- Controles: A5.16 (gestión de identidades) · A8.15 (trazabilidad)
--
-- La cuenta de prueba ANA (rol AUDITOR) se reemplaza por ISAAC, la cuenta
-- nominal del responsable de la auditoría: cada evaluación y cada evento
-- del rastro queda a nombre de una persona real e identificable.
-- Oracle no permite renombrar usuarios: se crea ISAAC con el mismo rol y
-- perfil, y se elimina ANA (no es dueña de objetos).
--
-- El histórico NO se reescribe: las evaluaciones y los eventos de auditoría
-- anteriores siguen a nombre de ANA (la evidencia es inalterable).
-- Ejecutar como SYS AS SYSDBA:  sqlplus / as sysdba @AC-03_cuenta_auditor_isaac.sql
-- =====================================================================
SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ALTER SESSION SET CONTAINER = XEPDB1;

ACCEPT pwd_isaac CHAR PROMPT 'Contrasena para ISAAC: ' HIDE

-- Igual que en el setup: se crea y luego se asigna el perfil seguro (A5.17 / A8.5)
CREATE USER isaac IDENTIFIED BY "&pwd_isaac" DEFAULT TABLESPACE users;
GRANT auditor TO isaac;
ALTER USER isaac PROFILE audinc_seguro;

-- Datos de prueba y catálogo que nombraban a la cuenta anterior
UPDATE audinc_demo.empleados
   SET nombre = 'Isaac Naranjo', usuario_bd = 'ISAAC'
 WHERE usuario_bd = 'ANA';

UPDATE audinc_owner.prueba
   SET procedimiento      = REPLACE(procedimiento, 'ANA', 'ISAAC'),
       resultado_esperado = REPLACE(resultado_esperado, 'ANA', 'ISAAC')
 WHERE id_prueba = 'PT-22';

COMMIT;

DROP USER ana;

UNDEFINE pwd_isaac

-- Evidencia
SELECT username, account_status, profile FROM dba_users WHERE username IN ('ANA', 'ISAAC');
SELECT grantee, granted_role FROM dba_role_privs WHERE granted_role = 'AUDITOR';
