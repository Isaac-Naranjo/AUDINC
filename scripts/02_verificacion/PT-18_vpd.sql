-- =====================================================================
-- PT-18 · Funcional · A8.3 Virtual Private Database · CO-08
-- Procedimiento: JUAN consulta VENTAS e intenta registrar una venta a
--   nombre de PEDRO; LUIS (SUPERVISOR) consulta VENTAS como contraste.
-- Resultado esperado: JUAN solo ve sus ventas; el INSERT ajeno falla con
--   ORA-28115 (violación de la política); LUIS ve las de ambos.
-- =====================================================================
SET ECHO ON LINESIZE 160 PAGESIZE 50
WHENEVER SQLERROR CONTINUE
SPOOL ../../evidencias/salidas/PT-18_vpd.txt

CONNECT juan/"&pwd_demo"@&conexion
SELECT vendedor, COUNT(*) AS ventas, SUM(monto) AS total
FROM   audinc_demo.ventas
GROUP  BY vendedor;

-- Debe fallar: ORA-28115
INSERT INTO audinc_demo.ventas (id_venta, id_cliente, vendedor, monto)
VALUES (999, 1, 'PEDRO', 1000);
ROLLBACK;

CONNECT luis/"&pwd_demo"@&conexion
SELECT vendedor, COUNT(*) AS ventas, SUM(monto) AS total
FROM   audinc_demo.ventas
GROUP  BY vendedor
ORDER  BY vendedor;

SPOOL OFF
SET ECHO OFF
