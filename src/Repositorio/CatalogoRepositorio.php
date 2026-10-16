<?php
declare(strict_types=1);

namespace Audinc\Repositorio;

use Audinc\Database;

/**
 * Lectura del catálogo (AUDINC_OWNER). La cuenta AUDINC_APP solo tiene SELECT,
 * así que este repositorio no puede modificar qué se evalúa.
 */
final class CatalogoRepositorio
{
    // Ordena A5.9 < A5.12 < A8.2 < A8.10 (orden numérico, no alfabético)
    private const ORDEN_CONTROL = "TO_NUMBER(REGEXP_SUBSTR(%1\$s, '\\d+', 1, 1)), TO_NUMBER(REGEXP_SUBSTR(%1\$s, '\\d+', 1, 2))";

    public function __construct(private readonly Database $db)
    {
    }

    public function riesgos(): array
    {
        // La clasificación se calcula en PHP: en 21c XE, seleccionar NIVEL junto a un
        // CASE que la referencia devolvía NIVEL = NULL en las filas de la primera rama.
        $filas = Numeros::enteros($this->db->consultar(
            'SELECT id_riesgo, nombre, dimension, escenario, impacto, probabilidad, nivel
               FROM audinc_owner.riesgo
              ORDER BY id_riesgo'
        ), ['impacto', 'probabilidad', 'nivel']);
        foreach ($filas as &$fila) {
            $fila['clasificacion'] = match (true) {
                $fila['nivel'] >= 15 => 'Alto',
                $fila['nivel'] >= 8  => 'Medio',
                default              => 'Bajo',
            };
        }
        return $filas;
    }

    public function tareas(): array
    {
        return array_map(static function (array $fila): array {
            $fila['riesgos']   = $fila['riesgos']   ? explode(',', $fila['riesgos'])   : [];
            $fila['controles'] = $fila['controles'] ? explode(',', $fila['controles']) : [];
            return $fila;
        }, $this->db->consultar(
            'SELECT t.id_tarea, t.nombre,
                    (SELECT LISTAGG(id_riesgo, \',\') WITHIN GROUP (ORDER BY id_riesgo)
                       FROM audinc_owner.tarea_riesgo tr WHERE tr.id_tarea = t.id_tarea) AS riesgos,
                    (SELECT LISTAGG(id_control, \',\') WITHIN GROUP (ORDER BY ' . sprintf(self::ORDEN_CONTROL, 'id_control') . ')
                       FROM audinc_owner.tarea_control tc WHERE tc.id_tarea = t.id_tarea) AS controles
               FROM audinc_owner.tarea t
              ORDER BY t.id_tarea'
        ));
    }

    public function controlesIso(): array
    {
        return $this->db->consultar(
            'SELECT id_control, nombre, tema, justificacion, implementacion, complementario
               FROM audinc_owner.control_iso
              ORDER BY ' . sprintf(self::ORDEN_CONTROL, 'id_control')
        );
    }

    public function controlesObservables(): array
    {
        return $this->db->consultar(
            'SELECT co.id_co, co.id_control, ci.nombre AS control, co.descripcion, co.criterio, co.consulta,
                    ci.complementario
               FROM audinc_owner.control_observable co
               JOIN audinc_owner.control_iso ci ON ci.id_control = co.id_control
              ORDER BY co.id_co'
        );
    }

    public function pruebas(): array
    {
        return $this->db->consultar(
            'SELECT id_prueba, id_co, tipo, procedimiento, resultado_esperado, herramienta
               FROM audinc_owner.prueba
              ORDER BY id_prueba'
        );
    }

    public function excepciones(): array
    {
        return $this->db->consultar(
            "SELECT id_excepcion, id_co, objeto, justificacion, control_compensatorio, aprobado_por,
                    fecha_aprobacion, fecha_vencimiento,
                    CASE WHEN fecha_vencimiento >= SYSDATE THEN 'Vigente' ELSE 'Vencida' END AS estado
               FROM audinc_owner.excepcion
              ORDER BY id_co, objeto"
        );
    }

    /** @return array<string, array<string, true>> id_co => [objeto => true] (solo vigentes) */
    public function excepcionesVigentes(): array
    {
        $resultado = [];
        foreach ($this->db->consultar(
            'SELECT id_co, objeto FROM audinc_owner.excepcion WHERE fecha_vencimiento >= SYSDATE'
        ) as $fila) {
            $resultado[$fila['id_co']][$fila['objeto']] = true;
        }
        return $resultado;
    }

    /** Matriz del enunciado: Tarea | Riesgo | Control | Criterio 0-4 | Evidencia | Estado */
    public function matriz(): array
    {
        $filas = $this->db->consultar(
            'SELECT id_tarea, tarea, riesgos, id_control, control, id_co, criterio,
                    nivel, hallazgos, estado, id_evaluacion
               FROM audinc_owner.v_matriz
              ORDER BY id_tarea, ' . sprintf(self::ORDEN_CONTROL, 'id_control') . ', id_co'
        );
        return Numeros::enteros($filas, ['nivel', 'hallazgos', 'id_evaluacion']);
    }
}
