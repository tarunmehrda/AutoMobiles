/* Render-blocking, in <head>, before React and before the first paint.
   Anything slower than this and the page flashes white on the way into dark. */
(function () {
  var root = document.documentElement;
  var theme = 'light';

  try {
    var saved = localStorage.getItem('ba-theme');
    if (saved === 'light' || saved === 'dark') {
      theme = saved;
    } else if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
      theme = 'dark';
    }
  } catch (e) {
    /* Private mode, or site data blocked. The default stands. */
  }

  root.setAttribute('data-theme', theme);

  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', theme === 'dark' ? '#0B0C0E' : '#F4F5F7');
})();
