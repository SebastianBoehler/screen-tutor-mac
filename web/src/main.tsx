import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './styles/tokens.css';
import './styles/sidebar.css';
import './styles/shell.css';
import './styles/learning.css';
import './styles/empty.css';
import './styles/composer.css';
import './styles/learning-responsive.css';
import './styles/forms.css';
import './styles/pages.css';

performance.mark('screentutor-client-start');
createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

import './styles/interactive.css';
