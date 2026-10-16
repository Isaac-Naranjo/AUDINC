-- =====================================================================
-- A8.12 Prevención de fuga de datos                      (PHVA: Hacer) v2
-- Riesgo: R-CONF-04 · Tarea: T-12 · Verificación: CO-12
-- Por defecto PUBLIC puede escribir archivos en el servidor (UTL_FILE) y
-- enviar datos por red (UTL_HTTP, UTL_TCP, UTL_SMTP): una vía directa para
-- sacar información. (En XEPDB1 estos grants son locales: COMMON = NO.)
--
-- v1 revocaba directamente a PUBLIC e invalidó 123 objetos de componentes
-- de Oracle (MDSYS, XDB, CTXSYS...). Ver 03_correccion/AC-01_A8.12.md.
-- v2:
--   1. Concede el paquete de forma explícita a cada esquema mantenido por
--      Oracle que depende de él y no tiene grant propio.
--   2. Revoca a PUBLIC y recompila.
--   3. Si queda algún objeto inválido, revierte todo automáticamente.
-- =====================================================================
DECLARE
  v_invalidos_antes   NUMBER;
  v_invalidos_despues NUMBER;

  PROCEDURE revertir IS
  BEGIN
    FOR p IN (SELECT column_value AS paquete
                FROM TABLE(sys.odcivarchar2list('UTL_FILE', 'UTL_HTTP', 'UTL_TCP', 'UTL_SMTP'))) LOOP
      EXECUTE IMMEDIATE 'GRANT EXECUTE ON sys.' || p.paquete || ' TO PUBLIC';
    END LOOP;
    UTL_RECOMP.RECOMP_SERIAL();
  END;
BEGIN
  SELECT COUNT(*) INTO v_invalidos_antes FROM dba_objects WHERE status = 'INVALID';

  -- 1. Grants explícitos a los dependientes (solo esquemas de Oracle)
  FOR d IN (SELECT DISTINCT dep.owner, dep.referenced_name AS paquete
              FROM dba_dependencies dep
              JOIN dba_users u ON u.username = dep.owner AND u.oracle_maintained = 'Y'
             WHERE dep.referenced_owner IN ('SYS', 'PUBLIC')
               AND dep.referenced_name IN ('UTL_FILE', 'UTL_HTTP', 'UTL_TCP', 'UTL_SMTP')
               AND dep.owner <> 'SYS'
               AND NOT EXISTS (SELECT 1 FROM dba_tab_privs t
                                WHERE t.grantee = dep.owner
                                  AND t.owner = 'SYS'
                                  AND t.table_name = dep.referenced_name)) LOOP
    EXECUTE IMMEDIATE 'GRANT EXECUTE ON sys.' || d.paquete || ' TO ' || DBMS_ASSERT.ENQUOTE_NAME(d.owner);
    DBMS_OUTPUT.PUT_LINE('Grant explícito: ' || d.paquete || ' -> ' || d.owner);
  END LOOP;

  -- 2. Revocación a PUBLIC
  FOR p IN (SELECT table_name AS paquete
              FROM dba_tab_privs
             WHERE grantee = 'PUBLIC' AND owner = 'SYS'
               AND table_name IN ('UTL_FILE', 'UTL_HTTP', 'UTL_TCP', 'UTL_SMTP')) LOOP
    EXECUTE IMMEDIATE 'REVOKE EXECUTE ON sys.' || p.paquete || ' FROM PUBLIC';
    DBMS_OUTPUT.PUT_LINE('Revocado a PUBLIC: ' || p.paquete);
  END LOOP;

  UTL_RECOMP.RECOMP_SERIAL();

  -- 3. Verificación con reversión automática
  SELECT COUNT(*) INTO v_invalidos_despues FROM dba_objects WHERE status = 'INVALID';
  DBMS_OUTPUT.PUT_LINE('Objetos inválidos: antes = ' || v_invalidos_antes || ', después = ' || v_invalidos_despues);

  IF v_invalidos_despues > v_invalidos_antes THEN
    revertir;
    RAISE_APPLICATION_ERROR(-20012,
      'A8.12 revertido: la revocación dejó ' || (v_invalidos_despues - v_invalidos_antes) || ' objetos inválidos');
  END IF;
END;
/
