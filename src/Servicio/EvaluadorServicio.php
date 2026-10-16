<?php
declare(strict_types=1);

namespace Audinc\Servicio;

use Audinc\BaseDatosException;
use Audinc\Database;
use Audinc\Repositorio\CatalogoRepositorio;
use Audinc\Repositorio\EvaluacionRepositorio;
use Throwable;

/**
 * Ejecuta las consultas de evidencia de cada control observable, califica
 * con el criterio de madurez 0-4 y guarda la evaluación completa en una
 * sola transacción (fase Verificar del PHVA).
 */
final class EvaluadorServicio
{
    public function __construct(
        private readonly Database $db,
        private readonly CatalogoRepositorio $catalogo,
        private readonly EvaluacionRepositorio $evaluaciones,
        private readonly int $maxFilasEvidencia
    ) {
    }

    public function evaluar(?string $observaciones): array
    {
        $lineaBase = $this->evaluaciones->hallazgosPorControl($this->evaluaciones->primeraId());
        $anterior  = $this->evaluaciones->hallazgosPorControl($this->evaluaciones->ultimaId());

        $excepciones = $this->catalogo->excepcionesVigentes();

        $resultados = [];
        foreach ($this->catalogo->controlesObservables() as $control) {
            $idCo = $control['id_co'];
            try {
                $tabla = $this->db->consultarTabla($control['consulta'], $this->maxFilasEvidencia);
                $evidencia = self::aplicarExcepciones($tabla, $excepciones[$idCo] ?? []);
                $hallazgos = $evidencia['total'];
            } catch (BaseDatosException $e) {
                error_log("AUDINC {$idCo}: " . $e->detalle());
                $hallazgos = null;
                $evidencia = ['error' => $e->codigoOra()];
            }

            [$nivel, $estado, $justificacion] = self::calificar(
                $hallazgos,
                $anterior[$idCo] ?? null,
                $lineaBase[$idCo] ?? null,
                count($evidencia['exceptuados'] ?? [])
            );

            $resultados[] = [
                'id_co'         => $idCo,
                'id_control'    => $control['id_control'],
                'descripcion'   => $control['descripcion'],
                'hallazgos'     => $hallazgos,
                'nivel'         => $nivel,
                'estado'        => $estado,
                'justificacion' => $justificacion,
                'evidencia'     => $evidencia,
            ];
        }

        try {
            $idEvaluacion = $this->evaluaciones->crear($observaciones);
            foreach ($resultados as $r) {
                $this->evaluaciones->agregarDetalle(
                    $idEvaluacion,
                    $r['id_co'],
                    $r['hallazgos'],
                    json_encode($r['evidencia'], JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
                    $r['nivel'],
                    $r['estado'],
                    $r['justificacion']
                );
            }
            $this->db->commit();
        } catch (Throwable $e) {
            $this->db->rollback();
            throw $e;
        }

        return $this->evaluaciones->obtener($idEvaluacion);
    }

    /**
     * Separa los hallazgos cubiertos por una excepción vigente. Se compara el primer
     * valor de la fila con EXCEPCION.OBJETO: igualdad exacta, o prefijo si OBJETO
     * termina en '%' (p. ej. 'C:\BACKUPGUARD_RMAN\%'). Siguen visibles en la evidencia.
     *
     * @param array{columnas: string[], filas: array[], total: int} $tabla
     * @param array<string, true> $objetosExceptuados
     */
    public static function aplicarExcepciones(array $tabla, array $objetosExceptuados): array
    {
        $prefijos = [];
        foreach (array_keys($objetosExceptuados) as $objeto) {
            if (str_ends_with((string) $objeto, '%')) {
                $prefijos[] = substr((string) $objeto, 0, -1);
            }
        }

        $filas = [];
        $exceptuados = [];
        foreach ($tabla['filas'] as $fila) {
            $valor = (string) ($fila[0] ?? '');
            $cubierto = isset($objetosExceptuados[$valor]);
            foreach ($prefijos as $prefijo) {
                $cubierto = $cubierto || ($prefijo !== '' && str_starts_with($valor, $prefijo));
            }
            if ($cubierto) {
                $exceptuados[] = $fila;
            } else {
                $filas[] = $fila;
            }
        }
        return [
            'columnas'    => $tabla['columnas'],
            'filas'       => $filas,
            'exceptuados' => $exceptuados,
            'total'       => $tabla['total'] - count($exceptuados),
        ];
    }

    /**
     * Criterio de madurez 0-4 (docs/catalogo_controles.md §5):
     *   0  No se pudo obtener evidencia                         -> No cumple
     *   1  Hay hallazgos y no hay mejora respecto a la línea base -> No cumple
     *   2  Hay hallazgos, pero menos que en la línea base         -> Parcial
     *   3  0 hallazgos                                            -> Cumple
     *   4  0 hallazgos en esta y en la evaluación anterior,
     *      sin depender de excepciones                            -> Cumple
     * Un riesgo aceptado (excepción) no equivale a un control implementado:
     * con excepciones el nivel máximo es 3.
     *
     * @return array{0: int, 1: string, 2: string}
     */
    public static function calificar(?int $hallazgos, ?int $anterior, ?int $lineaBase, int $exceptuados = 0): array
    {
        if ($hallazgos === null) {
            return [0, 'No cumple', 'No se pudo ejecutar la consulta de evidencia'];
        }
        $nota = $exceptuados > 0 ? " ({$exceptuados} exceptuado(s) por excepción aprobada vigente)" : '';
        if ($hallazgos === 0) {
            if ($exceptuados > 0) {
                return [3, 'Cumple', 'Sin hallazgos fuera de excepciones' . $nota];
            }
            return $anterior === 0
                ? [4, 'Cumple', 'Sin hallazgos en esta evaluación ni en la anterior (control sostenido)']
                : [3, 'Cumple', 'Sin hallazgos'];
        }
        if ($lineaBase !== null && $hallazgos < $lineaBase) {
            return [2, 'Parcial', "{$hallazgos} hallazgo(s); la línea base tenía {$lineaBase}" . $nota];
        }
        return [1, 'No cumple', "{$hallazgos} hallazgo(s) sin mejora respecto a la línea base" . $nota];
    }
}
