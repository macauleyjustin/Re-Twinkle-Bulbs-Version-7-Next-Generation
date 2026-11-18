package core

import (
	"crypto/rand"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

// WebServer exposes the full Remote Web Command Center, REST API, and RFC 6455 WebSocket stream.
type WebServer struct {
	mu       sync.RWMutex
	engine   *Engine
	synth    *TwinkleSynth
	tokens   map[string]bool
	wsConns  map[net.Conn]bool
	listener net.Listener
	latest   []BulbCoord
}

func NewWebServer(engine *Engine, synth *TwinkleSynth) *WebServer {
	return &WebServer{
		engine:  engine,
		synth:   synth,
		tokens:  make(map[string]bool),
		wsConns: make(map[net.Conn]bool),
	}
}

func (ws *WebServer) Start(port int) (int, error) {
	addr := fmt.Sprintf("127.0.0.1:%d", port)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		ln, err = net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			return 0, err
		}
	}
	ws.mu.Lock()
	ws.listener = ln
	ws.mu.Unlock()
	actualPort := ln.Addr().(*net.TCPAddr).Port

	mux := http.NewServeMux()
	mux.HandleFunc("/", ws.handleDashboard)
	mux.HandleFunc("/remote", ws.handleDashboard)
	mux.HandleFunc("/v1/health", ws.handleHealth)
	mux.HandleFunc("/v1/pair", ws.handlePair)
	mux.HandleFunc("/v1/status", ws.requireAuth(ws.handleStatus))
	mux.HandleFunc("/v1/catalog", ws.requireAuth(ws.handleCatalog))
	mux.HandleFunc("/v1/control", ws.requireAuth(ws.handleControl))
	mux.HandleFunc("/v1/scene", ws.requireAuth(ws.handleScene))
	mux.HandleFunc("/v1/blackout", ws.requireAuth(ws.handleBlackout))
	mux.HandleFunc("/v1/docs", ws.handleDocs)
	mux.HandleFunc("/v1/stream", ws.handleWS)

	srv := &http.Server{Handler: mux}
	go func() {
		_ = srv.Serve(ln)
	}()
	return actualPort, nil
}

func (ws *WebServer) Stop() {
	ws.mu.Lock()
	defer ws.mu.Unlock()
	if ws.listener != nil {
		_ = ws.listener.Close()
		ws.listener = nil
	}
	for c := range ws.wsConns {
		_ = c.Close()
		delete(ws.wsConns, c)
	}
}

func (ws *WebServer) BroadcastFrame(bulbs []BulbCoord) {
	ws.mu.Lock()
	ws.latest = make([]BulbCoord, len(bulbs))
	copy(ws.latest, bulbs)
	conns := make([]net.Conn, 0, len(ws.wsConns))
	for c := range ws.wsConns {
		conns = append(conns, c)
	}
	ws.mu.Unlock()

	if len(conns) == 0 {
		return
	}
	pkt := EncodeTWKLFrame(bulbs)
	frame := buildWSBinaryFrame(pkt)
	for _, c := range conns {
		_ = c.SetWriteDeadline(time.Now().Add(300 * time.Millisecond))
		if _, err := c.Write(frame); err != nil {
			ws.mu.Lock()
			delete(ws.wsConns, c)
			ws.mu.Unlock()
			_ = c.Close()
		}
	}
}

func EncodeTWKLFrame(bulbs []BulbCoord) []byte {
	hdr := 8
	pkt := make([]byte, hdr+len(bulbs)*4)
	copy(pkt[0:4], "TWKL")
	pkt[4] = 1
	binary.LittleEndian.PutUint16(pkt[5:7], uint16(len(bulbs)))
	for i, b := range bulbs {
		off := hdr + i*4
		pkt[off+0] = uint8(float64(b.Color.R) * b.Intensity)
		pkt[off+1] = uint8(float64(b.Color.G) * b.Intensity)
		pkt[off+2] = uint8(float64(b.Color.B) * b.Intensity)
		if b.On {
			pkt[off+3] = 255
		} else {
			pkt[off+3] = uint8(b.Intensity * 255)
		}
	}
	return pkt
}

func buildWSBinaryFrame(payload []byte) []byte {
	n := len(payload)
	var hdr []byte
	if n < 126 {
		hdr = []byte{0x82, byte(n)}
	} else {
		hdr = make([]byte, 4)
		hdr[0] = 0x82
		hdr[1] = 126
		binary.BigEndian.PutUint16(hdr[2:4], uint16(n))
	}
	out := make([]byte, len(hdr)+n)
	copy(out, hdr)
	copy(out[len(hdr):], payload)
	return out
}

func (ws *WebServer) isAuthorized(r *http.Request) bool {
	cfg := ws.engine.Config()
	pin := r.Header.Get("X-Twinkle-PIN")
	if pin == "" {
		pin = r.URL.Query().Get("pin")
	}
	if pin != "" && pin == cfg.PairingPIN {
		return true
	}
	auth := r.Header.Get("Authorization")
	if strings.HasPrefix(auth, "Bearer ") {
		tok := strings.TrimPrefix(auth, "Bearer ")
		ws.mu.RLock()
		ok := ws.tokens[tok]
		ws.mu.RUnlock()
		return ok
	}
	return false
}

func (ws *WebServer) requireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !ws.isAuthorized(r) {
			http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

func (ws *WebServer) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":      true,
		"app":     AppTitle,
		"version": AppVersion,
		"credit":  OriginalCredit,
	})
}

func (ws *WebServer) handleDocs(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = w.Write([]byte(FullDocumentationText()))
}

func (ws *WebServer) handlePair(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		PIN string `json:"pin"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	cfg := ws.engine.Config()
	if req.PIN != cfg.PairingPIN {
		http.Error(w, `{"error":"invalid_pin"}`, http.StatusUnauthorized)
		return
	}
	raw := make([]byte, 16)
	_, _ = rand.Read(raw)
	tok := hex.EncodeToString(raw)
	ws.mu.Lock()
	ws.tokens[tok] = true
	ws.mu.Unlock()
	writeJSON(w, http.StatusOK, map[string]any{"token": tok})
}

func (ws *WebServer) handleStatus(w http.ResponseWriter, r *http.Request) {
	ws.mu.RLock()
	frames := make([]BulbCoord, len(ws.latest))
	copy(frames, ws.latest)
	ws.mu.RUnlock()
	writeJSON(w, http.StatusOK, map[string]any{
		"version": AppVersion,
		"config":  ws.engine.Config(),
		"bulbs":   frames,
	})
}

func (ws *WebServer) handleCatalog(w http.ResponseWriter, r *http.Request) {
	tracks := ws.synth.Tracks()
	trackNames := make([]string, len(tracks))
	for i, t := range tracks {
		trackNames[i] = t.Title
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"bulbSets":       ws.engine.Catalog(),
		"flashModes":     FlashModeNames,
		"flashRates":     FlashRateNames,
		"colorModes":     ColorModeNames,
		"placements":     PlacementNames,
		"modernEffects":  ModernEffectNames,
		"modernPalettes": ModernPaletteNames,
		"scenes":         ws.engine.Scenes(),
		"musicTracks":    trackNames,
	})
}

func (ws *WebServer) handleBlackout(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		Blackout bool `json:"blackout"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	ws.engine.UpdateSettings(func(s *Settings) {
		s.Blackout = req.Blackout
	})
	writeJSON(w, http.StatusOK, map[string]any{"blackout": req.Blackout})
}

func (ws *WebServer) handleScene(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		Action  string `json:"action"`
		SceneID string `json:"sceneId"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	switch req.Action {
	case "restore":
		ws.engine.RestorePrevious()
	case "classic":
		ws.engine.ReturnToClassic()
	default:
		if !ws.engine.ActivateScene(req.SceneID) {
			http.Error(w, `{"error":"unknown_scene"}`, http.StatusNotFound)
			return
		}
	}
	cfg := ws.engine.Config()
	ws.synth.SetState(cfg.MusicPlaying, cfg.MusicTrack, cfg.MusicVolume)
	writeJSON(w, http.StatusOK, map[string]any{"config": cfg})
}

func (ws *WebServer) handleControl(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	cfg := ws.engine.Config()
	if !cfg.AllowRemoteCmd {
		http.Error(w, `{"error":"remote_commands_disabled"}`, http.StatusForbidden)
		return
	}
	var patch map[string]any
	if err := json.NewDecoder(r.Body).Decode(&patch); err != nil {
		http.Error(w, `{"error":"bad_json"}`, http.StatusBadRequest)
		return
	}
	ws.engine.UpdateSettings(func(s *Settings) {
		if v, ok := patch["classicMode"].(bool); ok {
			s.ClassicMode = v
		}
		if v, ok := patch["enabled"].(bool); ok {
			s.Enabled = v
		}
		if v, ok := patch["blackout"].(bool); ok {
			s.Blackout = v
		}
		if v, ok := patch["bulbSetId"].(float64); ok {
			s.BulbSetID = int(v)
		}
		if v, ok := patch["bulbSize"].(float64); ok && (int(v) == 32 || int(v) == 48) {
			s.BulbSize = int(v)
		}
		if v, ok := patch["flashMode"].(float64); ok {
			s.FlashMode = FlashMode(int(v))
		}
		if v, ok := patch["flashRate"].(float64); ok {
			s.FlashRate = FlashRate(int(v))
		}
		if v, ok := patch["colorMode"].(float64); ok {
			s.ColorMode = int(v)
		}
		if v, ok := patch["placement"].(float64); ok {
			s.Placement = PlacementMode(int(v))
		}
		if v, ok := patch["alwaysOnTop"].(bool); ok {
			s.AlwaysOnTop = v
		}
		if v, ok := patch["bareWire"].(bool); ok {
			s.BareWire = v
		}
		if v, ok := patch["noCorners"].(bool); ok {
			s.NoCorners = v
		}
		if v, ok := patch["sparseSpacing"].(bool); ok {
			s.SparseSpacing = v
		}
		if v, ok := patch["modernEffect"].(float64); ok {
			s.ModernEffect = ModernEffect(int(v))
		}
		if v, ok := patch["modernPalette"].(float64); ok {
			s.ModernPalette = ModernPalette(int(v))
		}
		if v, ok := patch["speed"].(float64); ok {
			s.Speed = v
		}
		if v, ok := patch["brightness"].(float64); ok {
			s.Brightness = v
		}
		if v, ok := patch["musicPlaying"].(bool); ok {
			s.MusicPlaying = v
		}
		if v, ok := patch["musicTrack"].(float64); ok {
			s.MusicTrack = int(v)
		}
		if v, ok := patch["musicVolume"].(float64); ok {
			s.MusicVolume = v
		}
		if v, ok := patch["automationEnabled"].(bool); ok {
			s.Automation.Enabled = v
		}
		if v, ok := patch["vacationMode"].(bool); ok {
			s.Automation.VacationMode = v
		}
	})
	newCfg := ws.engine.Config()
	ws.synth.SetState(newCfg.MusicPlaying, newCfg.MusicTrack, newCfg.MusicVolume)
	writeJSON(w, http.StatusOK, map[string]any{"config": newCfg})
}

func (ws *WebServer) handleWS(w http.ResponseWriter, r *http.Request) {
	if !ws.isAuthorized(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	key := r.Header.Get("Sec-WebSocket-Key")
	if key == "" {
		http.Error(w, "Missing Sec-WebSocket-Key", http.StatusBadRequest)
		return
	}
	hj, ok := w.(http.Hijacker)
	if !ok {
		http.Error(w, "Hijack unsupported", http.StatusInternalServerError)
		return
	}
	conn, buf, err := hj.Hijack()
	if err != nil {
		return
	}
	sum := sha1.Sum([]byte(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
	accept := base64.StdEncoding.EncodeToString(sum[:])
	resp := "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + "\r\n\r\n"
	_, _ = buf.WriteString(resp)
	_ = buf.Flush()

	ws.mu.Lock()
	ws.wsConns[conn] = true
	ws.mu.Unlock()
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func (ws *WebServer) handleDashboard(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(remoteDashboardHTML))
}

const remoteDashboardHTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Re: Twinkle Bulbs v7.0 — Remote Command Center</title>
<style>
  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#0e1624;color:#edf2f7;margin:0;padding:16px;}
  .wrap{max-width:960px;margin:0 auto;}
  .hdr{display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #24344d;padding-bottom:12px;margin-bottom:14px;}
  .card{background:#152236;border:1px solid #263954;border-radius:10px;padding:14px;margin-bottom:12px;}
  .tabs{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px;}
  button,select,input{background:#1e304c;color:#edf2f7;border:1px solid #35527a;border-radius:6px;padding:7px 11px;font-size:14px;}
  button{cursor:pointer;} button:hover{background:#29436b;}
  .danger{background:#9b1c1c;border-color:#c53030;} .gold{background:#9c6514;border-color:#d69e2e;}
  canvas{width:100%;height:78px;background:#080d16;border-radius:8px;border:1px solid #263954;}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:10px;}
  pre{white-space:pre-wrap;font-size:12.5px;line-height:1.5;background:#0a111d;padding:12px;border-radius:8px;max-height:420px;overflow:auto;}
</style>
</head>
<body><div class="wrap">
  <div class="hdr">
    <div><h2 style="margin:0">Re: Twinkle Bulbs — Version 7: Next Generation</h2><small>Tribute to Don Metzler & Barefoot Productions • Freeware</small></div>
    <div>PIN: <input id="pin" value="122570" style="width:86px"> <button onclick="pair()">Connect</button> <button class="danger" onclick="blackout(true)">Blackout</button> <button onclick="blackout(false)">Resume</button></div>
  </div>
  <div class="card"><canvas id="vis" width="900" height="78"></canvas></div>
  <div class="tabs">
    <button onclick="tab('t1')">Classic &amp; Modern Lights</button>
    <button onclick="tab('t2')">Holiday Scenes</button>
    <button onclick="tab('t3')">Music &amp; Automation</button>
    <button onclick="tab('t4')">History, Manual &amp; Credits</button>
  </div>
  <div id="t1" class="card grid">
    <div><label>Engine Mode</label><br><select id="mode" onchange="ctrl({classicMode:this.value==='classic'})"><option value="classic">Classic v6.0 Authentic</option><option value="modern">Modern 60fps Shader</option></select></div>
    <div><label>Bulb Set (265)</label><br><select id="bulbSet" onchange="ctrl({bulbSetId:+this.value})"></select></div>
    <div><label>Bulb Size</label><br><select id="bulbSize" onchange="ctrl({bulbSize:+this.value})"><option value="32">Normal (32px)</option><option value="48">Large (48px)</option></select></div>
    <div><label>Classic Flash Mode</label><br><select id="flashMode" onchange="ctrl({flashMode:+this.value})"></select></div>
    <div><label>Classic Flash Rate</label><br><select id="flashRate" onchange="ctrl({flashRate:+this.value})"></select></div>
    <div><label>Classic Color Mode</label><br><select id="colorMode" onchange="ctrl({colorMode:+this.value})"></select></div>
    <div><label>Modern Effect</label><br><select id="modernEffect" onchange="ctrl({modernEffect:+this.value})"></select></div>
    <div><label>Modern Palette</label><br><select id="modernPalette" onchange="ctrl({modernPalette:+this.value})"></select></div>
    <div><label>Placement</label><br><select id="placement" onchange="ctrl({placement:+this.value})"></select></div>
    <div><label>Brightness</label><br><input id="bright" type="range" min="0.1" max="1" step="0.05" value="1" oninput="ctrl({brightness:+this.value})"></div>
    <div><label>Speed</label><br><input id="speed" type="range" min="0.25" max="3" step="0.05" value="1" oninput="ctrl({speed:+this.value})"></div>
  </div>
  <div id="t2" class="card" style="display:none"><div id="scenesGrid" class="grid"></div><br><button class="gold" onclick="sceneAction('classic')">Return to Classic</button> <button onclick="sceneAction('restore')">Restore Previous</button></div>
  <div id="t3" class="card grid" style="display:none">
    <div><label>Jukebox Carols (105)</label><br><select id="track" onchange="ctrl({musicTrack:+this.value})"></select></div>
    <div><button onclick="ctrl({musicPlaying:true})">Play Music</button> <button onclick="ctrl({musicPlaying:false})">Stop Music</button></div>
    <div><label>Volume</label><br><input type="range" min="0" max="1.2" step="0.05" value="0.75" oninput="ctrl({musicVolume:+this.value})"></div>
    <div><label><input type="checkbox" id="autoEn" onchange="ctrl({automationEnabled:this.checked})"> Enable Seasonal Automation</label></div>
    <div><label><input type="checkbox" id="vacEn" onchange="ctrl({vacationMode:this.checked})"> Vacation Safe Blackout</label></div>
  </div>
  <div id="t4" class="card" style="display:none"><pre id="docText">Loading documentation...</pre></div>
</div>
<script>
let tok = '';
function hdr(){ return {'Content-Type':'application/json', 'Authorization':'Bearer '+tok, 'X-Twinkle-PIN':document.getElementById('pin').value}; }
async function pair(){
  const r = await fetch('/v1/pair',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({pin:document.getElementById('pin').value})});
  if(r.ok){ tok=(await r.json()).token; await loadCat(); } else alert('Invalid PIN');
}
async function loadCat(){
  const cat = await (await fetch('/v1/catalog',{headers:hdr()})).json();
  fill('bulbSet', cat.bulbSets.map((b,i)=>[b.id, b.name]));
  fill('flashMode', cat.flashModes.map((n,i)=>[i, n]));
  fill('flashRate', cat.flashRates.map((n,i)=>[i, n]));
  fill('colorMode', cat.colorModes.map((n,i)=>[i, n]));
  fill('modernEffect', cat.modernEffects.map((n,i)=>[i, n]));
  fill('modernPalette', cat.modernPalettes.map((n,i)=>[i, n]));
  fill('placement', cat.placements.map((n,i)=>[i, n]));
  fill('track', cat.musicTracks.map((n,i)=>[i, n]));
  const sg = document.getElementById('scenesGrid'); sg.innerHTML='';
  cat.scenes.forEach(sc=>{ const btn=document.createElement('button'); btn.textContent=sc.name; btn.onclick=()=>sceneAction('activate',sc.id); sg.appendChild(btn); });
  document.getElementById('docText').textContent = await (await fetch('/v1/docs')).text();
  poll();
}
function fill(id,pairs){ const el=document.getElementById(id); el.innerHTML=''; pairs.forEach(([v,t])=>{const o=document.createElement('option');o.value=v;o.textContent=t;el.appendChild(o);}); }
async function ctrl(p){ await fetch('/v1/control',{method:'POST',headers:hdr(),body:JSON.stringify(p)}); }
async function blackout(v){ await fetch('/v1/blackout',{method:'POST',headers:hdr(),body:JSON.stringify({blackout:v})}); }
async function sceneAction(action,sceneId){ await fetch('/v1/scene',{method:'POST',headers:hdr(),body:JSON.stringify({action,sceneId})}); }
function tab(id){ ['t1','t2','t3','t4'].forEach(x=>document.getElementById(x).style.display=(x===id?(x==='t1'||x==='t3'?'grid':'block'):'none')); }
async function poll(){
  try{
    const r = await fetch('/v1/status',{headers:hdr()});
    if(r.ok){
      const d = await r.json();
      const ctx = document.getElementById('vis').getContext('2d');
      ctx.clearRect(0,0,900,78);
      ctx.strokeStyle='#1b5e20'; ctx.lineWidth=3; ctx.beginPath(); ctx.moveTo(10,16); ctx.lineTo(890,16); ctx.stroke();
      const bs=d.bulbs||[];
      bs.forEach((b,i)=>{
        const x = 18 + (i/Math.max(1,bs.length-1))*864;
        const it = b.intensity||0;
        const r=Math.round(b.color.R*it), g=Math.round(b.color.G*it), bl=Math.round(b.color.B*it);
        ctx.fillStyle='rgba('+r+','+g+','+bl+',0.95)';
        ctx.beginPath(); ctx.ellipse(x,44,8,14,0,0,Math.PI*2); ctx.fill();
      });
    }
  }catch(e){}
  setTimeout(poll, 180);
}
pair();
</script></body></html>`
