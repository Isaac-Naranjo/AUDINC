-- =====================================================================
-- A5.12 Clasificación de la información                       (PHVA: Hacer)
-- Riesgo: R-CONF-03 · Tarea: T-05 · Verificación: CO-01 / PT-01
-- Las columnas con datos personales (Ley 8968) se etiquetan [CONFIDENCIAL].
-- La etiqueta es la base para decidir qué se enmascara (A8.11).
-- =====================================================================
COMMENT ON COLUMN audinc_demo.clientes.cedula    IS '[CONFIDENCIAL] Identificación personal (Ley 8968)';
COMMENT ON COLUMN audinc_demo.clientes.email     IS '[CONFIDENCIAL] Dato de contacto personal';
COMMENT ON COLUMN audinc_demo.clientes.telefono  IS '[CONFIDENCIAL] Dato de contacto personal';
COMMENT ON COLUMN audinc_demo.clientes.direccion IS '[CONFIDENCIAL] Domicilio';
COMMENT ON COLUMN audinc_demo.empleados.cedula   IS '[CONFIDENCIAL] Identificación personal (Ley 8968)';
COMMENT ON COLUMN audinc_demo.empleados.salario  IS '[CONFIDENCIAL] Información salarial';

COMMENT ON TABLE audinc_demo.clientes  IS 'Contiene datos personales. Clasificación: CONFIDENCIAL';
COMMENT ON TABLE audinc_demo.empleados IS 'Contiene datos personales y salariales. Clasificación: CONFIDENCIAL';
COMMENT ON TABLE audinc_demo.ventas    IS 'Datos comerciales. Clasificación: USO INTERNO';
