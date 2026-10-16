# AUDINC — Evaluador de confidencialidad ISO/IEC 27001:2022 para Oracle

Proyecto del curso **EIF402 Administración de Bases de Datos** (Universidad Nacional, II ciclo 2026).
Evalúa controles del Anexo A de ISO/IEC 27001:2022 que mitigan riesgos de **confidencialidad** en Oracle Database 21c XE, con matriz de madurez 0-4 y evidencias observables, siguiendo el ciclo PHVA.

## Estructura

| Carpeta | Contenido | PHVA |
|---|---|---|
| `public/` | Punto de entrada web y recursos del front (única carpeta expuesta por el servidor) | — |
| `src/` | Backend PHP: conexión OCI8, repositorios y servicio de evaluación | Verificar |
| `config/` | `config.example.php` (plantilla); `config.local.php` con la contraseña, ignorado por git | — |
| `docs/` | Catálogo de riesgos, tareas, controles y pruebas | Planificar |
| `scripts/00_setup/` | Esquema de prueba, roles, catálogo y cuenta del evaluador | Planificar |
| `scripts/01_controles/` | Implementación de cada control | Hacer |
| `scripts/02_verificacion/` | Pruebas PT-xx | Verificar |
| `scripts/03_correccion/` | Ajustes tras las pruebas | Actuar |
| `scripts/99_limpieza.sql` | Deja la base como estaba | — |

## Requisitos

- Oracle Database 21c XE con la PDB `XEPDB1`
- SQL*Plus o SQL Developer, con conexión como `SYS AS SYSDBA`
- PHP 8.1 o superior con la extensión OCI8 habilitada en `php.ini` (`extension=oci8_19`). No requiere Apache, WAMP ni XAMPP.

## Instalación

```bash
cd scripts/00_setup
sqlplus / as sysdba @00_instalar.sql
```

El script pide dos contraseñas (`AUDINC_APP` y usuarios de prueba). Ninguna credencial se guarda en el repositorio.

> En SQL Developer: abrir `00_instalar.sql`, ejecutar como script (F5) y verificar que la codificación del editor sea **UTF-8** (Herramientas → Preferencias → Entorno → Codificación) para que los acentos se guarden correctamente.

Para reinstalar desde cero: `sqlplus / as sysdba @scripts/99_limpieza.sql`.

## Aplicar los controles (fase Hacer)

```bash
cd scripts/01_controles
sqlplus / as sysdba @00_aplicar_controles.sql
```

Aplica los controles internos de la base: clasificación (A5.12), privilegios (A5.15/A5.18/A8.2), cuentas (A5.16),
perfiles (A5.17/A8.5), VPD (A8.3), eliminación segura (A8.10), Data Redaction (A8.11), fuga de datos (A8.12)
y auditoría unificada (A8.15).

Requieren cambios fuera de la base y se aplican por separado, previa aprobación:
`A8.20_cifrado_red.md` (sqlnet.ora), `A8.24_tde.sql` (keystore y reinicio), `A8.13_respaldos.rman` (depende de TDE).

## Acciones correctivas (fase Actuar)

`scripts/03_correccion/`:
- `AC-01_A8.12.md`: incidente de la revocación de `UTL_*` a PUBLIC (123 objetos inválidos), su reversión y el rediseño del control.
- `AC-02_cuentas_y_excepciones.sql`: bloqueo de `PDBADMIN` y excepciones aprobadas, con vencimiento, para objetos de otro proyecto que comparte la instancia.

## Pruebas funcionales (fase Verificar)

```bash
cd scripts/02_verificacion
sqlplus /nolog @00_pruebas_funcionales.sql
```

Ejecuta PT-17 a PT-21 conectándose como cada usuario de prueba. Las salidas quedan en `evidencias/salidas/PT-xx_*.txt`.

Pruebas unitarias del evaluador (no requieren Oracle): `php tests/ejecutar_pruebas.php`

## Ejecutar el evaluador

1. Copiar `config/config.example.php` como `config/config.local.php` y escribir la contraseña de `AUDINC_APP`.
2. Desde la carpeta `AUDINC`:

   ```bash
   php -S localhost:8000 -t public public/index.php
   ```

3. Abrir `http://localhost:8000` e iniciar sesión con una cuenta Oracle con rol `AUDITOR` (en el entorno de prueba: `ANA`).

### Interfaz web

Menú lateral con: Inicio (resumen, evolución PHVA, cobertura por riesgo), Evaluaciones (con el detalle de la
evidencia de cada control), Matriz de evaluación (filtrable), Riesgos (mapa de calor), Tareas del DBA,
Controles ISO, Controles observables (con su consulta SQL), Batería de pruebas, Excepciones y Mi actividad.

- HTML, CSS y JavaScript propios, sin frameworks ni CDN (`public/assets/`); funciona sin conexión a internet.
- Política de seguridad de contenido estricta: solo recursos del propio servidor, sin scripts ni estilos en línea.
- Todo el contenido dinámico se inserta como texto (`textContent`), nunca como HTML, para evitar XSS con datos de la base.
- Adaptable a celular (el menú se convierte en panel deslizable) y con modo oscuro automático.

### Autenticación

El evaluador **no guarda contraseñas**: el usuario inicia sesión con su **cuenta de Oracle** y la aplicación
verifica la contraseña abriendo una sesión en Oracle. Solo entran cuentas con el rol `AUDITOR` (en el entorno
de prueba: `ANA`). Así se aplican a la aplicación los mismos controles del perfil `AUDINC_SEGURO`:
bloqueo tras 3 intentos, expiración, complejidad, y el registro de intentos fallidos (`ORA_LOGON_FAILURES`).

- Sesión PHP con cookie `HttpOnly` + `SameSite=Strict`, id regenerado al iniciar sesión, cierre por
  15 min de inactividad (igual al `IDLE_TIME` del perfil) y duración máxima de 8 h.
- Las consultas usan la cuenta de servicio `AUDINC_APP`, pero cada petición identifica al usuario final con
  `DBMS_SESSION.SET_IDENTIFIER`: Oracle lo registra en `UNIFIED_AUDIT_TRAIL.CLIENT_IDENTIFIER`
  (política `AUDINC_EVALUACIONES`) y queda como autor de cada evaluación.
- Mismo mensaje de error para usuario inexistente, contraseña incorrecta o cuenta bloqueada (no se puede saber si un usuario existe).

Prueba funcional: `php tests/PT-22_login.php` → `evidencias/salidas/PT-22_login.txt`.

### API

Todas las rutas `/api/*` requieren sesión, excepto `/api/sesion`.

| Método | Ruta | Devuelve |
|---|---|---|
| POST | `/api/sesion` | Inicia sesión. Cuerpo JSON: `{"usuario": "...", "contrasena": "..."}` |
| GET | `/api/sesion` | Sesión actual (usuario, inicio, acceso anterior) |
| DELETE | `/api/sesion` | Cierra sesión |
| GET | `/api/mi-actividad` | Estado de la propia cuenta, acceso anterior, intentos fallidos (30 días) y evaluaciones lanzadas |
| GET | `/api/resumen` | Última evaluación, evolución histórica, cobertura de cada riesgo, controles pendientes y excepciones por vencer |
| GET | `/api/riesgos` | Riesgos R-CONF con impacto, probabilidad, nivel y clasificación |
| GET | `/api/tareas` | Tareas del DBA con sus riesgos y controles |
| GET | `/api/controles` | Controles ISO/IEC 27001:2022 del Anexo A |
| GET | `/api/controles-observables` | Controles observables con su consulta de evidencia |
| GET | `/api/pruebas` | Batería de pruebas PT-01 … PT-21 |
| GET | `/api/matriz` | Matriz Tarea / Riesgo / Control / Criterio 0-4 / Estado (última evaluación) |
| GET | `/api/excepciones` | Excepciones aprobadas (aceptación de riesgo) con su vencimiento |
| GET | `/api/evaluaciones` | Histórico de evaluaciones con su resumen |
| GET | `/api/evaluaciones/{id}` | Detalle de una evaluación con la evidencia de cada control |
| POST | `/api/evaluaciones` | Ejecuta una evaluación nueva. Cuerpo JSON: `{"observaciones": "..."}` |

### Medidas de seguridad del backend

- Solo se expone `public/`; el código y las credenciales quedan fuera de la raíz web. Las rutas se validan con `realpath` (sin `../`).
- Cabeceras `Content-Security-Policy`, `X-Frame-Options`, `X-Content-Type-Options`, `Cache-Control: no-store`.
- Tiempo máximo de 30 s por llamada a Oracle.
- Todas las consultas usan variables bind.
- Los errores de Oracle se registran en el servidor; al cliente solo llega el código `ORA-xxxxx`.
- `POST` exige `Content-Type: application/json`, lo que impide que otra página dispare evaluaciones (CSRF).
- `AUDINC_APP` no tiene `UPDATE` ni `DELETE`: la evidencia guardada no se puede alterar (verificado: `ORA-01031`).

## Qué crea el setup

| Objeto | Tipo | Propósito |
|---|---|---|
| `AUDINC_DEMO` | Esquema sin login (`NO AUTHENTICATION`) | Datos de negocio **ficticios** con datos personales (Ley 8968) |
| `VENDEDOR`, `SUPERVISOR`, `AUDITOR` | Roles | Acceso por rol (A5.18) |
| `JUAN`, `PEDRO`, `ANA`, `LUIS`, `TEMPORAL` | Usuarios de prueba | Escenarios de las pruebas funcionales |
| `AUDINC_OWNER` | Esquema sin login | Catálogo y resultados de las evaluaciones |
| `AUDINC_EVALUADOR` / `AUDINC_APP` | Rol / usuario | Cuenta de solo lectura del evaluador (mínimo privilegio) |

El setup deja **brechas intencionales** (grant a `PUBLIC`, privilegio directo, `SELECT ANY TABLE`, cuenta sin uso, copia en la papelera) para que la primera evaluación muestre la línea base y los scripts de `01_controles/` demuestren la mejora.
