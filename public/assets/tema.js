/* Aplica el tema guardado (día/noche) ANTES de pintar la página, para evitar un destello
 * del tema equivocado. Se carga sin "defer" en <head>. Por defecto: noche. */
(function () {
  var tema = 'oscuro';
  try { tema = localStorage.getItem('audinc-tema') || 'oscuro'; } catch (e) { /* almacenamiento bloqueado */ }
  document.documentElement.setAttribute('data-tema', tema === 'claro' ? 'claro' : 'oscuro');
})();
