-- =====================================================================
-- PT-19 · Funcional · A8.5 Autenticación segura · CO-09
-- Procedimiento: PEDRO inicia sesión correctamente; luego se intenta 3
--   veces con una contraseña incorrecta y una cuarta con la correcta.
-- Resultado esperado: 3 x ORA-01017 y luego ORA-28000 (cuenta bloqueada
--   por FAILED_LOGIN_ATTEMPTS = 3 del perfil AUDINC_SEGURO).
-- Al final SYSDBA desbloquea la cuenta para dejar el entorno listo.
-- =====================================================================
SET ECHO ON
WHENEVER SQLERROR CONTINUE
SPOOL ../../evidencias/salidas/PT-19_bloqueo_intentos.txt

CONNECT pedro/"&pwd_demo"@&conexion
SELECT USER AS usuario, SYSTIMESTAMP AS hora FROM dual;
DISCONNECT

CONNECT pedro/"Incorrecta_1"@&conexion
CONNECT pedro/"Incorrecta_2"@&conexion
CONNECT pedro/"Incorrecta_3"@&conexion
-- Contraseña correcta, pero la cuenta ya debe estar bloqueada
CONNECT pedro/"&pwd_demo"@&conexion

CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = XEPDB1;
SELECT username, account_status, profile, lock_date FROM dba_users WHERE username = 'PEDRO';
ALTER USER pedro ACCOUNT UNLOCK;
SELECT username, account_status FROM dba_users WHERE username = 'PEDRO';

SPOOL OFF
SET ECHO OFF
