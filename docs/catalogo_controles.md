# Catálogo AUDINC — Riesgos, tareas, controles y pruebas (BORRADOR v0.1)

> Estado: **borrador para revisión**. Base de evidencia: Oracle Database 21c XE 21.3, PDB `XEPDB1`.
> Escalas: Impacto y Probabilidad 1–5 · Nivel de riesgo = I × P (1–6 Bajo, 8–12 Medio, 15–25 Alto).

---

## 0. Línea base del entorno (resultado de `scripts/00_setup/00_verificar_entorno.sql`)

| Funcionalidad | Disponible | Estado actual | Implicación |
|---|---|---|---|
| Transparent Data Encryption | TRUE | Wallet `NOT_AVAILABLE` (sin configurar) | Control implementable; hoy **no cumple** |
| Data Redaction (`DBMS_REDACT`) | TRUE | Sin políticas | Implementable |
| VPD / Fine-grained access control (`DBMS_RLS`) | TRUE | Sin políticas | Implementable |
| Backup Encryption (RMAN) | TRUE | Sin configurar | Implementable |
| Unified Auditing (modo puro) | FALSE | Modo **mixto**: `ORA_LOGON_FAILURES` y `ORA_SECURECONFIG` activas | Se usan políticas unificadas en modo mixto |
| `audit_sys_operations` | TRUE | — | Ya cumple parcialmente A8.15 |
| Modo de log | ARCHIVELOG | `supplemental_log_data_min = NO` | LogMiner requiere activar log suplementario |
| `resource_limit` | TRUE | — | `IDLE_TIME` en perfiles sí tiene efecto |
| Oracle Label Security / Database Vault | FALSE | — | Fuera de alcance |

> Pendiente: confirmar en *Oracle Database 21c XE Licensing Information* que estas opciones están licenciadas en XE (fuente verificada para la tabla de IA).

---

## 1. Riesgos de confidencialidad (R-CONF)

Las tres dimensiones de confidencialidad vistas en clase: **acceso a datos**, **datos sensibles**, **copias no autorizadas**.

| ID | Riesgo | Dimensión | Escenario | I | P | Nivel |
|---|---|---|---|---|---|---|
| R-CONF-01 | Privilegios excesivos o mal asignados | Acceso a datos | Usuarios con rol `DBA`, privilegios `ANY` o grants a `PUBLIC` leen datos que no les corresponden | 5 | 4 | 20 Alto |
| R-CONF-02 | Autenticación débil y cuentas no gestionadas | Acceso a datos | Contraseñas por defecto, sin bloqueo por intentos, cuentas inactivas abiertas o compartidas | 5 | 3 | 15 Alto |
| R-CONF-03 | Datos sensibles expuestos en claro | Datos sensibles | Datos personales (Ley 8968) visibles sin enmascarar en consultas, datafiles sin cifrar o tráfico de red sin cifrar | 5 | 3 | 15 Alto |
| R-CONF-04 | Copias no autorizadas o no protegidas | Copias no autorizadas | Backups/exports sin cifrar, clones DEV/TEST con datos reales, datos “borrados” recuperables desde la papelera | 4 | 3 | 12 Medio |
| R-CONF-05 | Falta de trazabilidad | Transversal | Accesos y cambios de privilegios sin auditar; registros de auditoría alterables; imposible investigar un fraude | 4 | 3 | 12 Medio |

---

## 2. Tareas críticas del DBA

| ID | Tarea | Riesgos | Controles ISO |
|---|---|---|---|
| T-01 | Gestión de usuarios (alta, baja, bloqueo de inactivos) | R-01, R-02 | A5.16 |
| T-02 | Gestión de privilegios y roles | R-01 | A5.15, A5.18, A8.2 |
| T-03 | Autenticación y perfiles de contraseña | R-02 | A5.17, A8.5 |
| T-04 | Cifrado TDE de tablespaces/columnas | R-03 | A8.24\* |
| T-05 | Enmascaramiento / Data Redaction | R-03 | A8.11, A5.12 |
| T-06 | Respaldos (RMAN / Data Pump) | R-04 | A8.13 |
| T-07 | Auditoría de base de datos | R-05 | A8.15, A5.33 |
| T-08 | Parcheo y actualización | R-01, R-03 | A8.8\* |
| T-09 | Configuración del listener y red | R-03 | A8.20 |
| T-10 | Eliminación segura de información | R-04 | A8.10 |
| T-11 | Gestión de logs (redo, archive, LogMiner) | R-05 | A8.15, A5.33 |
| T-12 | Clones DEV/TEST | R-03, R-04 | A8.11, A8.12 (A8.33\*) |

\* Controles **complementarios** que no aparecen en la lista del enunciado pero son los que corresponden en el Anexo A 2022 (ver §3.1).

---

## 3. Mapeo de controles ISO/IEC 27001:2022 (Anexo A)

| Control | Nombre | Justificación (confidencialidad) | Implementación en Oracle | Evidencia observable |
|---|---|---|---|---|
| A5.12 | Clasificación de la información | Saber qué columnas son sensibles para protegerlas | `COMMENT ON COLUMN ... IS '[CONFIDENCIAL] ...'` | `DBA_COL_COMMENTS` |
| A5.15 | Control de acceso | Nada se concede a `PUBLIC` sobre el esquema de negocio | `REVOKE ... FROM PUBLIC` | `DBA_TAB_PRIVS` |
| A5.16 | Gestión de identidades | Cada persona con su cuenta; inactivas bloqueadas | `CREATE USER`, `ALTER USER ... ACCOUNT LOCK` | `DBA_USERS` (`LAST_LOGIN`, `ACCOUNT_STATUS`) |
| A5.17 | Información de autenticación | Sin contraseñas por defecto ni hashes débiles | `ALTER USER ... PASSWORD EXPIRE` | `DBA_USERS_WITH_DEFPWD`, `PASSWORD_VERSIONS` |
| A5.18 | Derechos de acceso | Privilegios por rol (`CREATE ROLE vendedor`), revisables | `GRANT SELECT ON ... TO vendedor; GRANT vendedor TO juan` | `DBA_TAB_PRIVS`, `DBA_ROLE_PRIVS` |
| A5.33 | Protección de registros | Los registros de auditoría no pueden ser borrados por quien es auditado | Separar `AUDIT_ADMIN` de los DBA operativos | `DBA_ROLE_PRIVS` |
| A8.2 | Derechos de acceso privilegiado | Mínimo privilegio en cuentas administrativas | Revocar `DBA` / `ANY` innecesarios | `DBA_SYS_PRIVS`, `DBA_ROLE_PRIVS`, `V$PWFILE_USERS` |
| A8.3 | Restricción de acceso a la información | Cada usuario ve solo las filas que le corresponden | VPD con `DBMS_RLS.ADD_POLICY` | `DBA_POLICIES` |
| A8.5 | Autenticación segura | Bloqueo por intentos, complejidad y sesión inactiva | `CREATE PROFILE` con `FAILED_LOGIN_ATTEMPTS`, `PASSWORD_VERIFY_FUNCTION`, `IDLE_TIME` | `DBA_PROFILES`, `DBA_USERS.PROFILE` |
| A8.10 | Eliminación de información | Datos sensibles eliminados no quedan recuperables | `DROP TABLE ... PURGE`, `PURGE RECYCLEBIN` | `DBA_RECYCLEBIN` |
| A8.11 | Enmascaramiento de datos | Datos personales ocultos a quien no los necesita | `DBMS_REDACT.ADD_POLICY` | `REDACTION_POLICIES`, `REDACTION_COLUMNS` |
| A8.12 | Prevención de fuga de datos | Limitar vías de extracción (`UTL_FILE`, Data Pump, directorios) | `REVOKE EXECUTE ON UTL_FILE FROM PUBLIC` | `DBA_TAB_PRIVS`, `DBA_ROLE_PRIVS` |
| A8.13 | Respaldo de la información | Backups cifrados | `CONFIGURE ENCRYPTION FOR DATABASE ON` (RMAN) | `V$RMAN_CONFIGURATION`, `V$BACKUP_PIECE.ENCRYPTED` |
| A8.15 | Registro (logging) | Auditar accesos a datos sensibles y uso de privilegios | `CREATE AUDIT POLICY ...; AUDIT POLICY ...` | `AUDIT_UNIFIED_ENABLED_POLICIES`, `UNIFIED_AUDIT_TRAIL` |
| A8.20 | Seguridad de redes | Cifrar el tráfico cliente–servidor | `SQLNET.ENCRYPTION_SERVER = REQUIRED` en `sqlnet.ora` | `V$SESSION_CONNECT_INFO` |

### 3.1 Observaciones para validar

- **TDE** encaja en **A8.24 (Uso de criptografía)**, que no está en la lista del enunciado. Propuesta: incluirlo como complementario y justificarlo.
- **Parcheo** encaja en **A8.8 (Gestión de vulnerabilidades técnicas)**. Oracle XE **no recibe parches** (RU/RUR): se documenta como **riesgo aceptado** con la versión como evidencia (`V$VERSION`).
- **Clones DEV/TEST** encajan en **A8.33 (Información de prueba)**; se cubre con A8.11 + A8.12.
- La pizarra usa la numeración **2013** (A.8.1, A.9.2, A.9.4, A.10.1). Su equivalencia en 2022 es: A.9.2 → A5.16/A5.18/A8.2; A.9.4 → A8.3/A8.5; A.10.1 → A8.24; A.8.1 → A5.9. Esta tabla es útil para el marco teórico (cambios 2013 → 2022).

---

## 4. Controles observables por auditor externo (15 + 1 complementario)

Cada control se verifica con una consulta de solo lectura. Esquema de prueba: `AUDINC_DEMO`.
Las consultas definitivas están en `scripts/00_setup/04_catalogo_datos.sql` y se escriben como **consultas de hallazgos**: devuelven las filas que incumplen (0 filas = el control se observa implementado). La tabla siguiente resume la idea de cada una.

| ID | ISO | Qué observa el auditor | Consulta de evidencia | Cumple si |
|---|---|---|---|---|
| CO-01 | A5.12 | Columnas sensibles clasificadas | `SELECT table_name, column_name, comments FROM dba_col_comments WHERE owner='AUDINC_DEMO' AND comments LIKE '[CONFIDENCIAL]%'` | Todas las columnas sensibles aparecen |
| CO-02 | A5.15 | Sin grants a `PUBLIC` en el esquema de negocio | `SELECT table_name, privilege FROM dba_tab_privs WHERE owner='AUDINC_DEMO' AND grantee='PUBLIC'` | 0 filas |
| CO-03 | A5.16 | Cuentas inactivas (>90 días) bloqueadas | `SELECT username, last_login FROM dba_users WHERE oracle_maintained='N' AND account_status='OPEN' AND (last_login IS NULL OR last_login < SYSDATE-90)` | 0 filas |
| CO-04 | A5.17 | Sin contraseñas por defecto ni hashes 10G | `SELECT d.username FROM dba_users_with_defpwd d JOIN dba_users u ON u.username=d.username WHERE u.account_status='OPEN'` + `... WHERE password_versions LIKE '%10G%'` | 0 filas en ambas |
| CO-05 | A5.18 | Privilegios de objeto solo vía roles | `SELECT grantee, table_name, privilege FROM dba_tab_privs WHERE owner='AUDINC_DEMO' AND grantee IN (SELECT username FROM dba_users)` | 0 filas |
| CO-06 | A5.33 | `AUDIT_ADMIN` separado de los DBA operativos | `SELECT grantee FROM dba_role_privs WHERE granted_role='AUDIT_ADMIN' AND grantee IN (SELECT grantee FROM dba_role_privs WHERE granted_role='DBA')` | 0 filas (excepto SYS) |
| CO-07 | A8.2 | Sin rol `DBA` ni privilegios `ANY` en cuentas no administrativas | `SELECT grantee, privilege FROM dba_sys_privs WHERE privilege LIKE '%ANY%' AND grantee IN (SELECT username FROM dba_users WHERE oracle_maintained='N')` | Solo cuentas administrativas justificadas |
| CO-08 | A8.3 | Política VPD activa sobre tablas sensibles | `SELECT object_name, policy_name, enable FROM dba_policies WHERE object_owner='AUDINC_DEMO'` | ≥1 política `ENABLE='YES'` |
| CO-09 | A8.5 | Perfil seguro asignado a todos los usuarios | `SELECT resource_name, limit FROM dba_profiles WHERE profile='AUDINC_SEGURO'` + `SELECT username FROM dba_users WHERE oracle_maintained='N' AND profile='DEFAULT'` | Límites definidos y 0 usuarios en `DEFAULT` |
| CO-10 | A8.10 | Papelera sin objetos sensibles | `SELECT original_name, droptime FROM dba_recyclebin WHERE owner='AUDINC_DEMO'` | 0 filas |
| CO-11 | A8.11 | Data Redaction sobre columnas sensibles | `SELECT object_name, column_name, function_type FROM redaction_columns WHERE object_owner='AUDINC_DEMO'` | Todas las columnas `[CONFIDENCIAL]` cubiertas |
| CO-12 | A8.12 | Paquetes de extracción no ejecutables por `PUBLIC` | `SELECT table_name FROM dba_tab_privs WHERE grantee='PUBLIC' AND table_name IN ('UTL_FILE','UTL_HTTP','UTL_TCP','UTL_SMTP')` | 0 filas |
| CO-13 | A8.13 | Backups RMAN cifrados | `SELECT name, value FROM v$rman_configuration WHERE name LIKE 'ENCRYPTION%'` + `SELECT COUNT(*) FROM v$backup_piece WHERE encrypted='NO'` | Cifrado ON y 0 piezas sin cifrar |
| CO-14 | A8.15 | Auditoría de accesos a datos sensibles y de privilegios | `SELECT policy_name, enabled_option FROM audit_unified_enabled_policies` + `SELECT value FROM v$parameter WHERE name='audit_sys_operations'` | Política `AUDINC_*` activa y `TRUE` |
| CO-15 | A8.20 | Tráfico cliente–servidor cifrado | `SELECT network_service_banner FROM v$session_connect_info WHERE sid=SYS_CONTEXT('USERENV','SID')` (sesión remota) | Banner muestra algoritmo `AES256` activo |
| CO-16 | A8.24\* | Wallet TDE abierto y tablespace de negocio cifrado | `SELECT status FROM v$encryption_wallet` + `SELECT encrypted FROM dba_tablespaces` | Wallet `OPEN` y tablespace cifrado |

---

## 5. Criterio de madurez 0–4 y estado

El evaluador califica cada control observable de forma automática y reproducible a partir de los **hallazgos** (filas que incumplen) que devuelve su consulta:

| Nivel | Significado | Regla aplicada por el evaluador | Estado |
|---|---|---|---|
| 0 | Sin evidencia | La consulta de evidencia no se pudo ejecutar | No cumple |
| 1 | Inicial | Hay hallazgos y no hay mejora respecto a la línea base (primera evaluación) | No cumple |
| 2 | En implementación | Hay hallazgos, pero menos que en la línea base | Parcial |
| 3 | Implementado | 0 hallazgos | Cumple |
| 4 | Sostenido | 0 hallazgos en esta evaluación **y** en la anterior (el control se mantiene en el tiempo: PHVA cerrado), sin depender de excepciones | Cumple |

**Excepciones aprobadas** (tabla `AUDINC_OWNER.EXCEPCION`): un hallazgo cuyo primer valor coincide con una excepción vigente
(igualdad exacta, o prefijo si el objeto termina en `%`) no cuenta como hallazgo, pero sigue visible en la evidencia como
"exceptuado". Toda excepción tiene justificación, control compensatorio, responsable y fecha de vencimiento.
Un riesgo aceptado no equivale a un control implementado: **con excepciones el nivel máximo es 3**.

Implementación: `EvaluadorServicio::calificar()` y `aplicarExcepciones()` en `src/Servicio/EvaluadorServicio.php`.

**Matriz de evaluación** (formato del enunciado): `Tarea | Riesgo | Control | Criterio 0-4 | Evidencia | Estado`. Se genera desde §2 + §4 y la llena el evaluador tras cada ejecución, guardando fecha y resultado.

---

## 6. Batería de pruebas (borrador)

| ID | Tipo | Procedimiento | Resultado esperado | Herramienta |
|---|---|---|---|---|
| PT-01 … PT-16 | Consulta de diccionario | Ejecutar la consulta de CO-01 … CO-16 | El criterio “Cumple si” de §4 | AUDINC / SQL Developer |
| PT-17 | Funcional | Conectar como JUAN (sin `EXEMPT REDACTION POLICY`) y consultar `CLIENTES` | Cédula, email y teléfono enmascarados | SQL Developer |
| PT-18 | Funcional | JUAN ejecuta `SELECT * FROM AUDINC_DEMO.VENTAS` con VPD activo | Solo sus ventas | SQL Developer |
| PT-19 | Funcional | PEDRO falla el login hasta superar `FAILED_LOGIN_ATTEMPTS` | `ORA-28000` cuenta bloqueada | SQL*Plus |
| PT-20 | Funcional | JUAN consulta `AUDINC_DEMO.EMPLEADOS` | `ORA-00942` / `ORA-01031` | SQL*Plus |
| PT-21 | Funcional | Leer `UNIFIED_AUDIT_TRAIL` tras PT-17–PT-20 | Eventos registrados con usuario, acción y hora | SQL Developer |

---

## 6.1 Línea base medida (2026-10-15, antes de aplicar controles)

| CO | Hallazgos | Detalle |
|---|---|---|
| CO-01 | 6 | Columnas sensibles sin clasificar |
| CO-02 | 1 | `SELECT` sobre `CLIENTES` concedido a `PUBLIC` (brecha intencional) |
| CO-03 | 6 | Cuentas abiertas nunca usadas (`TEMPORAL`, `PDBADMIN`, `C##BGBACKUP`, …) |
| CO-04 | 0 | — |
| CO-05 | 1 | `JUAN` con `SELECT` directo sobre `EMPLEADOS` (brecha intencional) |
| CO-06 | 0 | — |
| CO-07 | 1 | `LUIS` con `SELECT ANY TABLE` (brecha intencional) |
| CO-08 | 1 | `VENTAS` sin VPD |
| CO-09 | 8 | Usuarios con perfil `DEFAULT` |
| CO-10 | 1 | `CLIENTES_COPIA` recuperable desde la papelera (brecha intencional) |
| CO-11 | 6 | Columnas sensibles sin redaction |
| CO-12 | 4 | `PUBLIC` con `EXECUTE` sobre `UTL_FILE`, `UTL_HTTP`, `UTL_TCP`, `UTL_SMTP` |
| CO-13 | 7 | RMAN sin cifrado + 6 piezas de respaldo existentes sin cifrar (hallazgo real) |
| CO-14 | 1 | Sin política de auditoría `AUDINC_*` |
| CO-15 | 1 | Sesión del evaluador sin cifrado de red |
| CO-16 | 2 | Wallet `NOT_AVAILABLE`, tablespace `USERS` sin cifrar |

## 6.2 Evolución tras la fase Hacer (2026-10-15)

| CO | Línea base | Tras `01_controles` + PT-17…21 | Estado | Pendiente |
|---|---|---|---|---|
| CO-01 | 6 | 0 | Cumple | — |
| CO-02 | 1 | 0 | Cumple | — |
| CO-03 | 6 | 2 | Parcial | `PDBADMIN`, `C##BGBACKUP` (excepción propuesta) |
| CO-04 | 0 | 0 | Cumple (4) | — |
| CO-05 | 1 | 0 | Cumple | — |
| CO-06 | 0 | 0 | Cumple (4) | — |
| CO-07 | 1 | 0 | Cumple | — |
| CO-08 | 1 | 0 | Cumple | — |
| CO-09 | 8 | 2 | Parcial | `PDBADMIN`, `C##BGBACKUP` (excepción propuesta) |
| CO-10 | 1 | 0 | Cumple | — |
| CO-11 | 6 | 0 | Cumple | — |
| CO-12 | 4 | 0 | Cumple | Ver acción correctiva AC-01 |
| CO-13 | 7 | 7 | No cumple | Requiere TDE + aprobación (A8.13) |
| CO-14 | 1 | 0 | Cumple | — |
| CO-15 | 1 | 0 | Cumple | A8.20 aplicado: AES256 + SHA256 |
| CO-16 | 2 | 2 | No cumple | Requiere aprobación (A8.24, reinicio) |

**Resultado:** de 2 a 12 controles en Cumple. Todas las pruebas funcionales PT-17 a PT-21 dieron el resultado esperado.

## 6.2.1 Fase Actuar — AC-02 (2026-10-16)

- CO-07 ampliado: ahora también detecta privilegios administrativos (`SYSDBA`, `SYSOPER`, `SYSBACKUP`, `SYSDG`, `SYSKM`) vía `V$PWFILE_USERS`. Detectó `C##BGBACKUP` con `SYSBACKUP`.
- `PDBADMIN` (creado por el instalador de XE, nunca usado) → bloqueado.
- Excepciones aprobadas (vencen 2027-01-16) para objetos del proyecto BackupGuard, que comparte la instancia: `C##BGBACKUP` (CO-03, CO-07, CO-09), configuración RMAN y respaldos `C:\BACKUPGUARD_RMAN\%` (CO-13).

| Resultado | Línea base | Tras Hacer | Tras A8.20 | Tras AC-02 |
|---|---|---|---|---|
| Controles en Cumple | 2 / 16 | 11 / 16 | 12 / 16 | **15 / 16** |
| Pendiente | — | — | — | CO-16 (A8.24 TDE, pospuesto) |

## 6.3 Alcance: qué controles son de la PDB y cuáles de toda la instancia

La instalación tiene **una sola instancia XE** (un CDB) con la PDB `XEPDB1`. Otros proyectos (p. ej. BackupGuard, usuario común `C##BGBACKUP` con `SYSBACKUP`) usan la misma instancia y respaldan el CDB completo, incluida `XEPDB1`.

| Alcance | Controles |
|---|---|
| Solo `XEPDB1` | A5.12, A5.15, A5.16, A5.17/A8.5 (perfiles), A5.18, A8.2, A8.3 (VPD), A8.10, A8.11 (Redaction), A8.12, A8.15 (políticas) |
| Toda la instancia | A8.20 (`sqlnet.ora`), A8.24 (keystore TDE), A8.13 (configuración RMAN), `audit_sys_operations` |

---

## 7. Esquema de prueba propuesto (`AUDINC_DEMO`)

Datos ficticios con información personal protegida por la Ley 8968:
- `CLIENTES` (cédula, nombre, email, teléfono, dirección) → redaction + clasificación.
- `VENTAS` (id, vendedor, cliente, monto) → VPD por vendedor.
- `EMPLEADOS` (cédula, salario) → TDE de columna/tablespace.
- Roles: `VENDEDOR`, `AUDITOR`, `SUPERVISOR`. Usuarios de ejemplo: `JUAN` (vendedor), `ANA` (auditora).
