-- =====================================================================
-- A8.11 Enmascaramiento de datos                              (PHVA: Hacer)
-- Riesgo: R-CONF-03 · Tarea: T-05 · Verificación: CO-11 / PT-17
-- Oracle Data Redaction: oculta en tiempo de consulta las columnas
-- clasificadas [CONFIDENCIAL] (A5.12) a todo usuario que no tenga el rol
-- SUPERVISOR. El dato almacenado no cambia.
-- =====================================================================

-- CLIENTES ------------------------------------------------------------
BEGIN
  -- Cédula 9-0101-0001  ->  *-****-0001
  DBMS_REDACT.ADD_POLICY(
    object_schema       => 'AUDINC_DEMO',
    object_name         => 'CLIENTES',
    policy_name         => 'RED_CLIENTES',
    column_name         => 'CEDULA',
    function_type       => DBMS_REDACT.PARTIAL,
    function_parameters => 'VFVVVVFVVVV,V-VVVV-VVVV,*,1,5',
    expression          => 'SYS_CONTEXT(''SYS_SESSION_ROLES'', ''SUPERVISOR'') = ''FALSE'''
  );

  -- Teléfono 8800-0001  ->  ****-0001
  DBMS_REDACT.ALTER_POLICY(
    object_schema       => 'AUDINC_DEMO',
    object_name         => 'CLIENTES',
    policy_name         => 'RED_CLIENTES',
    action              => DBMS_REDACT.ADD_COLUMN,
    column_name         => 'TELEFONO',
    function_type       => DBMS_REDACT.PARTIAL,
    function_parameters => 'VVVVFVVVV,VVVV-VVVV,*,1,4'
  );

  -- Email laura.mora@ejemplo.com  ->  xxxx@ejemplo.com
  DBMS_REDACT.ALTER_POLICY(
    object_schema         => 'AUDINC_DEMO',
    object_name           => 'CLIENTES',
    policy_name           => 'RED_CLIENTES',
    action                => DBMS_REDACT.ADD_COLUMN,
    column_name           => 'EMAIL',
    function_type         => DBMS_REDACT.REGEXP,
    regexp_pattern        => DBMS_REDACT.RE_PATTERN_EMAIL_ADDRESS,
    regexp_replace_string => DBMS_REDACT.RE_REDACT_EMAIL_NAME,
    regexp_position       => DBMS_REDACT.RE_BEGINNING,
    regexp_occurrence     => DBMS_REDACT.RE_ALL
  );

  -- Dirección: ocultamiento total
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'AUDINC_DEMO',
    object_name   => 'CLIENTES',
    policy_name   => 'RED_CLIENTES',
    action        => DBMS_REDACT.ADD_COLUMN,
    column_name   => 'DIRECCION',
    function_type => DBMS_REDACT.FULL
  );
END;
/

-- EMPLEADOS -----------------------------------------------------------
BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema       => 'AUDINC_DEMO',
    object_name         => 'EMPLEADOS',
    policy_name         => 'RED_EMPLEADOS',
    column_name         => 'CEDULA',
    function_type       => DBMS_REDACT.PARTIAL,
    function_parameters => 'VFVVVVFVVVV,V-VVVV-VVVV,*,1,5',
    expression          => 'SYS_CONTEXT(''SYS_SESSION_ROLES'', ''SUPERVISOR'') = ''FALSE'''
  );

  -- Salario -> 0
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'AUDINC_DEMO',
    object_name   => 'EMPLEADOS',
    policy_name   => 'RED_EMPLEADOS',
    action        => DBMS_REDACT.ADD_COLUMN,
    column_name   => 'SALARIO',
    function_type => DBMS_REDACT.FULL
  );
END;
/
