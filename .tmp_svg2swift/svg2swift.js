// 将 SVG path d 采样为 Swift CGPoint 子路径数组
function parsePath(d) {
  const tokens = d.match(/[a-zA-Z]|-?\d*\.?\d+(?:e[-+]?\d+)?/gi);
  let i = 0;
  const peek = () => tokens[i];
  const num = () => parseFloat(tokens[i++]);
  let cx = 0, cy = 0, sx = 0, sy = 0; // current / subpath start
  let lastC = null; // 上个三次曲线第二控制点（S 用）
  const subpaths = [];

  const cubic = (p0, p1, p2, p3, n) => {
    const pts = [];
    for (let k = 1; k <= n; k++) {
      const t = k / n, u = 1 - t;
      pts.push({
        x: u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x,
        y: u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y,
      });
    }
    return pts;
  };

  const arc = (x0, y0, rx, ry, phiDeg, largeArc, sweep, x1, y1, n) => {
    // endpoint -> center 参数化 (SVG 规范 F.6.5)
    const phi = phiDeg * Math.PI / 180;
    const cosP = Math.cos(phi), sinP = Math.sin(phi);
    const dx2 = (x0 - x1) / 2, dy2 = (y0 - y1) / 2;
    const x1p = cosP * dx2 + sinP * dy2;
    const y1p = -sinP * dx2 + cosP * dy2;
    rx = Math.abs(rx); ry = Math.abs(ry);
    const lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
    if (lam > 1) { const s = Math.sqrt(lam); rx *= s; ry *= s; }
    let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
    const den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
    let co = Math.sqrt(Math.max(0, num / den));
    if (largeArc === sweep) co = -co;
    const cxp = co * rx * y1p / ry, cyp = -co * ry * x1p / rx;
    const ox = cosP * cxp - sinP * cyp + (x0 + x1) / 2;
    const oy = sinP * cxp + cosP * cyp + (y0 + y1) / 2;
    const ang = (ux, uy, vx, vy) => {
      const dot = ux * vx + uy * vy;
      const len = Math.hypot(ux, uy) * Math.hypot(vx, vy);
      let a = Math.acos(Math.min(1, Math.max(-1, dot / len)));
      if (ux * vy - uy * vx < 0) a = -a;
      return a;
    };
    const theta1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
    let dTheta = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
    if (!sweep && dTheta > 0) dTheta -= 2 * Math.PI;
    if (sweep && dTheta < 0) dTheta += 2 * Math.PI;
    const pts = [];
    for (let k = 1; k <= n; k++) {
      const t = k / n, th = theta1 + dTheta * t;
      pts.push({
        x: ox + rx * Math.cos(th) * cosP - ry * Math.sin(th) * sinP,
        y: oy + rx * Math.cos(th) * sinP + ry * Math.sin(th) * cosP,
      });
    }
    return pts;
  };

  while (i < tokens.length) {
    const cmd = tokens[i++];
    const rel = cmd === cmd.toLowerCase();
    const C = cmd.toUpperCase();
    if ('MCLSA'.includes(C)) lastC = null;
    let cur = null;
    if (!subpaths.length || subpaths[subpaths.length - 1].closed) subpaths.push({ pts: [], closed: false });
    cur = subpaths[subpaths.length - 1];
    const push = (...ps) => ps.forEach(p => { if (cur.pts.length === 0 || Math.hypot(p.x - cur.pts[cur.pts.length - 1].x, p.y - cur.pts[cur.pts.length - 1].y) > 1e-4) cur.pts.push(p); });
    const mv = (x, y) => { if (cur.pts.length) { subpaths.push({ pts: [], closed: false }); cur = subpaths[subpaths.length - 1]; } sx = x; sy = y; cx = x; cy = y; cur.pts.push({ x, y }); };

    switch (C) {
      case 'M': { let x = num() + (rel ? cx : 0), y = num() + (rel ? cy : 0); mv(x, y);
        while (peek() !== undefined && !isNaN(parseFloat(peek()))) { x = num() + (rel ? cx : 0); y = num() + (rel ? cy : 0); push({ x, y }); cx = x; cy = y; } break; }
      case 'L': { while (peek() !== undefined && !isNaN(parseFloat(peek()))) { const x = num() + (rel ? cx : 0), y = num() + (rel ? cy : 0); push({ x, y }); cx = x; cy = y; } break; }
      case 'H': { while (peek() !== undefined && !isNaN(parseFloat(peek()))) { const x = num() + (rel ? cx : 0); push({ x, y: cy }); cx = x; } break; }
      case 'V': { while (peek() !== undefined && !isNaN(parseFloat(peek()))) { const y = num() + (rel ? cy : 0); push({ x: cx, y }); cy = y; } break; }
      case 'C': { while (i + 6 <= tokens.length && !isNaN(parseFloat(peek()))) {
          const p1 = { x: num() + (rel ? cx : 0), y: num() + (rel ? cy : 0) };
          const p2 = { x: num() + (rel ? cx : 0), y: num() + (rel ? cy : 0) };
          const p3 = { x: num() + (rel ? cx : 0), y: num() + (rel ? cy : 0) };
          push(...cubic({ x: cx, y: cy }, p1, p2, p3, 24)); cx = p3.x; cy = p3.y; lastC = p2; } break; }
      case 'S': { while (i + 4 <= tokens.length && !isNaN(parseFloat(peek()))) {
          const p2 = { x: num() + (rel ? cx : 0), y: num() + (rel ? cy : 0) };
          const p3 = { x: num() + (rel ? cx : 0), y: num() + (rel ? cy : 0) };
          const p1 = lastC ? { x: 2 * cx - lastC.x, y: 2 * cy - lastC.y } : { x: cx, y: cy };
          push(...cubic({ x: cx, y: cy }, p1, p2, p3, 24)); cx = p3.x; cy = p3.y; lastC = p2; } break; }
      case 'A': { while (i + 7 <= tokens.length && !isNaN(parseFloat(peek()))) {
          const rx = num(), ry = num(), rot = num(), laf = num(), sf = num();
          const x = num() + (rel ? cx : 0), y = num() + (rel ? cy : 0);
          push(...arc(cx, cy, rx, ry, rot, laf, sf, x, y, 24)); cx = x; cy = y; } break; }
      case 'Z': { cur.closed = true; cx = sx; cy = sy; break; }
      case 'Q': case 'T': throw new Error('Q/T 未实现');
      default: throw new Error('未知命令 ' + cmd);
    }
  }
  return subpaths.filter(s => s.pts.length > 1);
}

function toSwift(name, d, dec = 1, step = 2) {
  const subs = parsePath(d).map(s => ({ pts: s.pts.filter((_, i) => i % step === 0 || i === s.pts.length - 1), closed: s.closed }));
  const lines = subs.map(s => {
    const nums = s.pts.map(p => `${(p.x).toFixed(dec)},${(p.y).toFixed(dec)}`).join(',');
    return `    [${nums}]`;
  });
  return `let ${name}: [[CGFloat]] = [\n${lines.join(',\n')}\n]`;
}

const openAI = 'M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3975.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z';

const petHair = 'M10 14c0-5 4.5-8 10-8s10 3 10 8v16H10V14z';
const petSweater = 'M6 40c1-8 6-12 14-12s13 4 14 12H6z';
const petCat = 'M12 27c0-3.5 3-6 7-6s7 2.5 7 6v13H12V27z';

console.log('// ---- OpenAI logo (viewBox 24) ----');
console.log(toSwift('openAIPath', openAI, 1, 2));
console.log();
console.log('// ---- Pet thumbnail (viewBox 40) ----');
console.log(toSwift('petHair', petHair, 1, 1));
console.log(toSwift('petSweater', petSweater, 1, 1));
console.log(toSwift('petCat', petCat, 1, 1));
