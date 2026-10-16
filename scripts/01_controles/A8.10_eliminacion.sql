-- =====================================================================
-- A8.10 Eliminación de información                            (PHVA: Hacer)
-- Riesgo: R-CONF-04 · Tarea: T-10 · Verificación: CO-10
-- Una tabla eliminada con DROP sin PURGE queda recuperable en la papelera
-- (FLASHBACK TABLE ... TO BEFORE DROP). Se purgan las del esquema de negocio.
-- Procedimiento a partir de ahora: DROP TABLE ... PURGE para datos sensibles.
-- =====================================================================
BEGIN
  FOR r IN (SELECT object_name, original_name
              FROM dba_recyclebin
             WHERE owner = 'AUDINC_DEMO'
               AND type = 'TABLE') LOOP
    EXECUTE IMMEDIATE 'PURGE TABLE audinc_demo."' || r.object_name || '"';
    DBMS_OUTPUT.PUT_LINE('Purgada: ' || r.original_name);
  END LOOP;
END;
/
