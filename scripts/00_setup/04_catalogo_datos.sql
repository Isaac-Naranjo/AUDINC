-- =====================================================================
-- AUDINC · 04_catalogo_datos.sql                        (PHVA: Planificar)
-- Carga el catálogo definido en docs/catalogo_controles.md
-- =====================================================================

-- ---------------------------------------------------------------------
-- Riesgos de confidencialidad
-- ---------------------------------------------------------------------
INSERT INTO audinc_owner.riesgo (id_riesgo, nombre, dimension, escenario, impacto, probabilidad) VALUES
  ('R-CONF-01', 'Privilegios excesivos o mal asignados', 'Acceso a datos',
   'Usuarios con rol DBA, privilegios ANY o grants a PUBLIC leen datos que no les corresponden', 5, 4);
INSERT INTO audinc_owner.riesgo (id_riesgo, nombre, dimension, escenario, impacto, probabilidad) VALUES
  ('R-CONF-02', 'Autenticación débil y cuentas no gestionadas', 'Acceso a datos',
   'Contraseñas por defecto, sin bloqueo por intentos, cuentas inactivas abiertas o compartidas', 5, 3);
INSERT INTO audinc_owner.riesgo (id_riesgo, nombre, dimension, escenario, impacto, probabilidad) VALUES
  ('R-CONF-03', 'Datos sensibles expuestos en claro', 'Datos sensibles',
   'Datos personales (Ley 8968) visibles sin enmascarar en consultas, datafiles sin cifrar o tráfico de red sin cifrar', 5, 3);
INSERT INTO audinc_owner.riesgo (id_riesgo, nombre, dimension, escenario, impacto, probabilidad) VALUES
  ('R-CONF-04', 'Copias no autorizadas o no protegidas', 'Copias no autorizadas',
   'Backups/exports sin cifrar, clones DEV/TEST con datos reales, datos borrados recuperables desde la papelera', 4, 3);
INSERT INTO audinc_owner.riesgo (id_riesgo, nombre, dimension, escenario, impacto, probabilidad) VALUES
  ('R-CONF-05', 'Falta de trazabilidad', 'Transversal',
   'Accesos y cambios de privilegios sin auditar; registros alterables; imposible investigar un fraude', 4, 3);

-- ---------------------------------------------------------------------
-- Controles ISO/IEC 27001:2022 Anexo A
-- ---------------------------------------------------------------------
INSERT INTO audinc_owner.control_iso VALUES ('A5.12', 'Clasificación de la información', 'ORGANIZACIONAL',
  'Identificar qué columnas contienen datos sensibles para poder protegerlas',
  'COMMENT ON COLUMN ... IS ''[CONFIDENCIAL] ...''', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A5.15', 'Control de acceso', 'ORGANIZACIONAL',
  'Nada se concede a PUBLIC sobre el esquema de negocio',
  'REVOKE ... FROM PUBLIC', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A5.16', 'Gestión de identidad', 'ORGANIZACIONAL',
  'Cada persona tiene su propia cuenta y las cuentas inactivas se bloquean',
  'CREATE USER / ALTER USER ... ACCOUNT LOCK', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A5.17', 'Información de autenticación', 'ORGANIZACIONAL',
  'Sin contraseñas por defecto ni algoritmos de hash débiles',
  'ALTER USER ... PASSWORD EXPIRE; SQLNET.ALLOWED_LOGON_VERSION_SERVER', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A5.18', 'Derechos de acceso', 'ORGANIZACIONAL',
  'Los privilegios se asignan por rol y se pueden revisar',
  'GRANT SELECT ON ... TO vendedor; GRANT vendedor TO juan', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A5.33', 'Protección de registros', 'ORGANIZACIONAL',
  'Quien es auditado no puede borrar ni alterar los registros de auditoría',
  'Separar AUDIT_ADMIN de las cuentas DBA operativas', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A8.2', 'Derechos de acceso privilegiados', 'TECNOLOGICO',
  'Mínimo privilegio en cuentas con capacidades administrativas',
  'REVOKE DBA / privilegios ANY innecesarios', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A8.3', 'Restricción de acceso a la información', 'TECNOLOGICO',
  'Cada usuario ve solo las filas que le corresponden',
  'Virtual Private Database: DBMS_RLS.ADD_POLICY', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A8.5', 'Autenticación segura', 'TECNOLOGICO',
  'Bloqueo por intentos fallidos, complejidad de contraseña y cierre de sesión inactiva',
  'CREATE PROFILE con FAILED_LOGIN_ATTEMPTS, PASSWORD_VERIFY_FUNCTION, IDLE_TIME', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A8.8', 'Gestión de vulnerabilidades técnicas', 'TECNOLOGICO',
  'Mantener el motor actualizado; en XE no hay parches, se documenta como riesgo aceptado',
  'Revisión de versión (V$VERSION) y plan de migración', 'S');
INSERT INTO audinc_owner.control_iso VALUES ('A8.10', 'Eliminación de información', 'TECNOLOGICO',
  'Los datos sensibles eliminados no quedan recuperables',
  'DROP TABLE ... PURGE; PURGE RECYCLEBIN', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A8.11', 'Enmascaramiento de datos', 'TECNOLOGICO',
  'Los datos personales se ocultan a quien no necesita verlos',
  'Data Redaction: DBMS_REDACT.ADD_POLICY', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A8.12', 'Prevención de fuga de datos', 'TECNOLOGICO',
  'Limitar las vías de extracción masiva (UTL_FILE, UTL_HTTP, Data Pump)',
  'REVOKE EXECUTE ON UTL_FILE FROM PUBLIC; controlar roles de exportación', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A8.13', 'Respaldo de la información', 'TECNOLOGICO',
  'Los respaldos que salen del servidor van cifrados',
  'RMAN: CONFIGURE ENCRYPTION FOR DATABASE ON', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A8.15', 'Registro (logging)', 'TECNOLOGICO',
  'Auditar accesos a datos sensibles y el uso de privilegios',
  'CREATE AUDIT POLICY ...; AUDIT POLICY ...', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A8.20', 'Seguridad de redes', 'TECNOLOGICO',
  'El tráfico cliente-servidor viaja cifrado',
  'sqlnet.ora: SQLNET.ENCRYPTION_SERVER = REQUIRED', 'N');
INSERT INTO audinc_owner.control_iso VALUES ('A8.24', 'Uso de criptografía', 'TECNOLOGICO',
  'Los datos en reposo (datafiles) están cifrados',
  'TDE: ADMINISTER KEY MANAGEMENT + tablespace cifrado', 'S');
INSERT INTO audinc_owner.control_iso VALUES ('A8.33', 'Información de prueba', 'TECNOLOGICO',
  'Los clones DEV/TEST no contienen datos personales reales',
  'Enmascarar o generar datos ficticios al clonar', 'S');

-- ---------------------------------------------------------------------
-- Tareas críticas del DBA
-- ---------------------------------------------------------------------
INSERT INTO audinc_owner.tarea VALUES ('T-01', 'Gestión de usuarios (alta, baja, bloqueo de inactivos)');
INSERT INTO audinc_owner.tarea VALUES ('T-02', 'Gestión de privilegios y roles');
INSERT INTO audinc_owner.tarea VALUES ('T-03', 'Autenticación y perfiles de contraseña');
INSERT INTO audinc_owner.tarea VALUES ('T-04', 'Cifrado TDE');
INSERT INTO audinc_owner.tarea VALUES ('T-05', 'Enmascaramiento / Data Redaction');
INSERT INTO audinc_owner.tarea VALUES ('T-06', 'Respaldos (RMAN / Data Pump)');
INSERT INTO audinc_owner.tarea VALUES ('T-07', 'Auditoría de base de datos');
INSERT INTO audinc_owner.tarea VALUES ('T-08', 'Parcheo y actualización');
INSERT INTO audinc_owner.tarea VALUES ('T-09', 'Configuración del listener y red');
INSERT INTO audinc_owner.tarea VALUES ('T-10', 'Eliminación segura de información');
INSERT INTO audinc_owner.tarea VALUES ('T-11', 'Gestión de logs (redo, archive, LogMiner)');
INSERT INTO audinc_owner.tarea VALUES ('T-12', 'Clones DEV/TEST');

INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-01', 'R-CONF-01');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-01', 'R-CONF-02');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-02', 'R-CONF-01');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-03', 'R-CONF-02');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-04', 'R-CONF-03');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-05', 'R-CONF-03');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-06', 'R-CONF-04');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-07', 'R-CONF-05');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-08', 'R-CONF-01');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-08', 'R-CONF-03');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-09', 'R-CONF-03');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-10', 'R-CONF-04');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-11', 'R-CONF-05');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-12', 'R-CONF-03');
INSERT INTO audinc_owner.tarea_riesgo VALUES ('T-12', 'R-CONF-04');

INSERT INTO audinc_owner.tarea_control VALUES ('T-01', 'A5.16');
INSERT INTO audinc_owner.tarea_control VALUES ('T-02', 'A5.15');
INSERT INTO audinc_owner.tarea_control VALUES ('T-02', 'A5.18');
INSERT INTO audinc_owner.tarea_control VALUES ('T-02', 'A8.2');
INSERT INTO audinc_owner.tarea_control VALUES ('T-03', 'A5.17');
INSERT INTO audinc_owner.tarea_control VALUES ('T-03', 'A8.5');
INSERT INTO audinc_owner.tarea_control VALUES ('T-04', 'A8.24');
INSERT INTO audinc_owner.tarea_control VALUES ('T-05', 'A5.12');
INSERT INTO audinc_owner.tarea_control VALUES ('T-05', 'A8.11');
INSERT INTO audinc_owner.tarea_control VALUES ('T-06', 'A8.13');
INSERT INTO audinc_owner.tarea_control VALUES ('T-07', 'A5.33');
INSERT INTO audinc_owner.tarea_control VALUES ('T-07', 'A8.15');
INSERT INTO audinc_owner.tarea_control VALUES ('T-08', 'A8.8');
INSERT INTO audinc_owner.tarea_control VALUES ('T-09', 'A8.20');
INSERT INTO audinc_owner.tarea_control VALUES ('T-10', 'A8.10');
INSERT INTO audinc_owner.tarea_control VALUES ('T-11', 'A8.15');
INSERT INTO audinc_owner.tarea_control VALUES ('T-11', 'A5.33');
INSERT INTO audinc_owner.tarea_control VALUES ('T-12', 'A8.11');
INSERT INTO audinc_owner.tarea_control VALUES ('T-12', 'A8.12');
INSERT INTO audinc_owner.tarea_control VALUES ('T-12', 'A8.33');

-- ---------------------------------------------------------------------
-- Controles observables: cada consulta devuelve los hallazgos (0 filas = cumple)
-- Convención: la PRIMERA columna identifica el objeto (usuario, tabla, archivo...);
-- es el valor contra el que se comparan las excepciones aprobadas.
-- ---------------------------------------------------------------------
INSERT INTO audinc_owner.control_observable VALUES ('CO-01', 'A5.12',
  'Columnas con datos personales clasificadas como [CONFIDENCIAL]',
  q'~SELECT c.table_name, c.column_name
FROM dba_tab_columns c
LEFT JOIN dba_col_comments m
  ON m.owner = c.owner AND m.table_name = c.table_name AND m.column_name = c.column_name
WHERE c.owner = 'AUDINC_DEMO'
  AND c.table_name NOT LIKE 'BIN$%'
  AND REGEXP_LIKE(c.column_name, 'CEDULA|EMAIL|TELEFONO|DIRECCION|SALARIO')
  AND (m.comments IS NULL OR m.comments NOT LIKE '[CONFIDENCIAL]%')~',
  'Todas las columnas sensibles tienen comentario [CONFIDENCIAL]');

INSERT INTO audinc_owner.control_observable VALUES ('CO-02', 'A5.15',
  'Sin privilegios concedidos a PUBLIC sobre el esquema de negocio',
  q'~SELECT table_name, privilege
FROM dba_tab_privs
WHERE owner = 'AUDINC_DEMO'
  AND grantee = 'PUBLIC'~',
  '0 privilegios a PUBLIC sobre AUDINC_DEMO');

INSERT INTO audinc_owner.control_observable VALUES ('CO-03', 'A5.16',
  'Cuentas abiertas sin uso en los últimos 90 días (o nunca usadas)',
  q'~SELECT username, account_status, TO_CHAR(last_login, 'YYYY-MM-DD HH24:MI') AS last_login
FROM dba_users
WHERE oracle_maintained = 'N'
  AND authentication_type = 'PASSWORD'
  AND account_status = 'OPEN'
  AND (last_login IS NULL OR last_login < SYSTIMESTAMP - INTERVAL '90' DAY)~',
  '0 cuentas abiertas inactivas');

INSERT INTO audinc_owner.control_observable VALUES ('CO-04', 'A5.17',
  'Sin contraseñas por defecto ni hashes 10G en cuentas abiertas',
  q'~SELECT d.username, 'Contrasena por defecto' AS hallazgo
FROM dba_users_with_defpwd d
JOIN dba_users u ON u.username = d.username
WHERE u.account_status = 'OPEN'
UNION ALL
SELECT username, 'Hash 10G habilitado'
FROM dba_users
WHERE account_status = 'OPEN'
  AND password_versions LIKE '%10G%'~',
  '0 cuentas con contraseña por defecto o hash 10G');

INSERT INTO audinc_owner.control_observable VALUES ('CO-05', 'A5.18',
  'Privilegios de objeto sobre el negocio solo a través de roles',
  q'~SELECT grantee, table_name, privilege
FROM dba_tab_privs
WHERE owner = 'AUDINC_DEMO'
  AND grantee IN (SELECT username FROM dba_users)~',
  '0 privilegios de objeto otorgados directamente a usuarios');

INSERT INTO audinc_owner.control_observable VALUES ('CO-06', 'A5.33',
  'AUDIT_ADMIN separado de las cuentas con rol DBA',
  q'~SELECT grantee
FROM dba_role_privs
WHERE granted_role = 'AUDIT_ADMIN'
  AND grantee <> 'SYS'
  AND grantee IN (SELECT grantee FROM dba_role_privs WHERE granted_role = 'DBA')~',
  'Ninguna cuenta (salvo SYS) tiene DBA y AUDIT_ADMIN a la vez');

INSERT INTO audinc_owner.control_observable VALUES ('CO-07', 'A8.2',
  'Sin rol DBA, privilegios ANY ni privilegios administrativos (SYSDBA, SYSBACKUP...) en cuentas no mantenidas por Oracle',
  q'~SELECT grantee, privilege AS privilegio
FROM dba_sys_privs
WHERE privilege LIKE '%ANY%'
  AND grantee IN (SELECT username FROM dba_users WHERE oracle_maintained = 'N')
UNION ALL
SELECT grantee, granted_role
FROM dba_role_privs
WHERE granted_role = 'DBA'
  AND grantee IN (SELECT username FROM dba_users WHERE oracle_maintained = 'N')
UNION ALL
SELECT username,
       'Administrativo: ' || RTRIM(DECODE(sysdba, 'TRUE', 'SYSDBA ') || DECODE(sysoper, 'TRUE', 'SYSOPER ') ||
                                  DECODE(sysbackup, 'TRUE', 'SYSBACKUP ') || DECODE(sysdg, 'TRUE', 'SYSDG ') ||
                                  DECODE(syskm, 'TRUE', 'SYSKM '))
FROM v$pwfile_users
WHERE username IN (SELECT username FROM dba_users WHERE oracle_maintained = 'N')~',
  '0 cuentas de usuario con DBA, privilegios ANY o administrativos sin excepción aprobada');

INSERT INTO audinc_owner.control_observable VALUES ('CO-08', 'A8.3',
  'Política VPD habilitada sobre AUDINC_DEMO.VENTAS',
  q'~SELECT 'AUDINC_DEMO.VENTAS' AS tabla, 'Sin politica VPD habilitada' AS hallazgo
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM dba_policies
                  WHERE object_owner = 'AUDINC_DEMO'
                    AND object_name  = 'VENTAS'
                    AND enable       = 'YES')~',
  'Existe al menos una política VPD habilitada');

INSERT INTO audinc_owner.control_observable VALUES ('CO-09', 'A8.5',
  'Usuarios con contraseña asignados a un perfil seguro',
  q'~SELECT username, profile
FROM dba_users
WHERE oracle_maintained = 'N'
  AND authentication_type = 'PASSWORD'
  AND account_status = 'OPEN'
  AND profile NOT IN ('AUDINC_SEGURO', 'AUDINC_SERVICIO')~',
  '0 usuarios abiertos fuera de AUDINC_SEGURO / AUDINC_SERVICIO');

INSERT INTO audinc_owner.control_observable VALUES ('CO-10', 'A8.10',
  'Papelera de reciclaje sin objetos del esquema de negocio',
  q'~SELECT original_name, type, droptime
FROM dba_recyclebin
WHERE owner = 'AUDINC_DEMO'~',
  '0 objetos de AUDINC_DEMO en la papelera');

INSERT INTO audinc_owner.control_observable VALUES ('CO-11', 'A8.11',
  'Columnas sensibles cubiertas por Data Redaction y sin exenciones',
  q'~SELECT c.table_name AS objeto, c.column_name AS detalle
FROM dba_tab_columns c
WHERE c.owner = 'AUDINC_DEMO'
  AND c.table_name NOT LIKE 'BIN$%'
  AND REGEXP_LIKE(c.column_name, 'CEDULA|EMAIL|TELEFONO|DIRECCION|SALARIO')
  AND NOT EXISTS (SELECT 1 FROM redaction_columns r
                  WHERE r.object_owner = c.owner
                    AND r.object_name  = c.table_name
                    AND r.column_name  = c.column_name)
UNION ALL
SELECT grantee, privilege
FROM dba_sys_privs
WHERE privilege = 'EXEMPT REDACTION POLICY'
  AND grantee IN (SELECT username FROM dba_users WHERE oracle_maintained = 'N')~',
  'Todas las columnas sensibles con redaction y 0 usuarios exentos');

INSERT INTO audinc_owner.control_observable VALUES ('CO-12', 'A8.12',
  'Paquetes de extracción no ejecutables por PUBLIC y roles de exportación controlados',
  q'~SELECT grantee, table_name AS objeto
FROM dba_tab_privs
WHERE grantee = 'PUBLIC'
  AND owner = 'SYS'
  AND table_name IN ('UTL_FILE', 'UTL_HTTP', 'UTL_TCP', 'UTL_SMTP')
UNION ALL
SELECT grantee, granted_role
FROM dba_role_privs
WHERE granted_role IN ('DATAPUMP_EXP_FULL_DATABASE', 'EXP_FULL_DATABASE')
  AND grantee IN (SELECT username FROM dba_users WHERE oracle_maintained = 'N')~',
  '0 grants de UTL_* a PUBLIC y 0 usuarios con roles de exportación total');

INSERT INTO audinc_owner.control_observable VALUES ('CO-13', 'A8.13',
  'Respaldos RMAN configurados con cifrado',
  q'~SELECT 'RMAN: ENCRYPTION FOR DATABASE' AS objeto, 'Cifrado de respaldos no configurado' AS hallazgo
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM v$rman_configuration
                  WHERE name = 'ENCRYPTION FOR DATABASE' AND value = 'ON')
UNION ALL
SELECT handle, 'Pieza de respaldo sin cifrar'
FROM v$backup_piece
WHERE encrypted = 'NO'
  AND status = 'A'~',
  'Cifrado RMAN activo y 0 piezas de respaldo sin cifrar');

INSERT INTO audinc_owner.control_observable VALUES ('CO-14', 'A8.15',
  'Política de auditoría AUDINC activa y auditoría de SYS habilitada',
  q'~SELECT 'Sin politica de auditoria AUDINC_* habilitada' AS hallazgo
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM audit_unified_enabled_policies
                  WHERE policy_name LIKE 'AUDINC%')
UNION ALL
SELECT 'audit_sys_operations = ' || value
FROM v$parameter
WHERE name = 'audit_sys_operations'
  AND UPPER(value) <> 'TRUE'~',
  'Política AUDINC_* habilitada y audit_sys_operations = TRUE');

INSERT INTO audinc_owner.control_observable VALUES ('CO-15', 'A8.20',
  'La sesión del evaluador viaja con cifrado de red nativo',
  q'~SELECT 'Sesion sin cifrado de red' AS hallazgo
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM v$session_connect_info
                  WHERE sid = SYS_CONTEXT('USERENV', 'SID')
                    AND network_service_banner LIKE '%Encryption service adapter%')~',
  'El banner de la sesión muestra un adaptador de cifrado activo (AES)');

INSERT INTO audinc_owner.control_observable VALUES ('CO-16', 'A8.24',
  '(Complementario) Wallet TDE abierto y tablespace de negocio cifrado',
  q'~SELECT 'Wallet TDE: ' || status AS hallazgo
FROM v$encryption_wallet
WHERE con_id = SYS_CONTEXT('USERENV', 'CON_ID')
  AND status <> 'OPEN'
UNION ALL
SELECT 'Tablespace sin cifrar: ' || tablespace_name
FROM dba_tablespaces
WHERE tablespace_name IN (SELECT default_tablespace FROM dba_users WHERE username = 'AUDINC_DEMO')
  AND encrypted = 'NO'~',
  'Wallet OPEN y tablespace de AUDINC_DEMO cifrado');

-- ---------------------------------------------------------------------
-- Batería de pruebas
-- ---------------------------------------------------------------------
INSERT INTO audinc_owner.prueba (id_prueba, id_co, tipo, procedimiento, resultado_esperado, herramienta)
SELECT 'PT-' || SUBSTR(id_co, 4), id_co, 'CONSULTA',
       'Ejecutar la consulta de evidencia de ' || id_co || ' (' || id_control || ')',
       criterio, 'AUDINC / SQL Developer'
FROM   audinc_owner.control_observable;

INSERT INTO audinc_owner.prueba VALUES ('PT-17', 'CO-11', 'FUNCIONAL',
  'Conectar como JUAN (sin EXEMPT REDACTION POLICY) y consultar AUDINC_DEMO.CLIENTES',
  'Cédula, email y teléfono aparecen enmascarados', 'SQL Developer');
INSERT INTO audinc_owner.prueba VALUES ('PT-18', 'CO-08', 'FUNCIONAL',
  'Conectar como JUAN y ejecutar SELECT * FROM AUDINC_DEMO.VENTAS',
  'Solo se devuelven las ventas con vendedor = JUAN', 'SQL Developer');
INSERT INTO audinc_owner.prueba VALUES ('PT-19', 'CO-09', 'FUNCIONAL',
  'Intentar conectar como PEDRO con contraseña incorrecta hasta superar FAILED_LOGIN_ATTEMPTS',
  'ORA-28000: la cuenta queda bloqueada', 'SQL*Plus');
INSERT INTO audinc_owner.prueba VALUES ('PT-20', 'CO-05', 'FUNCIONAL',
  'Conectar como JUAN y consultar AUDINC_DEMO.EMPLEADOS',
  'ORA-00942 / ORA-01031: sin acceso a salarios', 'SQL*Plus');
INSERT INTO audinc_owner.prueba VALUES ('PT-21', 'CO-14', 'FUNCIONAL',
  'Consultar UNIFIED_AUDIT_TRAIL después de PT-17 a PT-20',
  'Los eventos aparecen con usuario, acción, objeto y hora', 'SQL Developer');

INSERT INTO audinc_owner.prueba VALUES ('PT-22', 'CO-09', 'FUNCIONAL',
  'Login de la aplicación: sin sesión, LUIS (sin rol AUDITOR), ISAAC (AUDITOR), evaluación, cierre de sesión',
  '401 sin sesión; 403 LUIS; ISAAC entra con cookie HttpOnly/SameSite; evaluación a nombre de ISAAC; 401 tras cerrar sesión',
  'php tests/PT-22_login.php');

INSERT INTO audinc_owner.prueba VALUES ('PT-23', 'CO-02', 'FUNCIONAL',
  'Ciclo Verificar -> Actuar: GRANT SELECT de CLIENTES a PUBLIC, evaluación, REVOKE, evaluación',
  'Primera evaluación: CO-02 No cumple con el permiso como evidencia; segunda: CO-02 Cumple',
  'php tests/PT-23_deteccion_y_correccion.php');

COMMIT;
