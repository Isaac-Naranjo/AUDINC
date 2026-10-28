-- =====================================================================
-- AUDINC · 00_instalar.sql                              (PHVA: Planificar)
-- Script maestro del setup. Ejecutar como SYS AS SYSDBA:
--   sqlplus / as sysdba @00_instalar.sql
-- Las contraseñas se piden en tiempo de ejecución (no quedan en el repo).
-- Si se quiere reinstalar, ejecutar antes scripts/99_limpieza.sql
-- =====================================================================
SET VERIFY OFF
SET DEFINE ON
SET FEEDBACK ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

ALTER SESSION SET CONTAINER = XEPDB1;

ACCEPT pwd_app  CHAR PROMPT 'Contrasena para AUDINC_APP (cuenta del evaluador PHP): ' HIDE
ACCEPT pwd_demo CHAR PROMPT 'Contrasena para usuarios de prueba (JUAN, PEDRO, ISAAC, LUIS, TEMPORAL): ' HIDE

PROMPT === 01. Esquema de prueba AUDINC_DEMO ===
@@01_esquema_demo.sql
PROMPT === 02. Roles, usuarios y brechas de linea base ===
@@02_roles_usuarios.sql
PROMPT === 03. Catalogo del evaluador (AUDINC_OWNER) ===
@@03_catalogo.sql
PROMPT === 04. Datos del catalogo ===
@@04_catalogo_datos.sql
PROMPT === 05. Cuenta del evaluador (AUDINC_APP) ===
@@05_evaluador.sql

UNDEFINE pwd_app
UNDEFINE pwd_demo
PROMPT === Setup AUDINC completado ===
