-- =====================================================================
-- AUDINC · 02_roles_usuarios.sql                        (PHVA: Planificar)
-- Roles de negocio y usuarios de prueba (pizarra: CREATE ROLE vendedor /
-- GRANT SELECT ... TO vendedor / GRANT vendedor TO juan).
--
-- La sección final crea BRECHAS INTENCIONALES: representan la línea base
-- típica de una base sin controles. El evaluador debe detectarlas y los
-- scripts de 01_controles/ las corrigen (fase Hacer).
-- =====================================================================
CREATE ROLE vendedor;
CREATE ROLE supervisor;
CREATE ROLE auditor;

GRANT CREATE SESSION TO vendedor;
GRANT CREATE SESSION TO supervisor;
GRANT CREATE SESSION TO auditor;

GRANT SELECT         ON audinc_demo.clientes  TO vendedor;
GRANT SELECT, INSERT ON audinc_demo.ventas    TO vendedor;

GRANT SELECT ON audinc_demo.clientes  TO supervisor;
GRANT SELECT ON audinc_demo.ventas    TO supervisor;
GRANT SELECT ON audinc_demo.empleados TO supervisor;

GRANT audit_viewer TO auditor;

CREATE USER juan  IDENTIFIED BY "&pwd_demo" DEFAULT TABLESPACE users;
CREATE USER pedro IDENTIFIED BY "&pwd_demo" DEFAULT TABLESPACE users;
CREATE USER isaac IDENTIFIED BY "&pwd_demo" DEFAULT TABLESPACE users;
CREATE USER luis  IDENTIFIED BY "&pwd_demo" DEFAULT TABLESPACE users;

GRANT vendedor   TO juan;
GRANT vendedor   TO pedro;
GRANT auditor    TO isaac;
GRANT supervisor TO luis;

-- ---------------------------------------------------------------------
-- BRECHAS INTENCIONALES (línea base sin controles)
-- ---------------------------------------------------------------------
-- CO-02 / A5.15: datos personales legibles por cualquier usuario
GRANT SELECT ON audinc_demo.clientes TO PUBLIC;

-- CO-05 / A5.18: privilegio de objeto otorgado directo al usuario, fuera de su rol
GRANT SELECT ON audinc_demo.empleados TO juan;

-- CO-07 / A8.2: privilegio ANY en una cuenta no administrativa
GRANT SELECT ANY TABLE TO luis;

-- CO-03 / A5.16: cuenta creada "por si acaso" y nunca utilizada
CREATE USER temporal IDENTIFIED BY "&pwd_demo" DEFAULT TABLESPACE users;
GRANT CREATE SESSION TO temporal;

-- CO-10 / A8.10: copia de datos personales "eliminada" pero recuperable
CREATE TABLE audinc_demo.clientes_copia AS SELECT * FROM audinc_demo.clientes;
DROP TABLE audinc_demo.clientes_copia;
