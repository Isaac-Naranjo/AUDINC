<?php
declare(strict_types=1);

namespace Audinc\Repositorio;

use Audinc\Database;

/**
 * Datos agregados para la pantalla de inicio: estado de la última evaluación,
 * evolución histórica, cobertura de cada riesgo, cuentas de usuario auditadas
 * y excepciones por vencer.
 */
final class ResumenRepositorio
{
    private const DIAS_AVISO_VENCIMIENTO = 30;

    public function __construct(
        private readonly Database $db,
        private readonly EvaluacionRepositorio $evaluaciones,
        private readonly CuentasRepositorio $cuentas
    ) {
    }

    public function resumen(): array
    {
        $historial = array_reverse($this->evaluaciones->listar());   // más antigua primero
        $ultima    = $historial === [] ? null : $historial[count($historial) - 1];

        return [
            'ultima_evaluacion' => $ultima,
            'evolucion'         => $historial,
            'riesgos'           => $ultima ? $this->coberturaRiesgos($ultima['id_evaluacion']) : [],
            'pendientes'        => $ultima ? $this->pendientes($ultima['id_evaluacion']) : [],
            'cuentas'           => $this->cuentas->totales(),
            'excepciones'       => $this->excepciones(),
        ];
    }

    /** Por riesgo: cuántos controles observables lo mitigan y cuántos cumplen. */
    private function coberturaRiesgos(int $idEvaluacion): array
    {
        // impacto * probabilidad se calcula aquí: ver nota sobre NIVEL en CatalogoRepositorio::riesgos()
        $filas = $this->db->consultar(
            "SELECT r.id_riesgo, r.nombre, r.impacto * r.probabilidad AS nivel,
                    COUNT(DISTINCT co.id_co) AS controles,
                    COUNT(DISTINCT CASE WHEN d.estado = 'Cumple'    THEN co.id_co END) AS cumplen,
                    COUNT(DISTINCT CASE WHEN d.estado = 'Parcial'   THEN co.id_co END) AS parciales,
                    COUNT(DISTINCT CASE WHEN d.estado = 'No cumple' THEN co.id_co END) AS no_cumplen
               FROM audinc_owner.riesgo r
               JOIN audinc_owner.tarea_riesgo tr        ON tr.id_riesgo  = r.id_riesgo
               JOIN audinc_owner.tarea_control tc       ON tc.id_tarea   = tr.id_tarea
               JOIN audinc_owner.control_observable co  ON co.id_control = tc.id_control
               LEFT JOIN audinc_owner.evaluacion_detalle d
                      ON d.id_co = co.id_co AND d.id_evaluacion = :id
              GROUP BY r.id_riesgo, r.nombre, r.impacto, r.probabilidad
              ORDER BY nivel DESC, r.id_riesgo",
            [':id' => $idEvaluacion]
        );
        $filas = Numeros::enteros($filas, ['nivel', 'controles', 'cumplen', 'parciales', 'no_cumplen']);
        foreach ($filas as &$fila) {
            $fila['cobertura'] = $fila['controles'] > 0 ? round($fila['cumplen'] / $fila['controles'], 2) : 0.0;
        }
        return $filas;
    }

    /** Controles que no están en Cumple en la última evaluación. */
    private function pendientes(int $idEvaluacion): array
    {
        return Numeros::enteros($this->db->consultar(
            "SELECT d.id_co, co.id_control, co.descripcion, d.hallazgos, d.nivel, d.estado, d.justificacion
               FROM audinc_owner.evaluacion_detalle d
               JOIN audinc_owner.control_observable co ON co.id_co = d.id_co
              WHERE d.id_evaluacion = :id
                AND d.estado <> 'Cumple'
              ORDER BY d.nivel, d.id_co",
            [':id' => $idEvaluacion]
        ), ['hallazgos', 'nivel']);
    }

    private function excepciones(): array
    {
        $fila = $this->db->consultarUno(
            'SELECT COUNT(CASE WHEN fecha_vencimiento >= SYSDATE THEN 1 END) AS vigentes,
                    COUNT(CASE WHEN fecha_vencimiento <  SYSDATE THEN 1 END) AS vencidas,
                    COUNT(CASE WHEN fecha_vencimiento >= SYSDATE
                                AND fecha_vencimiento <  SYSDATE + :dias THEN 1 END) AS por_vencer,
                    MIN(CASE WHEN fecha_vencimiento >= SYSDATE THEN fecha_vencimiento END) AS proximo_vencimiento
               FROM audinc_owner.excepcion',
            [':dias' => self::DIAS_AVISO_VENCIMIENTO]
        );
        return Numeros::enteros([$fila], ['vigentes', 'vencidas', 'por_vencer'])[0];
    }
}
