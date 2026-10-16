-- =====================================================================
-- AUDINC · 03_catalogo.sql                              (PHVA: Planificar)
-- Tablas del evaluador: riesgos, tareas, controles ISO, controles
-- observables, pruebas y el histórico de evaluaciones.
-- AUDINC_OWNER es schema-only: la aplicación nunca se conecta como dueña.
-- =====================================================================
CREATE USER audinc_owner NO AUTHENTICATION
  DEFAULT TABLESPACE users
  QUOTA 50M ON users;

CREATE TABLE audinc_owner.riesgo (
  id_riesgo    VARCHAR2(10)  CONSTRAINT riesgo_pk PRIMARY KEY,
  nombre       VARCHAR2(100) NOT NULL,
  dimension    VARCHAR2(30)  NOT NULL,
  escenario    VARCHAR2(400) NOT NULL,
  impacto      NUMBER(1)     NOT NULL CONSTRAINT riesgo_impacto_ck CHECK (impacto BETWEEN 1 AND 5),
  probabilidad NUMBER(1)     NOT NULL CONSTRAINT riesgo_prob_ck    CHECK (probabilidad BETWEEN 1 AND 5),
  nivel        NUMBER(2)     GENERATED ALWAYS AS (impacto * probabilidad) VIRTUAL
);

CREATE TABLE audinc_owner.control_iso (
  id_control     VARCHAR2(6)   CONSTRAINT control_iso_pk PRIMARY KEY,
  nombre         VARCHAR2(80)  NOT NULL,
  tema           VARCHAR2(15)  NOT NULL CONSTRAINT control_iso_tema_ck
                   CHECK (tema IN ('ORGANIZACIONAL','PERSONAS','FISICO','TECNOLOGICO')),
  justificacion  VARCHAR2(400) NOT NULL,
  implementacion VARCHAR2(400) NOT NULL,
  complementario CHAR(1) DEFAULT 'N' NOT NULL CONSTRAINT control_iso_comp_ck CHECK (complementario IN ('S','N'))
);

CREATE TABLE audinc_owner.tarea (
  id_tarea VARCHAR2(5)   CONSTRAINT tarea_pk PRIMARY KEY,
  nombre   VARCHAR2(100) NOT NULL
);

CREATE TABLE audinc_owner.tarea_riesgo (
  id_tarea  VARCHAR2(5)  CONSTRAINT tr_tarea_fk  REFERENCES audinc_owner.tarea,
  id_riesgo VARCHAR2(10) CONSTRAINT tr_riesgo_fk REFERENCES audinc_owner.riesgo,
  CONSTRAINT tarea_riesgo_pk PRIMARY KEY (id_tarea, id_riesgo)
);

CREATE TABLE audinc_owner.tarea_control (
  id_tarea   VARCHAR2(5) CONSTRAINT tc_tarea_fk   REFERENCES audinc_owner.tarea,
  id_control VARCHAR2(6) CONSTRAINT tc_control_fk REFERENCES audinc_owner.control_iso,
  CONSTRAINT tarea_control_pk PRIMARY KEY (id_tarea, id_control)
);

-- Cada consulta devuelve los HALLAZGOS (filas que incumplen):
-- 0 filas = el control se observa implementado.
CREATE TABLE audinc_owner.control_observable (
  id_co       VARCHAR2(5)   CONSTRAINT control_obs_pk PRIMARY KEY,
  id_control  VARCHAR2(6)   NOT NULL CONSTRAINT co_control_fk REFERENCES audinc_owner.control_iso,
  descripcion VARCHAR2(200) NOT NULL,
  consulta    CLOB          NOT NULL,
  criterio    VARCHAR2(200) NOT NULL
);

CREATE TABLE audinc_owner.prueba (
  id_prueba          VARCHAR2(6)   CONSTRAINT prueba_pk PRIMARY KEY,
  id_co              VARCHAR2(5)   CONSTRAINT prueba_co_fk REFERENCES audinc_owner.control_observable,
  tipo               VARCHAR2(15)  NOT NULL CONSTRAINT prueba_tipo_ck
                       CHECK (tipo IN ('CONSULTA','FUNCIONAL','CONFIGURACION')),
  procedimiento      VARCHAR2(400) NOT NULL,
  resultado_esperado VARCHAR2(200) NOT NULL,
  herramienta        VARCHAR2(80)  NOT NULL
);

-- Excepciones aprobadas (aceptación de riesgo, fase Actuar). Un hallazgo cuyo
-- primer valor coincide con OBJETO no cuenta mientras la excepción esté vigente.
-- Toda excepción vence: obliga a revisarla periódicamente.
CREATE TABLE audinc_owner.excepcion (
  id_excepcion      NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT excepcion_pk PRIMARY KEY,
  id_co             VARCHAR2(5)   NOT NULL CONSTRAINT excepcion_co_fk REFERENCES audinc_owner.control_observable,
  objeto            VARCHAR2(512) NOT NULL,
  justificacion     VARCHAR2(400) NOT NULL,
  control_compensatorio VARCHAR2(400),
  aprobado_por      VARCHAR2(80)  NOT NULL,
  fecha_aprobacion  DATE DEFAULT SYSDATE NOT NULL,
  fecha_vencimiento DATE NOT NULL,
  CONSTRAINT excepcion_uk UNIQUE (id_co, objeto),
  CONSTRAINT excepcion_vence_ck CHECK (fecha_vencimiento > fecha_aprobacion)
);

CREATE TABLE audinc_owner.evaluacion (
  id_evaluacion NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT evaluacion_pk PRIMARY KEY,
  fecha         TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  -- Usuario final (CLIENT_IDENTIFIER que fija la aplicación) o, si no hay, el usuario de BD
  usuario_bd    VARCHAR2(128) DEFAULT NVL(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),
                                          SYS_CONTEXT('USERENV','SESSION_USER')) NOT NULL,
  observaciones VARCHAR2(400)
);

CREATE TABLE audinc_owner.evaluacion_detalle (
  id_evaluacion NUMBER      CONSTRAINT ed_evaluacion_fk REFERENCES audinc_owner.evaluacion,
  id_co         VARCHAR2(5) CONSTRAINT ed_co_fk         REFERENCES audinc_owner.control_observable,
  hallazgos     NUMBER,     -- NULL = la consulta de evidencia no se pudo ejecutar
  evidencia     CLOB        CONSTRAINT ed_evidencia_json_ck CHECK (evidencia IS JSON),
  nivel         NUMBER(1)   NOT NULL CONSTRAINT ed_nivel_ck  CHECK (nivel BETWEEN 0 AND 4),
  estado        VARCHAR2(10) NOT NULL CONSTRAINT ed_estado_ck CHECK (estado IN ('Cumple','Parcial','No cumple')),
  justificacion VARCHAR2(400),
  CONSTRAINT evaluacion_detalle_pk PRIMARY KEY (id_evaluacion, id_co)
);

-- Matriz de evaluación del enunciado: Tarea | Riesgo | Control | Criterio 0-4 | Evidencia | Estado
-- (toma el resultado de la última evaluación registrada)
CREATE VIEW audinc_owner.v_matriz AS
SELECT t.id_tarea,
       t.nombre AS tarea,
       (SELECT LISTAGG(tr.id_riesgo, ', ') WITHIN GROUP (ORDER BY tr.id_riesgo)
          FROM audinc_owner.tarea_riesgo tr
         WHERE tr.id_tarea = t.id_tarea) AS riesgos,
       tc.id_control,
       ci.nombre AS control,
       co.id_co,
       co.criterio,
       d.nivel,
       d.hallazgos,
       d.estado,
       d.id_evaluacion
FROM   audinc_owner.tarea t
JOIN   audinc_owner.tarea_control tc      ON tc.id_tarea   = t.id_tarea
JOIN   audinc_owner.control_iso ci        ON ci.id_control = tc.id_control
LEFT JOIN audinc_owner.control_observable co ON co.id_control = tc.id_control
LEFT JOIN (SELECT ed.*
             FROM audinc_owner.evaluacion_detalle ed
            WHERE ed.id_evaluacion = (SELECT MAX(id_evaluacion) FROM audinc_owner.evaluacion)) d
       ON d.id_co = co.id_co;
