-- =====================================================================
-- A8.3 Restricción de acceso a la información                 (PHVA: Hacer)
-- Riesgo: R-CONF-01 · Tarea: T-02 · Verificación: CO-08 / PT-18
-- Virtual Private Database: cada vendedor ve y modifica solo sus ventas.
-- Los supervisores ven todas. La función de política vive en un esquema
-- propio (AUDINC_SEC) separado de los datos (separación de funciones).
-- =====================================================================
CREATE USER audinc_sec NO AUTHENTICATION;

-- Grant directo (los roles no aplican dentro de PL/SQL con derechos de definidor)
GRANT SELECT ON sys.dba_role_privs TO audinc_sec;

CREATE OR REPLACE FUNCTION audinc_sec.f_vpd_ventas (
  p_esquema IN VARCHAR2,
  p_objeto  IN VARCHAR2
) RETURN VARCHAR2
AS
  v_usuario    VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
  v_supervisor NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_supervisor
    FROM sys.dba_role_privs
   WHERE grantee = v_usuario
     AND granted_role = 'SUPERVISOR';

  IF v_supervisor > 0 THEN
    RETURN NULL;                                   -- sin restricción
  END IF;
  RETURN 'vendedor = SYS_CONTEXT(''USERENV'', ''SESSION_USER'')';
END;
/

BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema   => 'AUDINC_DEMO',
    object_name     => 'VENTAS',
    policy_name     => 'VPD_VENTAS_VENDEDOR',
    function_schema => 'AUDINC_SEC',
    policy_function => 'F_VPD_VENTAS',
    statement_types => 'SELECT, INSERT, UPDATE, DELETE',
    update_check    => TRUE                        -- no puede insertar ventas a nombre de otro
  );
END;
/
