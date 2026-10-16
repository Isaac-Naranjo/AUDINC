-- =====================================================================
-- AC-02 · Acción correctiva: cuentas ajenas y riesgos aceptados (PHVA: Actuar)
-- Controles: CO-03 (A5.16), CO-07 (A8.2), CO-09 (A8.5), CO-13 (A8.13)
--
-- Tras aplicar 01_controles persistían hallazgos sobre objetos AJENOS a
-- AUDINC que comparten la instancia XE:
--   * PDBADMIN    -> creado por el instalador de XE, nunca usado: se BLOQUEA.
--   * C##BGBACKUP -> usuario de otro proyecto (BackupGuard): se acepta el
--                    riesgo con excepción justificada y vencimiento.
--   * Respaldos RMAN sin cifrar de BackupGuard y configuración RMAN de toda
--     la instancia -> cifrarlos afectaría a BackupGuard: riesgo aceptado.
-- Toda excepción vence a los 3 meses y debe revisarse (A5.15 / A5.18).
-- Ejecutar como SYS AS SYSDBA.
-- =====================================================================
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ALTER SESSION SET CONTAINER = XEPDB1;

-- Corrección: cuenta sin uso -> baja lógica (reversible con ACCOUNT UNLOCK)
ALTER USER pdbadmin ACCOUNT LOCK;

-- Riesgos aceptados
INSERT INTO audinc_owner.excepcion
  (id_co, objeto, justificacion, control_compensatorio, aprobado_por, fecha_vencimiento)
VALUES
  ('CO-03', 'C##BGBACKUP',
   'Usuario común del proyecto BackupGuard (misma instancia XE); opera desde CDB$ROOT, no inicia sesión en XEPDB1.',
   'Solo CREATE SESSION + SELECT_CATALOG_ROLE; intentos fallidos auditados por ORA_LOGON_FAILURES.',
   'Isaac Naranjo (responsable AUDINC)', ADD_MONTHS(SYSDATE, 3));

INSERT INTO audinc_owner.excepcion
  (id_co, objeto, justificacion, control_compensatorio, aprobado_por, fecha_vencimiento)
VALUES
  ('CO-09', 'C##BGBACKUP',
   'Usuario común: su perfil se administra desde CDB$ROOT y pertenece a otro proyecto.',
   'Sin privilegios sobre datos de negocio de XEPDB1.',
   'Isaac Naranjo (responsable AUDINC)', ADD_MONTHS(SYSDATE, 3));

INSERT INTO audinc_owner.excepcion
  (id_co, objeto, justificacion, control_compensatorio, aprobado_por, fecha_vencimiento)
VALUES
  ('CO-07', 'C##BGBACKUP',
   'BackupGuard requiere privilegio administrativo para ejecutar RMAN.',
   'Usa SYSBACKUP (el privilegio administrativo mínimo para respaldos) en lugar de SYSDBA; sus operaciones SYS se auditan (audit_sys_operations = TRUE).',
   'Isaac Naranjo (responsable AUDINC)', ADD_MONTHS(SYSDATE, 3));

INSERT INTO audinc_owner.excepcion
  (id_co, objeto, justificacion, control_compensatorio, aprobado_por, fecha_vencimiento)
VALUES
  ('CO-13', 'RMAN: ENCRYPTION FOR DATABASE',
   'La configuración RMAN es de toda la instancia; activarla cifraría también los respaldos de BackupGuard y haría depender su restauración de un keystore TDE que aún no existe.',
   'Los respaldos se guardan localmente en un equipo de uso personal; XEPDB1 solo contiene datos ficticios. Revisar al implementar A8.24 (TDE).',
   'Isaac Naranjo (responsable AUDINC)', ADD_MONTHS(SYSDATE, 3));

INSERT INTO audinc_owner.excepcion
  (id_co, objeto, justificacion, control_compensatorio, aprobado_por, fecha_vencimiento)
VALUES
  ('CO-13', 'C:\BACKUPGUARD_RMAN\%',
   'Respaldos generados por el proyecto BackupGuard; AUDINC no debe modificarlos ni eliminarlos.',
   'Ubicación local; contienen XEPDB1 solo con datos ficticios.',
   'Isaac Naranjo (responsable AUDINC)', ADD_MONTHS(SYSDATE, 3));

COMMIT;

SELECT id_co, objeto, TO_CHAR(fecha_vencimiento, 'YYYY-MM-DD') AS vence
FROM   audinc_owner.excepcion
ORDER  BY id_co, objeto;
