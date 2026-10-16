<?php
declare(strict_types=1);

namespace Audinc\Repositorio;

use Audinc\Database;

/**
 * Histórico de evaluaciones. Solo INSERT y SELECT: la evidencia registrada
 * no se modifica ni se borra (AUDINC_APP no tiene UPDATE/DELETE).
 */
final class EvaluacionRepositorio
{
    public function __construct(private readonly Database $db)
    {
    }

    public function primeraId(): ?int
    {
        $fila = $this->db->consultarUno('SELECT MIN(id_evaluacion) AS id FROM audinc_owner.evaluacion');
        return $fila['id'] === null ? null : (int) $fila['id'];
    }

    public function ultimaId(): ?int
    {
        $fila = $this->db->consultarUno('SELECT MAX(id_evaluacion) AS id FROM audinc_owner.evaluacion');
        return $fila['id'] === null ? null : (int) $fila['id'];
    }

    /** @return array<string, ?int> id_co => hallazgos */
    public function hallazgosPorControl(?int $idEvaluacion): array
    {
        if ($idEvaluacion === null) {
            return [];
        }
        $resultado = [];
        foreach ($this->db->consultar(
            'SELECT id_co, hallazgos FROM audinc_owner.evaluacion_detalle WHERE id_evaluacion = :id',
            [':id' => $idEvaluacion]
        ) as $fila) {
            $resultado[$fila['id_co']] = $fila['hallazgos'] === null ? null : (int) $fila['hallazgos'];
        }
        return $resultado;
    }

    public function crear(?string $observaciones): int
    {
        return $this->db->insertarRetornandoId(
            'INSERT INTO audinc_owner.evaluacion (observaciones) VALUES (:obs)
             RETURNING id_evaluacion INTO :id',
            [':obs' => $observaciones]
        );
    }

    public function agregarDetalle(
        int $idEvaluacion,
        string $idCo,
        ?int $hallazgos,
        string $evidenciaJson,
        int $nivel,
        string $estado,
        string $justificacion
    ): void {
        $this->db->ejecutarConClob(
            'INSERT INTO audinc_owner.evaluacion_detalle
                    (id_evaluacion, id_co, hallazgos, evidencia, nivel, estado, justificacion)
             VALUES (:id, :co, :hallazgos, :evidencia, :nivel, :estado, :justificacion)',
            [
                ':id'            => $idEvaluacion,
                ':co'            => $idCo,
                ':hallazgos'     => $hallazgos,
                ':nivel'         => $nivel,
                ':estado'        => $estado,
                ':justificacion' => $justificacion,
            ],
            ':evidencia',
            $evidenciaJson
        );
    }

    public function listar(): array
    {
        $filas = $this->db->consultar(
            "SELECT e.id_evaluacion, e.fecha, e.usuario_bd, e.observaciones,
                    COUNT(CASE WHEN d.estado = 'Cumple'    THEN 1 END) AS cumple,
                    COUNT(CASE WHEN d.estado = 'Parcial'   THEN 1 END) AS parcial,
                    COUNT(CASE WHEN d.estado = 'No cumple' THEN 1 END) AS no_cumple,
                    ROUND(AVG(d.nivel), 2) AS nivel_promedio
               FROM audinc_owner.evaluacion e
               LEFT JOIN audinc_owner.evaluacion_detalle d ON d.id_evaluacion = e.id_evaluacion
              GROUP BY e.id_evaluacion, e.fecha, e.usuario_bd, e.observaciones
              ORDER BY e.id_evaluacion DESC"
        );
        $filas = Numeros::enteros($filas, ['id_evaluacion', 'cumple', 'parcial', 'no_cumple']);
        foreach ($filas as &$fila) {
            $fila['nivel_promedio'] = $fila['nivel_promedio'] === null ? null : (float) $fila['nivel_promedio'];
        }
        return $filas;
    }

    public function obtener(int $idEvaluacion): ?array
    {
        $cabecera = $this->db->consultarUno(
            'SELECT id_evaluacion, fecha, usuario_bd, observaciones
               FROM audinc_owner.evaluacion WHERE id_evaluacion = :id',
            [':id' => $idEvaluacion]
        );
        if ($cabecera === null) {
            return null;
        }
        $cabecera['id_evaluacion'] = (int) $cabecera['id_evaluacion'];

        $detalles = $this->db->consultar(
            'SELECT d.id_co, co.id_control, co.descripcion, co.criterio,
                    d.hallazgos, d.nivel, d.estado, d.justificacion, d.evidencia
               FROM audinc_owner.evaluacion_detalle d
               JOIN audinc_owner.control_observable co ON co.id_co = d.id_co
              WHERE d.id_evaluacion = :id
              ORDER BY d.id_co',
            [':id' => $idEvaluacion]
        );
        foreach ($detalles as &$detalle) {
            $detalle['evidencia'] = json_decode((string) $detalle['evidencia'], true);
        }
        $cabecera['detalles'] = Numeros::enteros($detalles, ['hallazgos', 'nivel']);
        return $cabecera;
    }
}
