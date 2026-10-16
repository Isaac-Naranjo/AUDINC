-- =====================================================================
-- AUDINC · 00_pruebas_funcionales.sql                     (PHVA: Verificar)
-- Ejecuta PT-17 … PT-21 conectándose como cada usuario de prueba.
-- Ejecutar DESDE scripts/02_verificacion/ (las salidas se guardan en
-- ../../evidencias/salidas/):
--     sqlplus /nolog @00_pruebas_funcionales.sql
-- Requiere acceso local como SYSDBA (PT-19 desbloquea a PEDRO al terminar).
-- Las pruebas de consulta PT-01 … PT-16 las ejecuta el evaluador AUDINC.
-- =====================================================================
SET VERIFY OFF
ACCEPT pwd_demo CHAR PROMPT 'Contrasena de los usuarios de prueba: ' HIDE

DEFINE conexion = //localhost:1521/XEPDB1

@@PT-19_bloqueo_intentos.sql
@@PT-17_redaction.sql
@@PT-18_vpd.sql
@@PT-20_privilegios.sql
@@PT-21_auditoria.sql

UNDEFINE pwd_demo
PROMPT === Pruebas funcionales completadas. Salidas en evidencias/salidas/ ===
