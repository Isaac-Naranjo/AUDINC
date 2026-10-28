-- =====================================================================
-- AC-04 · Acción correctiva: respaldos de BackupGuard fuera de su carpeta
-- (PHVA: Actuar) · Control: CO-13 (A8.13)
--
-- El 2026-10-19 BackupGuard generó piezas RMAN sin cifrar también en la
-- carpeta por defecto de Oracle (ORACLE_HOME\DATABASE), que la excepción
-- de AC-02 ('C:\BACKUPGUARD_RMAN\%') no cubre. BackupGuard ya fue
-- presentado y aprobado, y no generará más respaldos: se acepta el riesgo
-- con el mismo vencimiento que el resto de excepciones de BackupGuard.
-- Ejecutar como SYS AS SYSDBA.
-- =====================================================================
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ALTER SESSION SET CONTAINER = XEPDB1;

INSERT INTO audinc_owner.excepcion
  (id_co, objeto, justificacion, control_compensatorio, aprobado_por, fecha_vencimiento)
SELECT 'CO-13', 'C:\APP\ISAAC\PRODUCT\21C\DBHOMEXE\DATABASE\%',
       'Piezas RMAN de BackupGuard (2026-10-19) guardadas en la carpeta por defecto de Oracle; AUDINC no debe modificarlas ni eliminarlas. BackupGuard ya no genera respaldos.',
       'Ubicación local; contienen XEPDB1 solo con datos ficticios. Con A8.24 (TDE) los datos de AUDINC_DEMO quedan cifrados también dentro de los respaldos nuevos.',
       'Isaac Naranjo (responsable AUDINC)', MAX(fecha_vencimiento)
  FROM audinc_owner.excepcion
 WHERE objeto = 'C:\BACKUPGUARD_RMAN\%';

COMMIT;

SELECT id_co, objeto, TO_CHAR(fecha_vencimiento, 'YYYY-MM-DD') AS vence
FROM   audinc_owner.excepcion
ORDER  BY id_co, objeto;
