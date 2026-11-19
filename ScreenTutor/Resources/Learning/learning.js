'use strict';
const root = document.getElementById('root');
const blocks = new Map();
const allowedTags = new Set(('p br strong em del ul ol li blockquote pre code h1 h2 h3 h4 table thead tbody tr th td a hr span div details summary '
  + 'svg g path rect circle ellipse line polyline polygon text tspan defs marker lineargradient stop title desc').split(' '));
const svgAttrs = new Set(('viewbox width height x y x1 x2 y1 y2 cx cy r rx ry d points fill stroke stroke-width opacity '
  + 'transform text-anchor font-size font-weight id marker-end marker-start refx refy markerwidth markerheight orient offset stop-color').split(' '));
function post(type, fields = {}) { window.webkit?.messageHandlers.learning?.postMessage({ type, ...fields }); }
function text(tag, value, className) {
  const node = document.createElement(tag); node.textContent = value;
  if (className) node.className = className;
  return node;
}
function sanitize(html) {
  const documentFragment = new DOMParser().parseFromString(html, 'text/html');
  for (const element of [...documentFragment.body.querySelectorAll('*')]) {
    if (!allowedTags.has(element.tagName.toLowerCase())) { element.remove(); continue; }
    for (const attribute of [...element.attributes]) {
      const name = attribute.name.toLowerCase();
      const value = attribute.value.trim();
      const safeLink = element.tagName === 'A' && name === 'href' && /^(https?:|screentutor-source:)/i.test(value);
      const safeClass = name === 'class' && /^(language-[a-z0-9_-]+)$/.test(value);
      const safeSVG = element.namespaceURI === 'http://www.w3.org/2000/svg' && svgAttrs.has(name)
        && !/javascript:|data:|https?:|\/\/|url\((?!#)/i.test(value);
      if (!safeLink && !safeClass && !safeSVG) element.removeAttribute(attribute.name);
    }
  }
  return documentFragment.body.innerHTML;
}
function markdown(value) {
  const math = [];
  const protectedText = value.replace(/\$\$[\s\S]+?\$\$|\$[^$\n]+?\$/g, match => {
    math.push(match); return 'MATHPLACEHOLDER' + (math.length - 1) + 'END';
  });
  return sanitize(marked.parse(protectedText)).replace(/MATHPLACEHOLDER(\d+)END/g, (_, i) => {
    const node = document.createElement('span'); node.textContent = math[Number(i)]; return node.innerHTML;
  });
}
async function enrich(node) {
  try {
    renderMathInElement(node, { delimiters: [
      {left:'$$',right:'$$',display:true}, {left:'$',right:'$',display:false},
      {left:'\\[',right:'\\]',display:true}, {left:'\\(',right:'\\)',display:false}
    ], throwOnError:true });
    const diagrams = [...node.querySelectorAll('pre code.language-mermaid')].map(code => {
      const diagram = text('div', code.textContent, 'mermaid'); code.parentElement.replaceWith(diagram); return diagram;
    });
    if (diagrams.length) await mermaid.run({ nodes: diagrams });
  } catch (error) {
    node.append(text('p', 'This visual could not be rendered: ' + String(error.message || error), 'render-error'));
  }
}
function contentBlock(key, signature, build) {
  let entry = blocks.get(key);
  if (!entry) { entry = {node:document.createElement('article'),signature:null}; blocks.set(key, entry); }
  if (entry.signature !== signature) { entry.signature = signature; build(entry.node); }
  return entry.node;
}
function actionButton(label, action) {
  const button = text('button', label); button.type = 'button'; button.onclick = action; return button;
}
function artifactNode(artifact, focused) {
  return contentBlock('artifact-' + artifact.id, JSON.stringify([artifact,focused]), node => {
    node.className = 'artifact' + (focused ? ' focused' : '');
    node.replaceChildren();
    const header = document.createElement('header');
    const title = document.createElement('div');
    title.append(text('div',artifact.section,'section-label'), text('h2',artifact.title));
    const focus = actionButton('Focus', () => post('focus',{id:artifact.id})); focus.className = 'focus-button';
    header.append(title, focus);
    const body = document.createElement('div'); body.className = 'content'; body.innerHTML = markdown(artifact.markdown);
    if (artifact.flashcard) {
      const card = artifact.flashcard;
      const controls = document.createElement('div'); controls.className = 'flashcard-actions';
      if (!card.revealed) controls.append(actionButton('Reveal answer', () => post('flashcard',{id:artifact.id,action:'reveal'})));
      else {
        const answer = document.createElement('div'); answer.className = 'flashcard-answer'; answer.innerHTML = markdown(card.answer);
        body.append(answer);
        controls.append(actionButton('Again',()=>post('flashcard',{id:artifact.id,action:'again'})),
          actionButton('Recalled',()=>post('flashcard',{id:artifact.id,action:'recalled'})));
      }
      if (card.selfRating) controls.append(text('span','Self-check: ' + card.selfRating,'rating'));
      body.append(controls);
    }
    node.append(header,body); void enrich(body);
  });
}
function messageNode(message, artifacts) {
  if (message.artifactID) {
    const artifact = artifacts.find(item => item.id === message.artifactID);
    if (artifact) return artifactNode(artifact,false);
  }
  return contentBlock('message-' + message.id, JSON.stringify(message), node => {
    node.className = 'message ' + message.role;
    const body = document.createElement('div'); body.innerHTML = markdown(message.text);
    node.replaceChildren(text('div',message.role === 'user' ? 'You' : 'Tutor','speaker'),body);
    void enrich(body);
  });
}
window.renderLearning = function(payload) {
  document.body.className = payload.mode === 'canvas' && payload.focusOnly ? 'focus-mode' : payload.mode;
  if (!window.marked || !window.katex || !window.mermaid || !window.renderMathInElement) {
    root.replaceChildren(text('p','Learning renderers did not load. Reopen the workspace.','render-error')); return;
  }
  const nearBottom = window.innerHeight + window.scrollY >= document.body.scrollHeight - 100;
  const nodes = [];
  if (payload.mode === 'conversation') {
    for (const message of payload.messages) nodes.push(messageNode(message,payload.artifacts));
    const last = payload.messages[payload.messages.length - 1];
    if (payload.liveAssistant && !(last?.role === 'assistant' && last.text === payload.liveAssistant)) {
      const live = messageNode({id:'live',role:'assistant',text:payload.liveAssistant},payload.artifacts);
      live.classList.add('live'); nodes.push(live);
    }
  } else {
    const artifacts = payload.focusOnly && payload.focusedID
      ? payload.artifacts.filter(item=>item.id === payload.focusedID) : payload.artifacts;
    const sections = [...new Set(artifacts.map(item=>item.section))];
    for (const section of sections) {
      nodes.push(text('h2',section,'section-title'));
      const grid = document.createElement('section'); grid.className = 'grid';
      for (const artifact of artifacts.filter(item=>item.section === section)) grid.append(artifactNode(artifact,artifact.id===payload.focusedID));
      nodes.push(grid);
    }
  }
  if (!nodes.length) {
    const empty = document.createElement('div'); empty.className = 'empty';
    empty.append(text('h2',payload.mode === 'conversation' ? 'What do you want to understand?' : 'One idea at a time.'),
      text('p',payload.mode === 'conversation' ? 'Choose a course, then talk or write to your tutor. Start with your own attempt.'
        : 'Explanations, diagrams, practice questions and flashcards will collect here as you learn.'));
    nodes.push(empty);
  }
  root.replaceChildren(...nodes);
  if (payload.mode === 'conversation' && nearBottom) requestAnimationFrame(()=>window.scrollTo(0,document.body.scrollHeight));
};
document.addEventListener('click', event => {
  const link = event.target.closest('a');
  if (link?.href) { event.preventDefault(); post('link',{url:link.href}); }
});
mermaid.initialize({startOnLoad:false,securityLevel:'strict',theme:matchMedia('(prefers-color-scheme:dark)').matches?'dark':'neutral'});
post('ready');
