-- =====================================================================
-- AUDINC · 00_aplicar_controles.sql                          (PHVA: Hacer)
-- Aplica los controles internos de la base (reversibles con 99_limpieza.sql).
-- Ejecutar como SYS AS SYSDBA:   sqlplus / as sysdba @00_aplicar_controles.sql
--
-- No incluye los controles que requieren cambios fuera de la base o reinicio:
--   A8.20_cifrado_red.md   (sqlnet.ora)
--   A8.24_tde.sql          (keystore TDE, reinicio de la instancia)
--   A8.13_respaldos.rman   (depende de TDE)
-- =====================================================================
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

ALTER SESSION SET CONTAINER = XEPDB1;

PROMPT === A5.12  Clasificación de columnas sensibles ===
@@A5.12_clasificacion.sql
PROMPT === A5.15 / A5.18 / A8.2  Privilegios ===
@@A5.15_A5.18_A8.2_privilegios.sql
PROMPT === A5.16  Gestión de cuentas ===
@@A5.16_cuentas.sql
PROMPT === A5.17 / A8.5  Perfiles de autenticación ===
@@A5.17_A8.5_perfiles.sql
PROMPT === A8.3  Virtual Private Database ===
@@A8.3_vpd.sql
PROMPT === A8.10  Eliminación segura ===
@@A8.10_eliminacion.sql
PROMPT === A8.11  Data Redaction ===
@@A8.11_redaction.sql
PROMPT === A8.12  Prevención de fuga de datos ===
@@A8.12_fuga_datos.sql
PROMPT === A8.15  Auditoría unificada ===
@@A8.15_auditoria.sql

PROMPT === Controles internos aplicados ===
