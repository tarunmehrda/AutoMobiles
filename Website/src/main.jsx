import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, HashRouter } from 'react-router-dom';
import App from './App.jsx';
import './styles/site.css';

/* Clean URLs on our own domain, where the host rewrites unknown paths to
   index.html. A portable build falls back to hash routing, which needs no
   rewrite rule and so survives being dropped on any static host. */
const Router = import.meta.env.VITE_ARTIFACT ? HashRouter : BrowserRouter;

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <Router>
      <App />
    </Router>
  </StrictMode>,
);
