-- =====================================================================
-- A8.24 Uso de criptografía (complementario) — TDE         (PHVA: Hacer)
-- Riesgo: R-CONF-03 · Tarea: T-04 · Verificación: CO-16
--
-- !!! LEER ANTES DE EJECUTAR !!!
-- Aprobado el 2026-10-28: BackupGuard ya fue presentado y no genera más
-- respaldos.
--  * Reinicia la instancia (SHUTDOWN / STARTUP): afecta unos segundos a
--    todas las PDB (XEPDB1, BANCO); se reabren solas (estado guardado).
--  * Crea un keystore (wallet). SI EL KEYSTORE SE PIERDE, LOS DATOS DEL
--    TABLESPACE CIFRADO SON IRRECUPERABLES: respaldar la carpeta del wallet
--    y guardar su contraseña fuera del repositorio
--    (credenciales.local.sql, ignorado por git).
--  * Solo se cifra un tablespace nuevo (AUDINC_DATOS) con los datos de
--    AUDINC_DEMO; USERS, FARMACIA y los demás tablespaces no se tocan.
--
-- Antes de ejecutar, crear la carpeta del keystore:
--   mkdir C:\app\isaac\product\21c\admin\XE\wallet\tde
-- Ejecutar como SYS AS SYSDBA conectado al CDB raíz:
--   sqlplus / as sysdba @A8.24_tde.sql
-- Después: respaldar la carpeta del wallet (ver el final del script).
-- =====================================================================
SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ACCEPT pwd_keystore CHAR PROMPT 'Contrasena del keystore TDE (guardela fuera del repo): ' HIDE

-- Paso 1 · Ubicación del keystore (parámetro estático: requiere reinicio)
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER SYSTEM SET WALLET_ROOT = 'C:\app\isaac\product\21c\admin\XE\wallet' SCOPE = SPFILE;
SHUTDOWN IMMEDIATE
STARTUP
-- Las PDB con estado guardado (XEPDB1, BANCO) se abren solas; se verifica
SELECT name, open_mode FROM v$pdbs;

-- Paso 2 · Keystore de software y llaves maestras (modo unido: CDB + PDB)
ALTER SYSTEM SET TDE_CONFIGURATION = 'KEYSTORE_CONFIGURATION=FILE' SCOPE = BOTH;
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE IDENTIFIED BY "&pwd_keystore";
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "&pwd_keystore" CONTAINER = ALL;
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "&pwd_keystore" WITH BACKUP USING 'audinc_cdb';

ALTER SESSION SET CONTAINER = XEPDB1;
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "&pwd_keystore" WITH BACKUP USING 'audinc_pdb';

-- Auto-login: el keystore se abre solo al arrancar la base
ALTER SESSION SET CONTAINER = CDB$ROOT;
ADMINISTER KEY MANAGEMENT CREATE AUTO_LOGIN KEYSTORE FROM KEYSTORE IDENTIFIED BY "&pwd_keystore";

-- Paso 3 · Tablespace cifrado y traslado de los datos de negocio
ALTER SESSION SET CONTAINER = XEPDB1;
CREATE TABLESPACE audinc_datos
  DATAFILE 'C:\APP\ISAAC\PRODUCT\21C\ORADATA\XE\XEPDB1\AUDINC_DATOS01.DBF'
  SIZE 50M AUTOEXTEND ON NEXT 10M MAXSIZE 500M
  ENCRYPTION USING 'AES256' ENCRYPT;

ALTER USER audinc_demo DEFAULT TABLESPACE audinc_datos QUOTA 50M ON audinc_datos;

ALTER TABLE audinc_demo.clientes  MOVE TABLESPACE audinc_datos UPDATE INDEXES;
ALTER TABLE audinc_demo.ventas    MOVE TABLESPACE audinc_datos UPDATE INDEXES;
ALTER TABLE audinc_demo.empleados MOVE TABLESPACE audinc_datos UPDATE INDEXES;

-- Evidencia
SELECT wrl_type, status, wallet_type FROM v$encryption_wallet;
SELECT tablespace_name, encrypted FROM dba_tablespaces WHERE tablespace_name = 'AUDINC_DATOS';
SELECT table_name, tablespace_name FROM dba_tables WHERE owner = 'AUDINC_DEMO';
SELECT index_name, status FROM dba_indexes WHERE owner = 'AUDINC_DEMO';

UNDEFINE pwd_keystore

-- Respaldo del keystore (fuera de la carpeta de Oracle):
HOST robocopy "C:\app\isaac\product\21c\admin\XE\wallet" "C:\Users\isaac\Documents\AUDINC_wallet_respaldo" /E
