-- =====================================================================
-- AUDINC · 01_esquema_demo.sql                          (PHVA: Planificar)
-- Esquema de negocio ficticio con datos personales (Ley 8968).
-- AUDINC_DEMO es una cuenta "schema-only" (NO AUTHENTICATION): es dueña
-- de los objetos pero nadie puede iniciar sesión con ella (A5.16 / A8.2).
-- Todos los datos son FICTICIOS.
-- =====================================================================
CREATE USER audinc_demo NO AUTHENTICATION
  DEFAULT TABLESPACE users
  QUOTA 20M ON users;

CREATE TABLE audinc_demo.clientes (
  id_cliente     NUMBER        CONSTRAINT clientes_pk PRIMARY KEY,
  cedula         VARCHAR2(12)  NOT NULL CONSTRAINT clientes_cedula_uk UNIQUE,
  nombre         VARCHAR2(80)  NOT NULL,
  email          VARCHAR2(80),
  telefono       VARCHAR2(9),
  direccion      VARCHAR2(120),
  fecha_registro DATE DEFAULT SYSDATE NOT NULL
);

CREATE TABLE audinc_demo.ventas (
  id_venta   NUMBER       CONSTRAINT ventas_pk PRIMARY KEY,
  id_cliente NUMBER       NOT NULL CONSTRAINT ventas_cliente_fk REFERENCES audinc_demo.clientes,
  vendedor   VARCHAR2(30) NOT NULL,
  monto      NUMBER(12,2) NOT NULL,
  fecha      DATE DEFAULT SYSDATE NOT NULL
);

CREATE TABLE audinc_demo.empleados (
  id_empleado NUMBER        CONSTRAINT empleados_pk PRIMARY KEY,
  cedula      VARCHAR2(12)  NOT NULL,
  nombre      VARCHAR2(80)  NOT NULL,
  puesto      VARCHAR2(40)  NOT NULL,
  salario     NUMBER(12,2)  NOT NULL,
  usuario_bd  VARCHAR2(30)
);

INSERT INTO audinc_demo.clientes VALUES (1,  '9-0101-0001', 'Laura Mora Solano',      'laura.mora@ejemplo.com',    '8800-0001', 'Heredia, San Pablo',        DATE '2025-01-10');
INSERT INTO audinc_demo.clientes VALUES (2,  '9-0101-0002', 'Carlos Vega Rojas',      'carlos.vega@ejemplo.com',   '8800-0002', 'San Jose, Curridabat',      DATE '2025-02-14');
INSERT INTO audinc_demo.clientes VALUES (3,  '9-0101-0003', 'Mariana Ulate Pérez',    'mariana.ulate@ejemplo.com', '8800-0003', 'Alajuela, Grecia',          DATE '2025-03-02');
INSERT INTO audinc_demo.clientes VALUES (4,  '9-0101-0004', 'Diego Campos Arias',     'diego.campos@ejemplo.com',  '8800-0004', 'Cartago, Paraíso',          DATE '2025-03-21');
INSERT INTO audinc_demo.clientes VALUES (5,  '9-0101-0005', 'Sofía Brenes Quesada',   'sofia.brenes@ejemplo.com',  '8800-0005', 'Heredia, Santo Domingo',    DATE '2025-04-05');
INSERT INTO audinc_demo.clientes VALUES (6,  '9-0101-0006', 'Andrés Jiménez Salas',   'andres.jimenez@ejemplo.com','8800-0006', 'San Jose, Escazú',          DATE '2025-05-18');
INSERT INTO audinc_demo.clientes VALUES (7,  '9-0101-0007', 'Valeria Chaves Mora',    'valeria.chaves@ejemplo.com','8800-0007', 'Puntarenas, Esparza',       DATE '2025-06-30');
INSERT INTO audinc_demo.clientes VALUES (8,  '9-0101-0008', 'José Hidalgo Vargas',    'jose.hidalgo@ejemplo.com',  '8800-0008', 'Guanacaste, Liberia',       DATE '2025-07-12');
INSERT INTO audinc_demo.clientes VALUES (9,  '9-0101-0009', 'Daniela Soto Céspedes',  'daniela.soto@ejemplo.com',  '8800-0009', 'Limón, Guápiles',           DATE '2025-08-25');
INSERT INTO audinc_demo.clientes VALUES (10, '9-0101-0010', 'Fernando Rojas Núñez',   'fernando.rojas@ejemplo.com','8800-0010', 'Heredia, Barva',            DATE '2025-09-09');

INSERT INTO audinc_demo.ventas VALUES (1,  1,  'JUAN',  125000.00, DATE '2026-01-15');
INSERT INTO audinc_demo.ventas VALUES (2,  2,  'JUAN',   48500.50, DATE '2026-02-03');
INSERT INTO audinc_demo.ventas VALUES (3,  3,  'PEDRO',  99900.00, DATE '2026-02-20');
INSERT INTO audinc_demo.ventas VALUES (4,  4,  'PEDRO', 310000.00, DATE '2026-03-11');
INSERT INTO audinc_demo.ventas VALUES (5,  5,  'JUAN',   15750.00, DATE '2026-04-01');
INSERT INTO audinc_demo.ventas VALUES (6,  6,  'PEDRO',  76000.00, DATE '2026-04-22');
INSERT INTO audinc_demo.ventas VALUES (7,  7,  'JUAN',  202500.00, DATE '2026-05-09');
INSERT INTO audinc_demo.ventas VALUES (8,  8,  'PEDRO',  54300.00, DATE '2026-06-17');
INSERT INTO audinc_demo.ventas VALUES (9,  9,  'JUAN',   88000.00, DATE '2026-07-28');
INSERT INTO audinc_demo.ventas VALUES (10, 10, 'PEDRO', 143200.00, DATE '2026-08-14');
INSERT INTO audinc_demo.ventas VALUES (11, 1,  'PEDRO',  27500.00, DATE '2026-09-02');
INSERT INTO audinc_demo.ventas VALUES (12, 5,  'JUAN',   66600.00, DATE '2026-09-30');

INSERT INTO audinc_demo.empleados VALUES (1, '9-0202-0001', 'Juan Pérez Alfaro',    'Vendedor',   650000.00, 'JUAN');
INSERT INTO audinc_demo.empleados VALUES (2, '9-0202-0002', 'Pedro Gómez Vindas',   'Vendedor',   640000.00, 'PEDRO');
INSERT INTO audinc_demo.empleados VALUES (3, '9-0202-0003', 'Isaac Naranjo',        'Auditor',    980000.00, 'ISAAC');
INSERT INTO audinc_demo.empleados VALUES (4, '9-0202-0004', 'Luis Araya Montero',   'Supervisor', 1150000.00,'LUIS');

COMMIT;
