-- =====================================================================
-- A5.15 Control de acceso · A5.18 Derechos de acceso ·
-- A8.2 Derechos de acceso privilegiados                       (PHVA: Hacer)
-- Riesgo: R-CONF-01 · Tarea: T-02 · Verificación: CO-02, CO-05, CO-07
-- Principio de mínimo privilegio: los accesos se conceden solo por rol.
-- =====================================================================

-- A5.15: nadie accede a datos personales "por defecto"
REVOKE SELECT ON audinc_demo.clientes FROM PUBLIC;

-- A5.18: JUAN es vendedor; su acceso viene del rol VENDEDOR, no de grants sueltos
REVOKE SELECT ON audinc_demo.empleados FROM juan;

-- A8.2: un supervisor no necesita leer CUALQUIER tabla de la base;
-- su rol SUPERVISOR ya le da lo necesario sobre AUDINC_DEMO
REVOKE SELECT ANY TABLE FROM luis;
