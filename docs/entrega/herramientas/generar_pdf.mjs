// Convierte los documentos de entrega (docs/entrega/*.md) a PDF.
// Markdown -> HTML con "marked" -> PDF con Microsoft Edge en modo headless (protocolo DevTools).
//
// Uso (desde docs/entrega/herramientas):
//   npm install      (solo la primera vez)
//   npm run pdf      (genera todos)    |   node generar_pdf.mjs 02_Manual_de_usuario.md   (uno)
//
// Convenciones dentro del Markdown:
//   <!-- indice -->        se reemplaza por el índice de secciones (h2 y h3)
//   <div class="salto"></div>   fuerza un salto de página
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, readdirSync, mkdirSync, mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { marked } from 'marked';

const AQUI = dirname(fileURLToPath(import.meta.url));
const ENTREGA = join(AQUI, '..');
const SALIDA = join(ENTREGA, 'pdf');
const NAVEGADORES = [
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
];
const espera = (ms) => new Promise((r) => setTimeout(r, ms));

/** Identificador de ancla a partir del texto del título. */
function ancla(texto) {
  return texto.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/<[^>]+>/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function aHtml(markdown, titulo) {
  const indice = [];
  const renderer = new marked.Renderer();
  renderer.heading = (texto, nivel) => {
    const id = ancla(texto);
    if (nivel === 2 || nivel === 3) indice.push({ nivel, texto, id });
    return `<h${nivel} id="${id}">${texto}</h${nivel}>\n`;
  };
  let cuerpo = marked.parse(markdown, { renderer, gfm: true });
  const listaIndice = `<nav class="indice"><h2 class="sin-indice">Índice</h2><ol>${indice.map((e) =>
    `<li class="n${e.nivel}"><a href="#${e.id}">${e.texto}</a></li>`).join('')}</ol></nav>`;
  cuerpo = cuerpo.replace('<!-- indice -->', listaIndice);
  const css = readFileSync(join(AQUI, 'estilo.css'), 'utf8');
  return `<!doctype html><html lang="es"><head><meta charset="utf-8"><title>${titulo}</title>
<style>${css}</style></head><body>${cuerpo}</body></html>`;
}

async function abrirNavegador() {
  const ejecutable = NAVEGADORES.find((n) => existsSync(n));
  if (!ejecutable) throw new Error('No se encontró Microsoft Edge ni Google Chrome');
  const perfil = mkdtempSync(join(tmpdir(), 'audinc-pdf-'));
  const puerto = 9400 + Math.floor(Math.random() * 400);
  const proc = spawn(ejecutable, ['--headless=new', `--remote-debugging-port=${puerto}`, `--user-data-dir=${perfil}`,
    '--no-first-run', '--disable-extensions', '--allow-file-access-from-files', 'about:blank'], { stdio: 'ignore' });
  let lista;
  for (let i = 0; i < 75 && !lista; i++) {
    await espera(200);
    try { lista = await (await fetch(`http://127.0.0.1:${puerto}/json/list`)).json(); } catch { /* arrancando */ }
  }
  const ws = new WebSocket(lista.find((t) => t.type === 'page').webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener('open', r, { once: true }));
  let id = 0;
  const pendientes = new Map();
  const eventos = [];
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pendientes.has(m.id)) {
      const { ok, ko } = pendientes.get(m.id);
      pendientes.delete(m.id);
      m.error ? ko(new Error(m.error.message)) : ok(m.result);
    } else if (m.method) {
      eventos.forEach((f) => f(m));
    }
  });
  const enviar = (method, params = {}) => new Promise((ok, ko) => {
    const n = ++id;
    pendientes.set(n, { ok, ko });
    ws.send(JSON.stringify({ id: n, method, params }));
  });
  await enviar('Page.enable');
  return {
    enviar,
    cargar: (url) => new Promise((ok) => {
      const f = (m) => { if (m.method === 'Page.loadEventFired') { eventos.splice(eventos.indexOf(f), 1); ok(); } };
      eventos.push(f);
      enviar('Page.navigate', { url });
    }),
    async cerrar() {
      try { await enviar('Browser.close'); } catch { /* cerrado */ }
      ws.close();
      proc.kill();
      await espera(500);
      try { rmSync(perfil, { recursive: true, force: true }); } catch { /* lo limpia el sistema */ }
    },
  };
}

const PIE = `<div style="width:100%;font-family:Segoe UI,Arial,sans-serif;font-size:8px;color:#6b7280;padding:0 15mm;display:flex;justify-content:space-between">
  <span>AUDINC · Evaluador de confidencialidad ISO/IEC 27001:2022</span>
  <span>Página <span class="pageNumber"></span> de <span class="totalPages"></span></span></div>`;

const archivos = process.argv.slice(2).length
  ? process.argv.slice(2)
  : readdirSync(ENTREGA).filter((f) => /^\d\d_.*\.md$/.test(f)).sort();

mkdirSync(SALIDA, { recursive: true });
const navegador = await abrirNavegador();
try {
  for (const archivo of archivos) {
    const markdown = readFileSync(join(ENTREGA, archivo), 'utf8');
    const titulo = (markdown.match(/^# (.+)$/m) || [, basename(archivo, '.md')])[1];
    // El HTML temporal va junto a los .md para que las rutas relativas de las imágenes funcionen
    const html = join(ENTREGA, `.${basename(archivo, '.md')}.tmp.html`);
    writeFileSync(html, aHtml(markdown, titulo));
    await navegador.cargar(pathToFileURL(html).href);
    await espera(400);
    const r = await navegador.enviar('Page.printToPDF', {
      paperWidth: 8.27, paperHeight: 11.69,                     // A4
      marginTop: 0.75, marginBottom: 0.75, marginLeft: 0.7, marginRight: 0.7,
      printBackground: true, displayHeaderFooter: true,
      headerTemplate: '<span></span>', footerTemplate: PIE,
      preferCSSPageSize: false, generateDocumentOutline: true,
    });
    const destino = join(SALIDA, `${basename(archivo, '.md')}.pdf`);
    writeFileSync(destino, Buffer.from(r.data, 'base64'));
    if (!process.env.CONSERVAR_HTML) rmSync(html);
    console.log(`PDF generado: ${destino}`);
  }
} finally {
  await navegador.cerrar();
}
