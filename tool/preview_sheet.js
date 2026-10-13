// Render a contact sheet: ghost glyph (grey) + authored strokes (colored, numbered)
const fs = require('fs');
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const glyphs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const strokesFile = process.argv[3];
const out = process.argv[4];
const filter = process.argv[5] || '';
const cols = parseInt(process.argv[6] || '8');
let strokes = {};
if (strokesFile && fs.existsSync(strokesFile)) strokes = JSON.parse(fs.readFileSync(strokesFile, 'utf8'));
const colors = ['#d62828','#1d4ed8','#15803d','#b45309','#7e22ce','#0e7490','#be185d'];
let keys = Object.keys(strokes).length ? Object.keys(strokes) : Object.keys(glyphs);
if (filter) keys = keys.filter(k => filter.includes(k));
const cell = parseInt(process.env.CELL||'160'); const grid = process.env.GRID==='1';
let html = `<html><body style="margin:0;background:#fff;font-family:sans-serif"><div style="display:grid;grid-template-columns:repeat(${cols},${cell}px);gap:6px;padding:6px">`;
for (const k of keys) {
  const g = glyphs[k];
  const s = strokes[k];
  let svg = `<svg width="${cell}" height="${cell}" viewBox="-2 -2 104 104">
  <rect x="0" y="0" width="100" height="100" fill="#fffdf5" stroke="#ddd" stroke-width="0.5"/>
  <line x1="0" y1="20" x2="100" y2="20" stroke="#bbb" stroke-width="0.4" stroke-dasharray="2 2"/>
  <line x1="0" y1="78" x2="100" y2="78" stroke="#bbb" stroke-width="0.4" stroke-dasharray="2 2"/>`;
  if (grid) { for (let v=10; v<100; v+=10) { svg += `<line x1="${v}" y1="0" x2="${v}" y2="100" stroke="#e3e3e3" stroke-width="0.3"/><line x1="0" y1="${v}" x2="100" y2="${v}" stroke="#e3e3e3" stroke-width="0.3"/><text x="${v}" y="99" font-size="3" fill="#999" text-anchor="middle">${v}</text><text x="1" y="${v+1}" font-size="3" fill="#999">${v}</text>`; } }
  if (g) svg += `<path d="${g.d}" fill="#cfd8dc" fill-opacity="0.9"/>`;
  if (s) {
    (s.strokes || s).forEach((st, i) => {
      const d = typeof st === 'string' ? st : st.d;
      svg += `<path d="${d}" fill="none" stroke="${colors[i % colors.length]}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" opacity="0.85"/>`;
      // start marker
      svg += `<path id="p${i}" d="${d}" fill="none" stroke="none"/>`;
    });
  }
  svg += `</svg>`;
  html += `<div style="position:relative">${svg}<div style="position:absolute;left:4px;top:2px;font-size:18px;font-weight:bold">${k}</div></div>`;
}
html += `</div><script>
document.querySelectorAll('svg').forEach(svg=>{
  svg.querySelectorAll('path[id^=p]').forEach((p,i)=>{
    const L=p.getTotalLength(); const a=p.getPointAtLength(0); const b=p.getPointAtLength(Math.max(0,L-0.01)); const m=p.getPointAtLength(L*0.5); const m2=p.getPointAtLength(L*0.52);
    const ns='http://www.w3.org/2000/svg';
    const c=document.createElementNS(ns,'circle'); c.setAttribute('cx',a.x);c.setAttribute('cy',a.y);c.setAttribute('r',3);c.setAttribute('fill','#111'); svg.appendChild(c);
    const t=document.createElementNS(ns,'text'); t.setAttribute('x',a.x);t.setAttribute('y',a.y+1.6);t.setAttribute('font-size','4.5');t.setAttribute('fill','#fff');t.setAttribute('text-anchor','middle');t.textContent=String(i+1); svg.appendChild(t);
    const ang=Math.atan2(m2.y-m.y,m2.x-m.x);
    const ar=document.createElementNS(ns,'path'); ar.setAttribute('d',\`M \${m.x} \${m.y} l \${-4*Math.cos(ang-0.5)} \${-4*Math.sin(ang-0.5)} M \${m.x} \${m.y} l \${-4*Math.cos(ang+0.5)} \${-4*Math.sin(ang+0.5)}\`); ar.setAttribute('stroke','#000'); ar.setAttribute('stroke-width','0.9'); ar.setAttribute('fill','none'); svg.appendChild(ar);
    const e=document.createElementNS(ns,'rect'); e.setAttribute('x',b.x-1.5);e.setAttribute('y',b.y-1.5);e.setAttribute('width',3);e.setAttribute('height',3);e.setAttribute('fill','#000'); svg.appendChild(e);
  });
});
</script></body></html>`;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: cols * (cell + 6) + 12, height: 800 } });
  await p.setContent(html);
  await p.screenshot({ path: out, fullPage: true });
  await b.close();
  console.log('wrote', out, keys.length, 'cells');
})();
