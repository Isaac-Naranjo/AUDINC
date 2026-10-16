-- =====================================================================
-- AUDINC · 00_verificar_entorno.sql                     (PHVA: Planificar)
-- Verifica qué funcionalidades de seguridad están disponibles en la
-- instancia antes de diseñar los controles. SOLO LECTURA: no modifica nada.
-- Ejecutar conectado a la PDB (XEPDB1) con un usuario con acceso al diccionario.
-- =====================================================================
SET LINESIZE 200
SET PAGESIZE 100
COLUMN parameter FORMAT A40
COLUMN value     FORMAT A40
COLUMN name      FORMAT A32

PROMPT === 1. Versión y contenedor ===
SELECT banner_full FROM v$version;
SELECT SYS_CONTEXT('USERENV','CON_NAME')         AS contenedor,
       SYS_CONTEXT('USERENV','NETWORK_PROTOCOL') AS protocolo
FROM dual;

PROMPT === 2. Opciones de seguridad (cifrado, redaction, VPD, auditoría) ===
SELECT parameter, value
FROM   v$option
WHERE  UPPER(parameter) LIKE '%ENCRYPT%'
   OR  UPPER(parameter) LIKE '%REDACT%'
   OR  UPPER(parameter) LIKE '%FINE-GRAINED%'
   OR  UPPER(parameter) LIKE '%AUDIT%'
   OR  UPPER(parameter) LIKE '%LABEL%'
   OR  UPPER(parameter) LIKE '%VAULT%'
ORDER  BY parameter;

PROMPT === 3. Paquetes de seguridad presentes ===
SELECT object_name, status
FROM   dba_objects
WHERE  owner = 'SYS'
AND    object_type = 'PACKAGE'
AND    object_name IN ('DBMS_REDACT','DBMS_RLS','DBMS_AUDIT_MGMT','DBMS_LOGMNR','DBMS_CRYPTO');

PROMPT === 4. Parámetros relevantes ===
SELECT name, value
FROM   v$parameter
WHERE  name IN ('audit_trail','audit_sys_operations','resource_limit',
                'wallet_root','tde_configuration','remote_login_passwordfile',
                'sec_max_failed_login_attempts','recyclebin')
ORDER  BY name;

PROMPT === 5. Wallet TDE ===
SELECT wrl_type, status, wallet_type, con_id FROM v$encryption_wallet;

PROMPT === 6. Trazabilidad (archivelog / LogMiner) ===
SELECT log_mode, supplemental_log_data_min FROM v$database;

PROMPT === 7. Cifrado de red de la sesión actual ===
SELECT network_service_banner
FROM   v$session_connect_info
WHERE  sid = SYS_CONTEXT('USERENV','SID');

PROMPT === 8. Políticas de auditoría unificada habilitadas ===
SELECT policy_name, enabled_option, entity_name
FROM   audit_unified_enabled_policies
ORDER  BY policy_name;
