import { Route, Routes } from 'react-router-dom';
import Header from './components/Header.jsx';
import Footer from './components/Footer.jsx';
import IconSprite from './components/IconSprite.jsx';
import ScrollManager from './components/ScrollManager.jsx';
import ToTop from './components/ToTop.jsx';
import Home from './pages/Home.jsx';
import JobCard from './pages/JobCard.jsx';
import Features from './pages/Features.jsx';
import Contact from './pages/Contact.jsx';
import Privacy from './pages/Privacy.jsx';
import Terms from './pages/Terms.jsx';
import NotFound from './pages/NotFound.jsx';

export default function App() {
  return (
    <>
      <IconSprite />
      <ScrollManager />
      <a className="skip-link" href="#main">Skip to content</a>
      <Header />
      <main id="main">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/features" element={<Features />} />
          <Route path="/contact" element={<Contact />} />
          <Route path="/privacy" element={<Privacy />} />
          <Route path="/terms" element={<Terms />} />
          {/* The link a workshop sends over WhatsApp. No sign-in. */}
          <Route path="/j/:token" element={<JobCard />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </main>
      <Footer />
      <ToTop />
    </>
  );
}
