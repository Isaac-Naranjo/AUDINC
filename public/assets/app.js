/* AUDINC · interfaz del evaluador
 * Seguridad: todo el contenido dinámico se inserta con textContent / nodos DOM
 * (nunca innerHTML con datos), porque la evidencia proviene de la base de datos.
 */
'use strict';

/* ======================================================================
 * Utilidades
 * ==================================================================== */

/** Crea un elemento. props: class, text, on<evento>, cualquier atributo. */
function h(etiqueta, props, ...hijos) {
  const el = document.createElement(etiqueta);
  for (const [clave, valor] of Object.entries(props || {})) {
    if (valor === null || valor === undefined || valor === false) continue;
    if (clave === 'class') el.className = valor;
    else if (clave === 'text') el.textContent = valor;
    else if (clave.startsWith('on')) el.addEventListener(clave.slice(2), valor);
    else el.setAttribute(clave, valor === true ? '' : String(valor));
  }
  for (const hijo of hijos.flat(Infinity)) {
    if (hijo === null || hijo === undefined || hijo === false) continue;
    el.append(hijo instanceof Node ? hijo : String(hijo));
  }
  return el;
}

const SVG = 'http://www.w3.org/2000/svg';
function s(etiqueta, atributos, ...hijos) {
  const el = document.createElementNS(SVG, etiqueta);
  for (const [clave, valor] of Object.entries(atributos || {})) el.setAttribute(clave, String(valor));
  for (const hijo of hijos) el.append(hijo instanceof Node ? hijo : document.createTextNode(String(hijo)));
  return el;
}

const $ = (selector) => document.querySelector(selector);

function claseEstado(estado) {
  return { 'Cumple': 'ok', 'Parcial': 'parcial', 'No cumple': 'mal',
    'Cumple con excepción': 'parcial', 'Exceptuado': 'parcial' }[estado] || '';
}

function etiquetaEstado(estado) {
  if (!estado) return h('span', { class: 'etiqueta', text: 'Sin evaluar' });
  return h('span', { class: `etiqueta ${claseEstado(estado)}`, text: estado });
}

function medidorNivel(nivel) {
  if (nivel === null || nivel === undefined) return h('span', { class: 'tenue', text: '—' });
  return h('span', { class: 'nivel', title: `Nivel de madurez ${nivel} de 4` },
    h('span', { class: `nivel-barras n${nivel}`, 'aria-hidden': 'true' }, h('i'), h('i'), h('i'), h('i')),
    h('b', { text: `${nivel}/4` }));
}

function claseRiesgo(nivel) {
  return nivel >= 15 ? 'mal' : nivel >= 8 ? 'parcial' : 'ok';
}

function chips(valores) {
  return h('span', { class: 'chips' }, (valores || []).map((v) => h('span', { class: 'chip', text: v })));
}

function fecha(valor) {
  return valor ? String(valor).slice(0, 16) : '—';
}

/**
 * Tabla genérica. columnas: [{ t: título, v: fila => nodo|texto, clase }]
 */
function tabla(columnas, filas, { vacio = 'Sin datos', claseFila } = {}) {
  if (!filas || filas.length === 0) {
    return h('div', { class: 'tabla-envoltura' }, h('div', { class: 'vacio', text: vacio }));
  }
  return h('div', { class: 'tabla-envoltura' },
    h('table', null,
      h('thead', null, h('tr', null, columnas.map((c) => h('th', { class: c.clase, text: c.t })))),
      h('tbody', null, filas.map((fila) =>
        h('tr', { class: claseFila ? claseFila(fila) : null },
          columnas.map((c) => {
            const valor = c.v(fila);
            return h('td', { class: c.clase }, valor === null || valor === undefined || valor === '' ? '—' : valor);
          }))))));
}

function tarjeta(titulo, subtitulo, ...contenido) {
  return h('section', { class: 'tarjeta' },
    titulo ? h('h3', { text: titulo }) : null,
    subtitulo ? h('p', { class: 'sub', text: subtitulo }) : null,
    contenido);
}

function aviso(texto, tipo = '') {
  const el = $('#aviso');
  if (!texto) { el.hidden = true; return; }
  el.className = `aviso ${tipo}`;
  el.textContent = texto;
  el.hidden = false;
}

/* ======================================================================
 * API
 * ==================================================================== */

class ErrorApi extends Error {
  constructor(estado, mensaje) { super(mensaje); this.estado = estado; }
}

async function api(metodo, ruta, cuerpo) {
  const opciones = { method: metodo, credentials: 'same-origin', headers: { Accept: 'application/json' } };
  if (cuerpo !== undefined) {
    opciones.headers['Content-Type'] = 'application/json';
    opciones.body = JSON.stringify(cuerpo);
  }
  const respuesta = await fetch(ruta, opciones);
  if (respuesta.status === 204) return null;
  let datos = null;
  try { datos = await respuesta.json(); } catch { /* respuesta sin JSON */ }
  if (!respuesta.ok) {
    if (respuesta.status === 401 && ruta !== '/api/sesion') {
      mostrarLogin('Su sesión expiró o no ha iniciado sesión.');
    }
    throw new ErrorApi(respuesta.status, (datos && datos.error) || `Error ${respuesta.status}`);
  }
  return datos;
}

/* ======================================================================
 * Sesión
 * ==================================================================== */

let usuarioActual = null;

function mostrarLogin(mensaje) {
  usuarioActual = null;
  $('#app').hidden = true;
  $('#login').hidden = false;
  const error = $('#login-error');
  error.hidden = !mensaje;
  error.textContent = mensaje || '';
  $('#login-contrasena').value = '';
  $('#login-usuario').focus();
}

async function mostrarApp(sesion) {
  usuarioActual = sesion.usuario;
  $('#usuario-nombre').textContent = sesion.usuario;
  $('#avatar').textContent = sesion.usuario.slice(0, 1);
  $('#login').hidden = true;
  $('#app').hidden = false;
  if (!location.hash || location.hash === '#/') location.hash = '#/inicio';
  else enrutar();
  avisoSeguridad();
}

/** Aviso al estilo bancario: último acceso e intentos fallidos desde entonces. */
async function avisoSeguridad() {
  try {
    const actividad = await api('GET', '/api/mi-actividad');
    const fallidos = actividad.intentos_fallidos_desde_ultimo_acceso;
    if (fallidos > 0) {
      aviso(`Atención: hubo ${fallidos} intento(s) fallido(s) de inicio de sesión con su cuenta desde su último acceso`
        + ` (${fecha(actividad.acceso_anterior)}). Revise "Mi actividad".`, 'mal');
    } else if (actividad.acceso_anterior) {
      aviso(`Último acceso: ${fecha(actividad.acceso_anterior)}. Sin intentos fallidos desde entonces.`, 'ok');
      setTimeout(() => aviso(''), 6000);
    }
  } catch { /* el aviso es informativo */ }
}

$('#form-login').addEventListener('submit', async (evento) => {
  evento.preventDefault();
  const boton = evento.submitter || $('#form-login button');
  const usuario = $('#login-usuario').value.trim();
  const contrasena = $('#login-contrasena').value;
  if (!usuario || !contrasena) {
    mostrarLogin('Escriba usuario y contraseña.');
    $('#login-usuario').value = usuario;
    return;
  }
  boton.disabled = true;
  try {
    const sesion = await api('POST', '/api/sesion', { usuario, contrasena });
    $('#login-contrasena').value = '';
    mostrarApp(sesion);
  } catch (e) {
    mostrarLogin(e.message);
    $('#login-usuario').value = usuario;
  } finally {
    boton.disabled = false;
  }
});

$('#boton-salir').addEventListener('click', async () => {
  try { await api('DELETE', '/api/sesion'); } catch { /* ya no hay sesión */ }
  aviso('');
  location.hash = '';
  mostrarLogin();
});

/* ======================================================================
 * Ejecutar evaluación
 * ==================================================================== */

const dialogo = $('#dialogo-evaluar');
$('#boton-evaluar').addEventListener('click', () => {
  $('#evaluar-observaciones').value = '';
  dialogo.showModal();
});
$('#evaluar-cancelar').addEventListener('click', () => dialogo.close());
$('#form-evaluar').addEventListener('submit', async (evento) => {
  evento.preventDefault();
  const boton = $('#evaluar-confirmar');
  boton.disabled = true;
  boton.textContent = 'Ejecutando…';
  try {
    const observaciones = $('#evaluar-observaciones').value.trim();
    const resultado = await api('POST', '/api/evaluaciones', { observaciones });
    dialogo.close();
    aviso(`Evaluación #${resultado.id_evaluacion} registrada.`, 'ok');
    location.hash = `#/evaluaciones/${resultado.id_evaluacion}`;
  } catch (e) {
    dialogo.close();
    if (e.estado !== 401) aviso(`No se pudo ejecutar la evaluación: ${e.message}`, 'mal');
  } finally {
    boton.disabled = false;
    boton.textContent = 'Ejecutar';
  }
});

/* ======================================================================
 * Vistas
 * ==================================================================== */

async function vistaInicio() {
  const r = await api('GET', '/api/resumen');
  const u = r.ultima_evaluacion;
  if (!u) {
    return [h('p', { class: 'intro', text: 'Todavía no hay evaluaciones. Ejecute la primera para obtener la línea base.' })];
  }
  const total = u.cumple + u.parcial + u.no_cumple;
  const kpi = (titulo, valor, pie, clase, enlace) => h(enlace ? 'a' : 'section',
    { class: `tarjeta kpi ${clase || ''} ${enlace ? 'kpi-enlace' : ''}`, href: enlace },
    h('div', { class: 'kpi-titulo', text: titulo }),
    h('div', { class: 'kpi-valor' }, valor),
    h('div', { class: 'kpi-pie', text: pie }));

  const exc = r.excepciones;
  const cu = r.cuentas;

  // Cobertura por riesgo: las barras empiezan en 0 y se animan al mostrarse la vista
  const barrasCobertura = [];
  const listaCobertura = h('ul', { class: 'lista-riesgos' }, r.riesgos.map((riesgo) => {
    const pct = Math.round(riesgo.cobertura * 100);
    const relleno = h('span');
    relleno.style.width = '0%';
    const barra = h('div', { class: 'barra-progreso mal', role: 'progressbar', 'aria-valuemin': 0, 'aria-valuemax': 100,
      'aria-valuenow': pct, 'aria-label': `Cobertura de ${riesgo.id_riesgo}` }, relleno);
    const cifra = h('span', { text: `0/${riesgo.controles} · 0%` });
    barrasCobertura.push({ barra, relleno, cifra, pct, cumplen: riesgo.cumplen, controles: riesgo.controles });
    // El ID va neutro; el riesgo inherente (antes de los controles) se muestra aparte, como contorno,
    // para no confundirlo con el color de la barra, que es la cobertura actual.
    const clasificacion = riesgo.nivel >= 15 ? 'Alto' : riesgo.nivel >= 8 ? 'Medio' : 'Bajo';
    return h('li', null,
      h('div', { class: 'fila' },
        h('span', { class: 'fila-riesgo' },
          h('span', { class: 'chip', text: riesgo.id_riesgo }), ' ', riesgo.nombre, ' ',
          h('span', { class: `inherente ${claseRiesgo(riesgo.nivel)}`,
            title: 'Riesgo inherente: Impacto × Probabilidad, antes de aplicar controles',
            text: `Inherente: ${clasificacion} · ${riesgo.nivel}` })),
        cifra),
      barra);
  }));

  const nodos = [
    h('p', { class: 'intro' },
      `Última evaluación #${u.id_evaluacion} · ${fecha(u.fecha)} · por ${u.usuario_bd}`,
      u.observaciones ? ` · “${u.observaciones}”` : ''),
    h('div', { class: 'rejilla rejilla-kpi' },
      kpi('Controles que cumplen', [String(u.cumple), h('small', { text: ` / ${total}` })], 'Estado Cumple', 'ok'),
      kpi('Parciales', String(u.parcial), 'Con mejora respecto a la línea base', 'parcial'),
      kpi('No cumplen', String(u.no_cumple), 'Requieren acción', 'mal'),
      kpi('Nivel promedio', [String(u.nivel_promedio ?? '—'), h('small', { text: ' / 4' })], 'Madurez 0 – 4'),
      kpi('Cuentas de usuario auditadas', String(cu.auditadas),
        `${cu.cumplen} cumplen · ${cu.con_excepcion} con excepción · ${cu.no_cumplen} no cumple${cu.no_cumplen === 1 ? '' : 'n'} →`,
        cu.no_cumplen > 0 ? 'mal' : cu.con_excepcion > 0 ? 'parcial' : 'ok', '#/cuentas'),
      kpi('Excepciones vigentes', String(exc.vigentes),
        exc.por_vencer > 0 ? `${exc.por_vencer} vencen en 30 días` : `Próximo vencimiento: ${fecha(exc.proximo_vencimiento).slice(0, 10)}`)),
    h('div', { class: 'rejilla rejilla-2 seccion' },
      tarjeta('Evolución', 'Controles por estado en cada evaluación (PHVA)', graficoEvolucion(r.evolucion)),
      tarjeta('Cobertura por riesgo',
        'La barra indica cuántos controles que mitigan el riesgo cumplen hoy. "Inherente" es la gravedad del riesgo antes de aplicar controles (Impacto × Probabilidad).',
        listaCobertura)),
    h('div', { class: 'seccion' },
      tarjeta('Controles pendientes', r.pendientes.length ? 'No están en estado Cumple en la última evaluación' : null,
        r.pendientes.length === 0
          ? h('p', { class: 'tenue', text: 'Todos los controles observables cumplen.' })
          : h('ul', { class: 'lista' }, r.pendientes.map((p) => h('li', null,
            h('div', { class: 'cabeza' },
              h('span', { class: 'chip', text: p.id_co }), h('span', { class: 'chip', text: p.id_control }),
              etiquetaEstado(p.estado), medidorNivel(p.nivel)),
            h('p', { text: `${p.descripcion}. ${p.justificacion || ''}` })))))),
  ];
  return { nodos, alMostrar: () => animarCobertura(barrasCobertura) };
}

/**
 * Carga animada de las barras de cobertura: crecen de 0 al valor real en ~2 s,
 * escalonadas, con el contador sincronizado y el color según el avance
 * (rojo < 50 %, ámbar < 100 %, verde = 100 %).
 */
function animarCobertura(barras) {
  const DURACION = 1700;          // ms por barra
  const DESFASE = 90;             // ms entre una barra y la siguiente (total ≈ 2 s)
  const suavizar = (t) => 1 - Math.pow(1 - t, 3);   // arranca rápido, frena al llegar
  const claseSegun = (pct) => (pct >= 100 ? '' : pct >= 50 ? 'parcial' : 'mal');
  const pintar = (b, avance) => {
    const pct = b.pct * avance;
    b.relleno.style.width = `${pct}%`;
    b.barra.className = `barra-progreso ${claseSegun(Math.round(pct))}`;
    // floor: "4/4" solo aparece cuando la barra llega a su valor final
    b.cifra.textContent = `${Math.floor(b.cumplen * avance + 1e-9)}/${b.controles} · ${Math.round(pct)}%`;
  };

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    barras.forEach((b) => pintar(b, 1));
    return;
  }
  const inicio = performance.now();
  const paso = (ahora) => {
    let pendientes = false;
    barras.forEach((b, i) => {
      if (!b.barra.isConnected) return;          // el usuario ya salió de Inicio
      const t = Math.min(Math.max((ahora - inicio - i * DESFASE) / DURACION, 0), 1);
      pintar(b, suavizar(t));
      b.barra.classList.toggle('animando', t > 0 && t < 1);
      if (t < 1) pendientes = true;
    });
    if (pendientes) requestAnimationFrame(paso);
  };
  requestAnimationFrame(paso);
}

function graficoEvolucion(evolucion) {
  const datos = evolucion.slice(-14);
  if (datos.length === 0) return h('p', { class: 'tenue', text: 'Sin evaluaciones.' });
  const ancho = 560, alto = 190, margenIzq = 28, margenInf = 22, margenSup = 8;
  const maximo = Math.max(...datos.map((d) => d.cumple + d.parcial + d.no_cumple), 1);
  const paso = (ancho - margenIzq) / datos.length;
  const anchoBarra = Math.min(34, paso * 0.62);
  const escala = (v) => (v / maximo) * (alto - margenInf - margenSup);

  const svg = s('svg', { viewBox: `0 0 ${ancho} ${alto}`, role: 'img',
    'aria-label': 'Evolución de controles por estado en cada evaluación' });
  for (const marca of [0, Math.round(maximo / 2), maximo]) {
    const y = alto - margenInf - escala(marca);
    svg.append(s('line', { x1: margenIzq, x2: ancho, y1: y, y2: y, class: 'eje' }));
    svg.append(s('text', { x: margenIzq - 6, y: y + 4, 'text-anchor': 'end' }, marca));
  }
  datos.forEach((d, i) => {
    const x = margenIzq + i * paso + (paso - anchoBarra) / 2;
    let y = alto - margenInf;
    for (const [valor, clase] of [[d.cumple, 's-ok'], [d.parcial, 's-parcial'], [d.no_cumple, 's-mal']]) {
      const altura = escala(valor);
      if (altura > 0) {
        y -= altura;
        const rect = s('rect', { x, y, width: anchoBarra, height: altura, class: clase, rx: 2 });
        rect.append(s('title', null, `#${d.id_evaluacion} · ${fecha(d.fecha)} · Cumple ${d.cumple}, Parcial ${d.parcial}, No cumple ${d.no_cumple}`));
        svg.append(rect);
      }
    }
    svg.append(s('text', { x: x + anchoBarra / 2, y: alto - 6, 'text-anchor': 'middle' }, `#${d.id_evaluacion}`));
  });
  return h('div', { class: 'grafico' }, svg,
    h('div', { class: 'leyenda' },
      h('span', null, h('i', { class: 'ok' }), 'Cumple'),
      h('span', null, h('i', { class: 'parcial' }), 'Parcial'),
      h('span', null, h('i', { class: 'mal' }), 'No cumple')));
}

async function vistaRiesgos() {
  const riesgos = await api('GET', '/api/riesgos');
  // Mapa de calor 5x5: filas = impacto (5 arriba), columnas = probabilidad
  const mapa = h('div', { class: 'mapa', role: 'img', 'aria-label': 'Mapa de calor de riesgos: impacto por probabilidad' });
  for (let impacto = 5; impacto >= 1; impacto--) {
    mapa.append(h('div', { class: 'eje-y', text: impacto }));
    for (let prob = 1; prob <= 5; prob++) {
      const n = impacto * prob;
      const enCelda = riesgos.filter((r) => r.impacto === impacto && r.probabilidad === prob);
      mapa.append(h('div', { class: `celda ${n >= 15 ? 'alto' : n >= 8 ? 'medio' : 'bajo'}`, title: `I${impacto} × P${prob} = ${n}` },
        enCelda.map((r) => h('span', { text: r.id_riesgo.replace('R-CONF-', 'R') }))));
    }
  }
  mapa.append(h('div'));
  for (let prob = 1; prob <= 5; prob++) mapa.append(h('div', { class: 'eje-x', text: prob }));

  return [
    h('p', { class: 'intro', text: 'Riesgos de confidencialidad (R-CONF) asociados al motor Oracle. Nivel = Impacto × Probabilidad (1–6 Bajo, 8–12 Medio, 15–25 Alto).' }),
    h('div', { class: 'rejilla rejilla-2' },
      tarjeta('Mapa de calor', null, mapa, h('p', { class: 'mapa-titulo', text: 'Vertical: impacto · Horizontal: probabilidad' })),
      tarjeta('Dimensiones de confidencialidad', 'Vistas en clase',
        h('ul', { class: 'lista' },
          ['Acceso a datos', 'Datos sensibles', 'Copias no autorizadas', 'Transversal'].map((d) => h('li', null,
            h('div', { class: 'cabeza' }, h('strong', { text: d })),
            h('p', { text: riesgos.filter((r) => r.dimension === d).map((r) => r.id_riesgo).join(', ') || '—' })))))),
    h('div', { class: 'seccion' }, tabla([
      { t: 'ID', v: (r) => h('span', { class: 'chip', text: r.id_riesgo }) },
      { t: 'Riesgo', v: (r) => h('div', null, h('strong', { text: r.nombre }), h('div', { class: 'tenue', text: r.escenario })) },
      { t: 'Dimensión', v: (r) => r.dimension },
      { t: 'Impacto', v: (r) => r.impacto, clase: 'num' },
      { t: 'Prob.', v: (r) => r.probabilidad, clase: 'num' },
      { t: 'Nivel', v: (r) => h('span', { class: `etiqueta ${claseRiesgo(r.nivel)}`, text: `${r.nivel} · ${r.clasificacion}` }) },
    ], riesgos)),
  ];
}

async function vistaTareas() {
  const tareas = await api('GET', '/api/tareas');
  return [
    h('p', { class: 'intro', text: 'Tareas críticas del DBA con los riesgos que generan y los controles ISO que las protegen.' }),
    tabla([
      { t: 'ID', v: (t) => h('span', { class: 'chip', text: t.id_tarea }) },
      { t: 'Tarea', v: (t) => t.nombre },
      { t: 'Riesgos', v: (t) => chips(t.riesgos) },
      { t: 'Controles ISO', v: (t) => chips(t.controles) },
    ], tareas),
  ];
}

async function vistaControles() {
  const controles = await api('GET', '/api/controles');
  return [
    h('p', { class: 'intro', text: 'Controles del Anexo A de ISO/IEC 27001:2022 seleccionados. Los complementarios no están en la lista del enunciado, pero son los que corresponden según la norma.' }),
    tabla([
      { t: 'Control', v: (c) => h('span', { class: 'chip', text: c.id_control }) },
      { t: 'Nombre', v: (c) => h('div', null, h('strong', { text: c.nombre }),
        c.complementario === 'S' ? [' ', h('span', { class: 'etiqueta acento', text: 'Complementario' })] : null) },
      { t: 'Tema', v: (c) => c.tema.charAt(0) + c.tema.slice(1).toLowerCase() },
      { t: 'Justificación', v: (c) => c.justificacion },
      { t: 'Implementación en Oracle', v: (c) => h('code', { text: c.implementacion }) },
    ], controles),
  ];
}

async function vistaObservables() {
  const observables = await api('GET', '/api/controles-observables');
  return [
    h('p', { class: 'intro', text: 'Controles verificables por un auditor externo. Cada consulta devuelve los hallazgos (filas que incumplen): 0 filas significa que el control se observa implementado.' }),
    h('div', { class: 'evidencia' }, observables.map((c) => h('section', { class: 'tarjeta' },
      h('div', { class: 'tarjeta-cabeza' },
        h('h4', null, h('span', { class: 'chip', text: c.id_co }), ' ', c.descripcion),
        h('span', { class: 'chips' }, h('span', { class: 'chip', text: c.id_control }),
          c.complementario === 'S' ? h('span', { class: 'etiqueta acento', text: 'Complementario' }) : null)),
      h('p', { class: 'justificacion', text: `${c.control} · Cumple si: ${c.criterio}` }),
      h('details', { class: 'consulta' },
        h('summary', { text: 'Ver consulta de evidencia (SQL)' }),
        h('pre', { class: 'sql' }, h('code', { text: c.consulta })))))),
  ];
}

async function vistaMatriz() {
  const matriz = await api('GET', '/api/matriz');
  const contenedor = h('div');
  const filtroEstado = h('select', { id: 'filtro-estado' },
    ['Todos', 'Cumple', 'Parcial', 'No cumple', 'Sin evaluar'].map((e) => h('option', { value: e, text: e })));
  const filtroTexto = h('input', { id: 'filtro-texto', type: 'search', placeholder: 'Tarea, riesgo o control…' });

  const pintar = () => {
    const estado = filtroEstado.value;
    const texto = filtroTexto.value.trim().toLowerCase();
    const filas = matriz.filter((f) => {
      const estadoFila = f.estado || 'Sin evaluar';
      if (estado !== 'Todos' && estadoFila !== estado) return false;
      if (!texto) return true;
      return [f.id_tarea, f.tarea, f.riesgos, f.id_control, f.control, f.id_co].join(' ').toLowerCase().includes(texto);
    });
    contenedor.replaceChildren(tabla([
      { t: 'Tarea', v: (f) => h('div', null, h('span', { class: 'chip', text: f.id_tarea }), ' ', f.tarea) },
      { t: 'Riesgo', v: (f) => chips((f.riesgos || '').split(', ').filter(Boolean)) },
      { t: 'Control', v: (f) => h('div', null, h('span', { class: 'chip', text: f.id_control }), ' ', f.control) },
      { t: 'Control observable', v: (f) => f.id_co ? h('span', { class: 'chip', text: f.id_co }) : h('span', { class: 'tenue', text: 'Sin control observable' }) },
      { t: 'Criterio', v: (f) => f.criterio },
      { t: 'Nivel 0–4', v: (f) => medidorNivel(f.nivel) },
      { t: 'Evidencia', clase: 'sin-corte', v: (f) => f.id_evaluacion !== null && f.id_co
        ? h('a', { href: `#/evaluaciones/${f.id_evaluacion}`, title: `${f.hallazgos} hallazgo(s) en la evaluación #${f.id_evaluacion}`,
          text: `${f.hallazgos} hallazgo${f.hallazgos === 1 ? '' : 's'}` })
        : null },
      { t: 'Estado', v: (f) => f.id_co ? etiquetaEstado(f.estado) : h('span', { class: 'tenue', text: 'N/A' }) },
    ], filas, { vacio: 'Ninguna fila coincide con el filtro.' }));
  };
  filtroEstado.addEventListener('change', pintar);
  filtroTexto.addEventListener('input', pintar);
  pintar();

  return [
    h('p', { class: 'intro', text: 'Matriz de evaluación: Tarea | Riesgo | Control | Criterio 0–4 | Evidencia | Estado, según la última evaluación registrada.' }),
    h('div', { class: 'filtros' },
      h('div', null, h('label', { for: 'filtro-estado', text: 'Estado' }), filtroEstado),
      h('div', null, h('label', { for: 'filtro-texto', text: 'Buscar' }), filtroTexto)),
    contenedor,
  ];
}

async function vistaPruebas() {
  const pruebas = await api('GET', '/api/pruebas');
  return [
    h('p', { class: 'intro', text: 'Batería de pruebas: PT-01 a PT-16 las ejecuta el evaluador; PT-17 en adelante son pruebas funcionales (scripts/02_verificacion y tests/).' }),
    tabla([
      { t: 'ID', v: (p) => h('span', { class: 'chip', text: p.id_prueba }) },
      { t: 'Tipo', v: (p) => h('span', { class: `etiqueta ${p.tipo === 'FUNCIONAL' ? 'acento' : ''}`, text: p.tipo.charAt(0) + p.tipo.slice(1).toLowerCase() }) },
      { t: 'Control', v: (p) => p.id_co ? h('span', { class: 'chip', text: p.id_co }) : null },
      { t: 'Procedimiento', v: (p) => p.procedimiento },
      { t: 'Resultado esperado', v: (p) => p.resultado_esperado },
      { t: 'Herramienta', v: (p) => h('code', { text: p.herramienta }) },
    ], pruebas),
  ];
}

async function vistaEvaluaciones() {
  const evaluaciones = await api('GET', '/api/evaluaciones');
  return [
    h('p', { class: 'intro', text: 'Histórico de evaluaciones. Los registros no se pueden modificar ni eliminar (la cuenta del evaluador solo tiene INSERT y SELECT).' }),
    tabla([
      { t: '#', v: (e) => h('a', { href: `#/evaluaciones/${e.id_evaluacion}`, text: `#${e.id_evaluacion}` }) },
      { t: 'Fecha', v: (e) => fecha(e.fecha), clase: 'mono' },
      { t: 'Auditor', v: (e) => e.usuario_bd },
      { t: 'Cumple', v: (e) => h('span', { class: 'etiqueta ok', text: e.cumple }), clase: 'num' },
      { t: 'Parcial', v: (e) => h('span', { class: 'etiqueta parcial', text: e.parcial }), clase: 'num' },
      { t: 'No cumple', v: (e) => h('span', { class: 'etiqueta mal', text: e.no_cumple }), clase: 'num' },
      { t: 'Nivel prom.', v: (e) => e.nivel_promedio, clase: 'num' },
      { t: 'Observaciones', v: (e) => e.observaciones },
    ], evaluaciones, { vacio: 'Aún no hay evaluaciones.' }),
  ];
}

function tablaEvidencia(columnas, filas, clase) {
  return tabla(
    columnas.map((nombre, i) => ({ t: nombre, v: (fila) => fila[i] === null ? null : String(fila[i]) })),
    filas,
    { claseFila: () => clase });
}

async function vistaEvaluacion(id) {
  const e = await api('GET', `/api/evaluaciones/${encodeURIComponent(id)}`);
  const conteo = (estado) => e.detalles.filter((d) => d.estado === estado).length;
  return [
    h('p', { class: 'intro' }, h('a', { href: '#/evaluaciones', text: '← Evaluaciones' })),
    h('section', { class: 'tarjeta' },
      h('dl', { class: 'datos' },
        h('dt', { text: 'Evaluación' }), h('dd', { text: `#${e.id_evaluacion}` }),
        h('dt', { text: 'Fecha' }), h('dd', { text: fecha(e.fecha) }),
        h('dt', { text: 'Auditor' }), h('dd', { text: e.usuario_bd }),
        h('dt', { text: 'Resultado' }), h('dd', null,
          h('span', { class: 'etiqueta ok', text: `${conteo('Cumple')} Cumple` }), ' ',
          h('span', { class: 'etiqueta parcial', text: `${conteo('Parcial')} Parcial` }), ' ',
          h('span', { class: 'etiqueta mal', text: `${conteo('No cumple')} No cumple` })),
        e.observaciones ? [h('dt', { text: 'Observaciones' }), h('dd', { text: e.observaciones })] : null)),
    h('div', { class: 'evidencia seccion' }, e.detalles.map((d) => {
      const ev = d.evidencia || {};
      return h('section', { class: 'tarjeta' },
        h('div', { class: 'tarjeta-cabeza' },
          h('h4', null, h('span', { class: 'chip', text: d.id_co }), ' ', h('span', { class: 'chip', text: d.id_control }), ' ', d.descripcion),
          h('span', { class: 'chips' }, medidorNivel(d.nivel), etiquetaEstado(d.estado))),
        h('p', { class: 'justificacion', text: `${d.justificacion || ''} · Criterio: ${d.criterio}` }),
        ev.error ? h('div', { class: 'error-vista', text: `La consulta de evidencia falló (${ev.error}).` }) : null,
        ev.filas && ev.filas.length ? [h('p', { class: 'subtitulo', text: `Hallazgos (${d.hallazgos})` }), tablaEvidencia(ev.columnas, ev.filas)] : null,
        ev.exceptuados && ev.exceptuados.length
          ? [h('p', { class: 'subtitulo', text: `Exceptuados por excepción aprobada (${ev.exceptuados.length})` }),
            tablaEvidencia(ev.columnas, ev.exceptuados, 'exceptuado')]
          : null,
        !ev.error && (!ev.filas || ev.filas.length === 0) && (!ev.exceptuados || ev.exceptuados.length === 0)
          ? h('p', { class: 'tenue', text: 'Sin hallazgos: la consulta no devolvió filas.' }) : null);
    })),
  ];
}

/* Requisitos por cuenta: símbolo corto para la matriz y etiqueta completa para el detalle */
const SIMBOLO_REQUISITO = {
  'Cumple': ['✓', 'ok'], 'No cumple': ['✗', 'mal'], 'Exceptuado': ['E', 'parcial'], 'No aplica': ['—', ''],
};

const COLUMNA_REQUISITO = {
  perfil: 'Perfil', politica: 'Política', contrasena: 'Contraseña', uso: 'En uso',
  privilegios: 'Privilegios', roles: 'Por roles', auditoria: 'Auditada',
};

function marcaRequisito(r) {
  const [simbolo, clase] = SIMBOLO_REQUISITO[r.estado] || ['?', ''];
  return h('span', { class: `etiqueta marca ${clase}`, title: `${r.titulo}: ${r.estado}. ${r.detalle}`,
    'aria-label': `${r.titulo}: ${r.estado}`, text: simbolo });
}

function etiquetaCuenta(estado) {
  return h('span', { class: `etiqueta ${estado === 'OPEN' ? 'ok' : ''}`, text: estado });
}

const rutaCuenta = (usuario) => `#/cuentas/${encodeURIComponent(usuario)}`;

async function vistaCuentas() {
  const { totales: t, cuentas } = await api('GET', '/api/cuentas');
  const kpi = (titulo, valor, pie, clase) => h('section', { class: `tarjeta kpi ${clase || ''}` },
    h('div', { class: 'kpi-titulo', text: titulo }), h('div', { class: 'kpi-valor', text: valor }), h('div', { class: 'kpi-pie', text: pie }));

  const requisitos = cuentas.length ? cuentas[0].requisitos : [];
  const contenedor = h('div');
  const filtroEstado = h('select', { id: 'filtro-estado-cuenta' },
    ['Todos', 'Cumple', 'Cumple con excepción', 'No cumple'].map((e) => h('option', { value: e, text: e })));
  const filtroTexto = h('input', { id: 'filtro-texto-cuenta', type: 'search', placeholder: 'Usuario, perfil o rol…' });

  const pintar = () => {
    const estado = filtroEstado.value;
    const texto = filtroTexto.value.trim().toLowerCase();
    const filas = cuentas.filter((c) => (estado === 'Todos' || c.estado === estado)
      && (!texto || [c.usuario, c.profile, c.tipo, ...c.roles].join(' ').toLowerCase().includes(texto)));
    contenedor.replaceChildren(tabla([
      { t: 'Usuario', v: (c) => h('div', null, h('a', { href: rutaCuenta(c.usuario), text: c.usuario }), h('div', { class: 'tenue', text: c.tipo })) },
      { t: 'Cuenta y perfil', v: (c) => h('div', null, etiquetaCuenta(c.account_status), h('div', null, h('code', { class: 'tenue', text: c.profile }))) },
      { t: 'Roles', v: (c) => chips(c.roles) },
      ...requisitos.map((r, i) => ({ t: COLUMNA_REQUISITO[r.id] || r.control, clase: 'centro', v: (c) => marcaRequisito(c.requisitos[i]) })),
      { t: 'Resultado', v: (c) => h('div', null, etiquetaEstado(c.estado),
        h('div', { class: 'tenue', text: `${c.cumplidos}/${c.aplicables} requisitos` })) },
    ], filas, { vacio: 'Ninguna cuenta coincide con el filtro.' }));
  };
  filtroEstado.addEventListener('change', pintar);
  filtroTexto.addEventListener('input', pintar);
  pintar();

  return [
    h('p', { class: 'intro', text: 'Auditoría de cada cuenta de Oracle creada en XEPDB1 (las cuentas internas de Oracle no se incluyen). '
      + 'Cada cuenta se revisa contra los requisitos de confidencialidad que le aplican, con los mismos criterios de los controles observables. '
      + 'Se calcula en vivo desde el diccionario de datos.' }),
    h('div', { class: 'rejilla rejilla-kpi' },
      kpi('Cuentas auditadas', String(t.auditadas), `${t.abiertas} abiertas`),
      kpi('Cumplen', String(t.cumplen), 'Todos los requisitos aplicables', 'ok'),
      kpi('Con excepción', String(t.con_excepcion), 'Incumplimiento con riesgo aceptado', 'parcial'),
      kpi('No cumplen', String(t.no_cumplen), 'Requieren acción', 'mal')),
    h('div', { class: 'seccion' },
      tarjeta('Requisitos evaluados', 'Pase el cursor sobre cada marca para ver el detalle; abra una cuenta para ver toda la evidencia.',
        h('ul', { class: 'lista lista-requisitos' }, requisitos.map((r) => h('li', null,
          h('div', { class: 'cabeza' }, h('span', { class: 'chip', text: r.control }),
            r.co ? h('span', { class: 'chip', text: r.co }) : null, h('strong', { text: r.titulo })),
          h('p', { text: r.criterio })))),
        h('p', { class: 'leyenda-marcas' },
          ['Cumple', 'No cumple', 'Exceptuado', 'No aplica'].map((e) => h('span', null,
            marcaRequisito({ estado: e, titulo: e, detalle: '' }), ` ${e}`))))),
    h('div', { class: 'filtros seccion' },
      h('div', null, h('label', { for: 'filtro-estado-cuenta', text: 'Resultado' }), filtroEstado),
      h('div', null, h('label', { for: 'filtro-texto-cuenta', text: 'Buscar' }), filtroTexto)),
    contenedor,
  ];
}

const NOMBRES_PARAMETRO = {
  FAILED_LOGIN_ATTEMPTS: 'Intentos fallidos antes del bloqueo',
  PASSWORD_LOCK_TIME: 'Duración del bloqueo (días)',
  PASSWORD_LIFE_TIME: 'Vigencia de la contraseña (días)',
  PASSWORD_GRACE_TIME: 'Período de gracia (días)',
  PASSWORD_REUSE_TIME: 'Días antes de reutilizar',
  PASSWORD_REUSE_MAX: 'Cambios antes de reutilizar',
  PASSWORD_VERIFY_FUNCTION: 'Función de complejidad',
  IDLE_TIME: 'Inactividad máxima (min)',
  SESSIONS_PER_USER: 'Sesiones simultáneas',
};

async function vistaCuenta(usuario) {
  const c = await api('GET', `/api/cuentas/${encodeURIComponent(usuario)}`);
  const parametros = Object.keys(NOMBRES_PARAMETRO).filter((p) => p in c.parametros_perfil);
  return [
    h('p', { class: 'intro' }, h('a', { href: '#/cuentas', text: '← Cuentas de usuario' })),
    h('div', { class: 'rejilla rejilla-2' },
      tarjeta('Cuenta', null, h('dl', { class: 'datos' },
        h('dt', { text: 'Usuario' }), h('dd', { text: c.usuario }),
        h('dt', { text: 'Tipo' }), h('dd', { text: c.tipo }),
        h('dt', { text: 'Resultado' }), h('dd', null, etiquetaEstado(c.estado), ` ${c.cumplidos}/${c.aplicables} requisitos`),
        h('dt', { text: 'Estado de la cuenta' }), h('dd', null, etiquetaCuenta(c.account_status)),
        h('dt', { text: 'Autenticación' }), h('dd', { text: c.authentication_type }),
        h('dt', { text: 'Perfil' }), h('dd', null, h('code', { text: c.profile })),
        h('dt', { text: 'Roles' }), h('dd', null, c.roles.length ? chips(c.roles) : '—'),
        h('dt', { text: 'Creada' }), h('dd', { text: c.creada }),
        h('dt', { text: 'Último acceso' }), h('dd', { text: fecha(c.ultimo_acceso) }),
        h('dt', { text: 'Contraseña vence' }), h('dd', { text: c.vence_contrasena || 'No vence' }),
        c.bloqueada_desde ? [h('dt', { text: 'Bloqueada desde' }), h('dd', { text: c.bloqueada_desde })] : null,
        h('dt', { text: 'Fallidos (30 días)' }), h('dd', null,
          h('span', { class: `etiqueta ${c.fallidos_30_dias > 0 ? 'mal' : 'ok'}`, text: c.fallidos_30_dias })))),
      tarjeta(`Perfil ${c.profile}`, 'Parámetros efectivos (los valores DEFAULT se toman del perfil DEFAULT)',
        parametros.length === 0 ? h('p', { class: 'tenue', text: 'Sin parámetros.' }) : h('dl', { class: 'datos' },
          parametros.map((p) => [h('dt', { text: NOMBRES_PARAMETRO[p] }), h('dd', null, h('code', { text: c.parametros_perfil[p] }))])))),
    h('div', { class: 'evidencia seccion' }, c.requisitos.map((r) => h('section', { class: 'tarjeta' },
      h('div', { class: 'tarjeta-cabeza' },
        h('h4', null, h('span', { class: 'chip', text: r.control }), ' ', r.co ? [h('span', { class: 'chip', text: r.co }), ' '] : null, r.titulo),
        h('span', { class: `etiqueta ${claseEstado(r.estado)}`, text: r.estado })),
      h('p', { class: 'justificacion', text: `Criterio: ${r.criterio}` }),
      h('p', { text: r.detalle })))),
    h('div', { class: 'rejilla rejilla-2 seccion' },
      tarjeta('Políticas de auditoría que la cubren', 'Auditoría unificada habilitada para esta cuenta (A8.15)',
        tabla([
          { t: 'Política', v: (p) => h('code', { text: p.policy_name }) },
          { t: 'Exitosos', v: (p) => (p.exitosos ? 'Sí' : 'No') },
          { t: 'Fallidos', v: (p) => (p.fallidos ? 'Sí' : 'No') },
        ], c.politicas_auditoria, { vacio: 'Ninguna política de auditoría alcanza a esta cuenta.' })),
      tarjeta('Intentos fallidos de inicio de sesión (30 días)', 'Registrados por la política ORA_LOGON_FAILURES',
        tabla([
          { t: 'Fecha y hora', v: (f) => f.hora, clase: 'mono' },
          { t: 'Error Oracle', v: (f) => h('code', { text: `ORA-${String(f.codigo_ora).padStart(5, '0')}` }) },
          { t: 'Equipo', v: (f) => f.equipo },
        ], c.intentos_fallidos, { vacio: 'Sin intentos fallidos en los últimos 30 días.' }))),
  ];
}

async function vistaExcepciones() {
  const excepciones = await api('GET', '/api/excepciones');
  return [
    h('p', { class: 'intro', text: 'Riesgos aceptados formalmente (fase Actuar). Un hallazgo exceptuado no cuenta, pero sigue visible en la evidencia; con excepciones el nivel máximo es 3. Toda excepción vence y debe revisarse.' }),
    tabla([
      { t: 'Control', v: (x) => h('span', { class: 'chip', text: x.id_co }) },
      { t: 'Objeto', v: (x) => h('code', { text: x.objeto }) },
      { t: 'Justificación', v: (x) => x.justificacion },
      { t: 'Control compensatorio', v: (x) => x.control_compensatorio },
      { t: 'Aprobó', v: (x) => x.aprobado_por },
      { t: 'Vence', v: (x) => fecha(x.fecha_vencimiento).slice(0, 10), clase: 'mono' },
      { t: 'Estado', v: (x) => h('span', { class: `etiqueta ${x.estado === 'Vigente' ? 'ok' : 'mal'}`, text: x.estado }) },
    ], excepciones, { vacio: 'No hay excepciones registradas.' }),
  ];
}

async function vistaActividad() {
  const a = await api('GET', '/api/mi-actividad');
  const c = a.cuenta || {};
  return [
    h('p', { class: 'intro', text: 'Su propia actividad registrada por Oracle. Puede consultarla, pero no modificarla ni borrarla (separación de funciones, A5.33).' }),
    h('div', { class: 'rejilla rejilla-2' },
      tarjeta('Mi cuenta', null, h('dl', { class: 'datos' },
        h('dt', { text: 'Usuario' }), h('dd', { text: a.usuario }),
        h('dt', { text: 'Estado' }), h('dd', null, h('span', { class: `etiqueta ${c.account_status === 'OPEN' ? 'ok' : 'mal'}`, text: c.account_status || '—' })),
        h('dt', { text: 'Perfil' }), h('dd', { text: c.profile || '—' }),
        h('dt', { text: 'Contraseña vence' }), h('dd', { text: c.vence_contrasena || 'No vence' }),
        h('dt', { text: 'Acceso anterior' }), h('dd', { text: fecha(a.acceso_anterior) }),
        h('dt', { text: 'Fallidos desde entonces' }), h('dd', null,
          h('span', { class: `etiqueta ${a.intentos_fallidos_desde_ultimo_acceso > 0 ? 'mal' : 'ok'}`, text: a.intentos_fallidos_desde_ultimo_acceso })))),
      tarjeta('Evaluaciones lanzadas', null, a.evaluaciones_lanzadas.length === 0
        ? h('p', { class: 'tenue', text: 'Aún no ha lanzado evaluaciones.' })
        : h('ul', { class: 'lista' }, a.evaluaciones_lanzadas.map((e) => h('li', null,
          h('div', { class: 'cabeza' }, h('a', { href: `#/evaluaciones/${e.id_evaluacion}`, text: `#${e.id_evaluacion}` }), h('span', { class: 'tenue', text: fecha(e.fecha) })),
          e.observaciones ? h('p', { text: e.observaciones }) : null))))),
    h('div', { class: 'seccion' },
      tarjeta('Intentos fallidos de inicio de sesión (30 días)', 'Registrados por la política ORA_LOGON_FAILURES',
        tabla([
          { t: 'Fecha y hora', v: (f) => f.hora, clase: 'mono' },
          { t: 'Error Oracle', v: (f) => h('code', { text: `ORA-${String(f.codigo_ora).padStart(5, '0')}` }) },
          { t: 'Equipo', v: (f) => f.equipo },
        ], a.intentos_fallidos_30_dias, { vacio: 'Sin intentos fallidos en los últimos 30 días.' }))),
  ];
}

/* ======================================================================
 * Enrutador
 * ==================================================================== */

const rutas = {
  inicio: { titulo: 'Inicio', vista: vistaInicio },
  evaluaciones: { titulo: 'Evaluaciones', vista: vistaEvaluaciones },
  matriz: { titulo: 'Matriz de evaluación', vista: vistaMatriz },
  cuentas: { titulo: 'Cuentas de usuario', vista: vistaCuentas },
  riesgos: { titulo: 'Riesgos de confidencialidad', vista: vistaRiesgos },
  tareas: { titulo: 'Tareas del DBA', vista: vistaTareas },
  controles: { titulo: 'Controles ISO/IEC 27001:2022', vista: vistaControles },
  observables: { titulo: 'Controles observables', vista: vistaObservables },
  pruebas: { titulo: 'Batería de pruebas', vista: vistaPruebas },
  excepciones: { titulo: 'Excepciones aprobadas', vista: vistaExcepciones },
  actividad: { titulo: 'Mi actividad', vista: vistaActividad },
};

let navegacion = 0;

async function enrutar() {
  if (!usuarioActual) return;
  const [, seccion = 'inicio', id] = (location.hash || '#/inicio').split('/');
  let ruta = rutas[seccion] || rutas.inicio;
  let vista = ruta.vista;
  let titulo = ruta.titulo;
  if (seccion === 'evaluaciones' && id && /^\d{1,9}$/.test(id)) {
    vista = () => vistaEvaluacion(id);
    titulo = `Evaluación #${id}`;
  }
  if (seccion === 'cuentas' && id) {
    let usuario = '';
    try { usuario = decodeURIComponent(id); } catch { /* hash mal formado: se muestra la lista */ }
    if (/^[A-Za-z][A-Za-z0-9_$#]{0,127}$/.test(usuario)) {
      vista = () => vistaCuenta(usuario);
      titulo = `Cuenta ${usuario.toUpperCase()}`;
    }
  }

  document.querySelectorAll('#menu nav a').forEach((a) => a.classList.toggle('activo', a.dataset.ruta === (rutas[seccion] ? seccion : 'inicio')));
  $('#titulo').textContent = titulo;
  document.title = `${titulo} · AUDINC`;
  cerrarMenu();

  const contenido = $('#contenido');
  const actual = ++navegacion;
  contenido.replaceChildren(h('div', { class: 'cargando', text: 'Cargando…' }));
  try {
    // Una vista devuelve sus nodos, o { nodos, alMostrar } si necesita animarse al aparecer
    const resultado = await vista();
    if (actual !== navegacion) return;           // el usuario ya navegó a otra vista
    const nodos = Array.isArray(resultado) ? resultado : resultado.nodos;
    contenido.replaceChildren(...nodos);
    if (!Array.isArray(resultado) && resultado.alMostrar) resultado.alMostrar();
  } catch (e) {
    if (actual !== navegacion || e.estado === 401) return;
    contenido.replaceChildren(h('div', { class: 'error-vista', text: `No se pudo cargar la vista: ${e.message}` }));
  }
  contenido.focus({ preventScroll: true });
}

window.addEventListener('hashchange', enrutar);

/* Modo día / noche (la preferencia se guarda en el navegador; tema.js la aplica al cargar) */
const botonTema = $('#boton-tema');
function aplicarTema(tema) {
  document.documentElement.setAttribute('data-tema', tema);
  const etiqueta = tema === 'claro' ? 'Cambiar a modo noche' : 'Cambiar a modo día';
  botonTema.setAttribute('aria-label', etiqueta);
  botonTema.title = etiqueta;
}
botonTema.addEventListener('click', () => {
  const nuevo = document.documentElement.getAttribute('data-tema') === 'claro' ? 'oscuro' : 'claro';
  // Transición suave de colores solo durante el cambio
  document.documentElement.classList.add('cambiando-tema');
  aplicarTema(nuevo);
  setTimeout(() => document.documentElement.classList.remove('cambiando-tema'), 450);
  try { localStorage.setItem('audinc-tema', nuevo); } catch { /* almacenamiento bloqueado: solo esta visita */ }
});
aplicarTema(document.documentElement.getAttribute('data-tema') === 'claro' ? 'claro' : 'oscuro');

/* Menú en pantallas pequeñas */
function cerrarMenu() {
  $('#menu').classList.remove('abierto');
  $('#boton-menu').setAttribute('aria-expanded', 'false');
}
$('#boton-menu').addEventListener('click', () => {
  const abierto = $('#menu').classList.toggle('abierto');
  $('#boton-menu').setAttribute('aria-expanded', String(abierto));
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') cerrarMenu(); });
document.querySelector('.principal').addEventListener('click', (e) => {
  if ($('#menu').classList.contains('abierto') && !e.target.closest('#boton-menu')) cerrarMenu();
});

/* ======================================================================
 * Arranque: ¿hay sesión activa?
 * ==================================================================== */
(async () => {
  try {
    mostrarApp(await api('GET', '/api/sesion'));
  } catch {
    mostrarLogin();
  }
})();
