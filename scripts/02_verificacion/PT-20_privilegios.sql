-- =====================================================================
-- PT-20 · Funcional · A5.15 / A5.18 / A8.2 Privilegios · CO-02, CO-05, CO-07
-- Procedimiento: JUAN intenta leer EMPLEADOS (antes tenía grant directo);
--   ANA (AUDITOR) intenta leer CLIENTES (antes era legible por PUBLIC);
--   LUIS intenta leer una tabla fuera de su rol (antes: SELECT ANY TABLE).
-- Resultado esperado: ORA-00942 en los tres casos.
-- =====================================================================
SET ECHO ON
WHENEVER SQLERROR CONTINUE
SPOOL ../../evidencias/salidas/PT-20_privilegios.txt

CONNECT juan/"&pwd_demo"@&conexion
SELECT nombre, salario FROM audinc_demo.empleados;

CONNECT ana/"&pwd_demo"@&conexion
SELECT nombre, cedula FROM audinc_demo.clientes;

CONNECT luis/"&pwd_demo"@&conexion
SELECT COUNT(*) FROM audinc_owner.evaluacion;
SELECT * FROM session_roles;

SPOOL OFF
SET ECHO OFF
