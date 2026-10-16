-- =====================================================================
-- PT-17 · Funcional · A8.11 Data Redaction · CO-11
-- Procedimiento: JUAN (rol VENDEDOR, sin EXEMPT REDACTION POLICY) consulta
--   CLIENTES; LUIS (rol SUPERVISOR) hace la misma consulta como contraste.
-- Resultado esperado: JUAN ve cédula, email, teléfono y dirección
--   enmascarados; LUIS los ve completos.
-- =====================================================================
SET ECHO ON LINESIZE 160 PAGESIZE 50
COLUMN cedula    FORMAT A12
COLUMN email     FORMAT A28
COLUMN telefono  FORMAT A10
COLUMN direccion FORMAT A24
SPOOL ../../evidencias/salidas/PT-17_redaction.txt

CONNECT juan/"&pwd_demo"@&conexion
SELECT USER AS usuario, SYS_CONTEXT('SYS_SESSION_ROLES', 'SUPERVISOR') AS es_supervisor FROM dual;
SELECT id_cliente, cedula, email, telefono, direccion
FROM   audinc_demo.clientes
WHERE  id_cliente <= 3
ORDER  BY id_cliente;

CONNECT luis/"&pwd_demo"@&conexion
SELECT USER AS usuario, SYS_CONTEXT('SYS_SESSION_ROLES', 'SUPERVISOR') AS es_supervisor FROM dual;
SELECT id_cliente, cedula, email, telefono, direccion
FROM   audinc_demo.clientes
WHERE  id_cliente <= 3
ORDER  BY id_cliente;

SPOOL OFF
SET ECHO OFF
