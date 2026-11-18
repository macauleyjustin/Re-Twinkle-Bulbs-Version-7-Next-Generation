import Foundation
import CryptoKit

// MARK: - Part VIII: Local Mobile Phone & Desktop Web Remote Controller

public final class RemoteControlService {
    public static let shared = RemoteControlService()

    public private(set) var activePairingPIN: String
    private var activeSessionTokens: [String: Date] = [:]
    private let lock = NSLock()

    public init() {
        self.activePairingPIN = Self.generatePIN()
    }

    public static func generatePIN() -> String {
        String(format: "%06d", Int.random(in: 100000...999999))
    }

    @discardableResult
    public func rotatePairingPIN() -> String {
        lock.lock()
        let next = Self.generatePIN()
        activePairingPIN = next
        lock.unlock()
        return next
    }

    public func revokeAllSessions() {
        lock.lock()
        activeSessionTokens.removeAll()
        lock.unlock()
    }

    public func issueSessionIfPINMatches(_ submittedPIN: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let trimmed = submittedPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, constantTimeEquals(trimmed, activePairingPIN) else {
            return nil
        }
        let token = TwinkleAPIConfig.generateRandomToken(prefix: "tk_rem_")
        activeSessionTokens[token] = Date().addingTimeInterval(12 * 3600)
        return token
    }

    public func isSessionValid(_ token: String?) -> Bool {
        guard let t = token, !t.isEmpty else { return false }
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        activeSessionTokens = activeSessionTokens.filter { $0.value > now }
        return activeSessionTokens[t] != nil
    }

    /// Discovers non-loopback local IPv4 addresses cleanly via BSD getifaddrs for displaying the LAN remote URL.
    public static func localIPv4Addresses() -> [String] {
        var result: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            if let sa = cur.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: cur.pointee.ifa_name)
                if name != "lo0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        if !ip.hasPrefix("169.254.") { result.append(ip) }
                    }
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return result
    }

    private func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let da = Array(a.utf8), db = Array(b.utf8)
        guard da.count == db.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<da.count { diff |= da[i] ^ db[i] }
        return diff == 0
    }

    public static func renderMobileWebAppHTML() -> String {
        #"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <title>Re: Twinkle Bulbs — Remote Command Center</title>
        <style>
          :root{--bg:#09111e;--card:#121e33;--card2:#182742;--bd:#2a4269;--acc:#2f81f7;--ok:#2ea043;--bad:#da3633;--txt:#f0f6fc;--mut:#8b949e;}
          *{box-sizing:border-box;}
          body{margin:0;padding:14px;background:var(--bg);color:var(--txt);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;max-width:960px;margin-left:auto;margin-right:auto;}
          h1{font-size:20px;margin:0 0 10px;display:flex;align-items:center;justify-content:space-between;}
          h2{font-size:15px;margin:0 0 10px;color:#cfe2ff;}
          .card{background:var(--card);border:1px solid var(--bd);border-radius:12px;padding:14px;margin-bottom:12px;}
          .row{display:flex;flex-wrap:wrap;gap:8px;align-items:center;}
          .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:8px;}
          .grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:10px;}
          button{background:var(--acc);color:#fff;border:none;border-radius:8px;padding:9px 13px;font-size:14px;font-weight:600;cursor:pointer;}
          button:hover{filter:brightness(1.1);}
          button.danger{background:var(--bad);}
          button.ok{background:var(--ok);}
          button.sec{background:#243552;}
          button.active{outline:2px solid #ffd166;background:#1d5ab8;}
          .tabs{display:flex;gap:6px;overflow-x:auto;margin-bottom:12px;padding-bottom:4px;}
          .tabBtn{flex:1;min-width:110px;background:var(--card2);border:1px solid var(--bd);}
          .tabBtn.sel{background:var(--acc);border-color:var(--acc);}
          input[type=text],input[type=password],select{width:100%;padding:8px 10px;border-radius:8px;border:1px solid #38517a;background:#0a1424;color:#fff;font-size:14px;margin-top:4px;margin-bottom:8px;}
          input[type=range]{width:100%;accent-color:var(--acc);}
          label.chk{display:flex;align-items:center;gap:8px;font-size:13.5px;padding:4px 0;cursor:pointer;}
          label.field{display:block;font-size:12.5px;color:#b8c7de;margin-top:6px;}
          canvas#bulbCanvas{width:100%;height:48px;border-radius:8px;background:#050a14;border:1px solid #223659;display:block;margin-bottom:10px;}
          .pill{display:inline-block;padding:3px 9px;border-radius:999px;font-size:12px;background:#1b3152;color:#a5d6ff;}
          .listBox{max-height:240px;overflow-y:auto;border:1px solid #263d61;border-radius:8px;background:#0a1322;padding:6px;}
          .listItem{display:flex;justify-content:space-between;align-items:center;padding:7px 9px;border-radius:6px;cursor:pointer;font-size:13px;}
          .listItem:hover{background:#182b49;}
          .listItem.cur{background:#1f4e8c;font-weight:600;}
          small{color:var(--mut);}
        </style>
        </head>
        <body>
        <h1>
          <span>🎄 Re: Twinkle Bulbs Remote</span>
          <span id="connBadge" class="pill">Locked</span>
        </h1>

        <div id="authCard" class="card">
          <h2>Connect to Mac Controller</h2>
          <label class="field">Option A: 6-Digit Pairing PIN (shown in Mac Remote &amp; API Console)
            <input id="pinInput" type="text" placeholder="6-digit PIN" inputmode="numeric">
          </label>
          <label class="field">Option B: Developer Control Token (tk_ctrl_...)
            <input id="tokInput" type="password" placeholder="Optional Control Token">
          </label>
          <button onclick="pair()">Unlock Full Remote Control</button>
          <div id="authMsg" style="margin-top:8px;color:#ffb4a2;"></div>
        </div>

        <div id="ctrlUI" style="display:none;">
          <canvas id="bulbCanvas" width="800" height="48"></canvas>

          <div class="card">
            <div class="row" style="justify-content:space-between;margin-bottom:8px;">
              <div id="statusText" style="font-size:13.5px;font-weight:600;">Connecting...</div>
              <button class="sec" style="padding:5px 10px;font-size:12px;" onclick="logout()">Lock Session</button>
            </div>
            <div class="row">
              <button id="btnLightsOn" class="ok" onclick="cmd({action:'setLights',enabled:true})">💡 Lights ON</button>
              <button class="danger" onclick="cmd({action:'blackout'})">🛑 Blackout / OFF</button>
              <button id="btnCatClassic" class="sec" onclick="cmd({action:'setLightingCategory',lightingCategory:'classic'})">Classic v6.0</button>
              <button id="btnCatModern" class="sec" onclick="cmd({action:'setLightingCategory',lightingCategory:'modern'})">Modern 60fps</button>
              <button class="sec" onclick="cmd({action:'restorePreviousScene'})">↩ Prev Scene</button>
              <button class="sec" onclick="cmd({action:'returnToClassic'})">🕰 Return Classic</button>
            </div>
          </div>

          <div class="tabs">
            <button class="tabBtn sel" onclick="showTab('tabLights', this)">💡 Lights &amp; Bulbs</button>
            <button class="tabBtn" onclick="showTab('tabScenes', this)">🎄 Scenes &amp; FX</button>
            <button class="tabBtn" onclick="showTab('tabMusic', this)">🎼 Music &amp; MIDI</button>
            <button class="tabBtn" onclick="showTab('tabExtra', this)">⚙ Savers &amp; Smart</button>
          </div>

          <!-- TAB 1: LIGHTS & BULBS -->
          <div id="tabLights" class="tabPane">
            <div class="grid2">
              <div class="card">
                <h2>Intensity &amp; Speed</h2>
                <label class="field">Brightness (<span id="lblBr">100%</span>)
                  <input id="brRange" type="range" min="5" max="100" value="100" oninput="lblBr.innerText=this.value+'%';cmd({action:'setBrightness',value:this.value/100})">
                </label>
                <label class="field">Speed (<span id="lblSp">1.0x</span>)
                  <input id="spRange" type="range" min="10" max="300" value="100" oninput="lblSp.innerText=(this.value/100).toFixed(2)+'x';cmd({action:'setSpeed',value:this.value/100})">
                </label>
                <label class="field">Smoothness (<span id="lblSm">75%</span>)
                  <input id="smRange" type="range" min="0" max="100" value="75" oninput="lblSm.innerText=this.value+'%';cmd({action:'setSmoothness',value:this.value/100})">
                </label>
                <label class="field">Modern Effect (15)
                  <select id="selModernFx" onchange="cmd({action:'setModernEffect',effectID:parseInt(this.value)})"></select>
                </label>
                <label class="field">Modern Color Palette (9)
                  <select id="selModernPal" onchange="cmd({action:'setModernPalette',paletteID:parseInt(this.value)})"></select>
                </label>
              </div>

              <div class="card">
                <h2>Classic v6.0 Engine Modes</h2>
                <label class="field">Flashing Mode (9)
                  <select id="selClassicFlash" onchange="cmd({action:'setFlashMode',flashMode:parseInt(this.value)})"></select>
                </label>
                <label class="field">Color Mode (21)
                  <select id="selClassicColor" onchange="cmd({action:'setColorMode',colorMode:parseInt(this.value)})"></select>
                </label>
                <label class="field">Classic Flash Rate
                  <select id="selRate" onchange="cmd({action:'setRate',rate:parseInt(this.value)})"></select>
                </label>
                <label class="field">Bulb Size
                  <select id="selBulbSize" onchange="cmd({action:'setBulbSize',bulbSize:parseInt(this.value)})">
                    <option value="0">Normal (32×32)</option>
                    <option value="1">Large (48×48)</option>
                  </select>
                </label>
              </div>
            </div>

            <div class="grid2">
              <div class="card">
                <h2>265+ Bulb Sets</h2>
                <input id="bulbSearch" type="text" placeholder="Filter bulb sets (Outdoor, Holly, Icicles...)" oninput="renderBulbs()">
                <div id="bulbList" class="listBox"></div>
              </div>

              <div class="card">
                <h2>Placement, Options &amp; Defects</h2>
                <label class="field">Screen Edge Placement
                  <select id="selLoc" onchange="cmd({action:'setPlacement',location:parseInt(this.value)})">
                    <option value="0">Top of Screen</option>
                    <option value="1">Top and Bottom</option>
                    <option value="2">Around Whole Screen</option>
                    <option value="3">Sides Only</option>
                    <option value="4">Top and Sides</option>
                    <option value="5">Bottom Only</option>
                  </select>
                </label>
                <label class="field">Window Layer
                  <select id="selDrawMode" onchange="cmd({action:'setPlacement',drawMode:parseInt(this.value)})">
                    <option value="0">On the Desktop</option>
                    <option value="1">Always On Top</option>
                    <option value="2">Menu Bar Level</option>
                  </select>
                </label>
                <div class="grid">
                  <label class="chk"><input type="checkbox" id="chkAllMon" onchange="cmd({action:'setPlacement',useAllMonitors:this.checked})"> All Monitors</label>
                  <label class="chk"><input type="checkbox" id="chkRev" onchange="cmd({action:'setReverse',enabled:this.checked})"> Reverse Direction</label>
                  <label class="chk"><input type="checkbox" id="chkInw" onchange="cmd({action:'setPlacement',inward:this.checked})"> Point Inward</label>
                  <label class="chk"><input type="checkbox" id="chkBare" onchange="cmd({action:'setPlacement',bareWire:this.checked})"> Bare Wire</label>
                  <label class="chk"><input type="checkbox" id="chkSparse" onchange="cmd({action:'setPlacement',notSoMany:this.checked})"> Sparse Spacing</label>
                  <label class="chk"><input type="checkbox" id="chkCorners" onchange="cmd({action:'setPlacement',noCorners:this.checked})"> Clear Corners</label>
                  <label class="chk"><input type="checkbox" id="chkBroken" onchange="cmd({action:'setPlacement',broken:this.checked})"> Broken Bulbs</label>
                  <label class="chk"><input type="checkbox" id="chkBurned" onchange="cmd({action:'setPlacement',burnedOut:this.checked})"> Burned Out</label>
                </div>
              </div>
            </div>
          </div>

          <!-- TAB 2: SCENES & FX TIMELINES -->
          <div id="tabScenes" class="tabPane" style="display:none;">
            <div class="card">
              <h2>Holiday Scenes (16 Built-In + Custom)</h2>
              <div class="row" style="margin-bottom:8px;">
                <label class="chk"><input type="checkbox" id="chkSceneWP" checked> Apply Scene Desktop Wallpaper</label>
              </div>
              <div id="sceneGrid" class="grid"></div>
              <div class="row" style="margin-top:10px;">
                <input id="newSceneName" type="text" placeholder="Save current setup as new scene..." style="flex:1;margin:0;">
                <button onclick="saveSceneRemote()">Save Scene</button>
              </div>
            </div>

            <div class="grid2">
              <div class="card">
                <h2>Lighting Effect Timeline (.twinklefx)</h2>
                <label class="field">Active Timeline Show
                  <select id="selTimeline" onchange="cmd({action:'setActiveTimeline',timelineID:this.value})"></select>
                </label>
                <button class="sec" onclick="cmd({action:'setActiveTimeline',timelineID:''})">Stop Timeline Override</button>
              </div>

              <div class="card">
                <h2>Holiday Celebration Bursts</h2>
                <div class="row">
                  <button onclick="cmd({action:'triggerCelebration',celebration:'christmas'})">🎄 Christmas</button>
                  <button onclick="cmd({action:'triggerCelebration',celebration:'newYear'})">🎆 New Year</button>
                  <button onclick="cmd({action:'triggerCelebration',celebration:'halloween'})">🎃 Halloween</button>
                  <button onclick="cmd({action:'triggerCelebration',celebration:'birthday'})">🎂 Birthday</button>
                </div>
              </div>
            </div>
          </div>

          <!-- TAB 3: MUSIC & MIDI SHOW -->
          <div id="tabMusic" class="tabPane" style="display:none;">
            <div class="grid2">
              <div class="card">
                <h2>Holiday Jukebox (105+ Songs)</h2>
                <div class="row" style="margin-bottom:8px;">
                  <button class="sec" onclick="cmd({action:'musicPrev'})">⏮ Prev</button>
                  <button class="ok" onclick="cmd({action:'musicToggle'})">⏯ Play / Pause</button>
                  <button class="danger" onclick="cmd({action:'musicStop'})">⏹ Stop</button>
                  <button class="sec" onclick="cmd({action:'musicNext'})">⏭ Next</button>
                </div>
                <label class="field">Music Volume (<span id="lblVol">85%</span>)
                  <input id="volRange" type="range" min="0" max="100" value="85" oninput="lblVol.innerText=this.value+'%';cmd({action:'setMusicVolume',value:this.value/100})">
                </label>
                <div class="row">
                  <label class="field" style="flex:1;">Play Order
                    <select id="selPlayMode" onchange="cmd({action:'setMusicPlayMode',intValue:parseInt(this.value)})">
                      <option value="0">Sequential</option>
                      <option value="1">Shuffle</option>
                    </select>
                  </label>
                  <label class="field" style="flex:1;">Repeat Mode
                    <select id="selRepeatMode" onchange="cmd({action:'setMusicRepeatMode',intValue:parseInt(this.value)})">
                      <option value="0">Stop After Playlist</option>
                      <option value="1">Repeat All</option>
                      <option value="2">Repeat One</option>
                    </select>
                  </label>
                </div>
                <input id="trackSearch" type="text" placeholder="Search 105 carols & songs..." oninput="renderTracks()">
                <div id="trackList" class="listBox"></div>
              </div>

              <div class="card">
                <h2>MIDI Light Show Sync (7 Modes)</h2>
                <label class="chk"><input type="checkbox" id="chkMidiOn" onchange="cmd({action:'setMIDIReactive',enabled:this.checked})"> Enable MIDI-Reactive Lighting</label>
                <label class="field">Reactive Mode
                  <select id="selMidiMode" onchange="cmd({action:'setMIDIReactive',enabled:true,midiMode:parseInt(this.value)})"></select>
                </label>
                <label class="field">Sensitivity (<span id="lblSens">1.0x</span>)
                  <input id="sensRange" type="range" min="20" max="200" value="100" oninput="lblSens.innerText=(this.value/100).toFixed(2)+'x';cmd({action:'setMIDIReactive',sensitivity:this.value/100})">
                </label>
              </div>
            </div>
          </div>

          <!-- TAB 4: SCREENSAVERS, WALLPAPERS & SMART -->
          <div id="tabExtra" class="tabPane" style="display:none;">
            <div class="grid2">
              <div class="card">
                <h2>Screen Saver Control (25 Modules)</h2>
                <label class="field">Module
                  <select id="selSaver" onchange="cmd({action:'setScreenSaverConfig',moduleID:this.value})"></select>
                </label>
                <label class="field">Banner Text
                  <input id="txtSSMsg" type="text" placeholder="YOUR MESSAGE HERE">
                </label>
                <div class="row">
                  <button class="sec" onclick="cmd({action:'setScreenSaverConfig',text:txtSSMsg.value,scrollMessage:chkSSScroll.checked})">Update Text</button>
                  <button class="ok" onclick="cmd({action:'startScreenSaver',moduleID:selSaver.value})">▶ Start Saver</button>
                  <button class="danger" onclick="cmd({action:'stopScreenSaver'})">⏹ Stop Saver</button>
                </div>
                <label class="chk"><input type="checkbox" id="chkSSScroll" onchange="cmd({action:'setScreenSaverConfig',scrollMessage:this.checked})"> Scroll Banner Text</label>
              </div>

              <div class="card">
                <h2>Desktop Wallpaper (130 Designs)</h2>
                <label class="field">Wallpaper Style
                  <select id="selWpStyle" onchange="cmd({action:'setWallpaper',wallpaperStyle:parseInt(this.value)})">
                    <option value="0">Tile</option>
                    <option value="1">Center</option>
                    <option value="2">Stretch</option>
                    <option value="3">Fit</option>
                  </select>
                </label>
                <input id="wpSearch" type="text" placeholder="Search 130 wallpapers..." oninput="renderWallpapers()">
                <div id="wpList" class="listBox" style="max-height:175px;"></div>
              </div>
            </div>

            <div class="grid2">
              <div class="card">
                <h2>Seasonal Automation</h2>
                <label class="chk"><input type="checkbox" id="chkAutoOn" onchange="cmd({action:'setAutomation',enabled:this.checked})"> Enable Seasonal Schedule Automation</label>
                <label class="chk"><input type="checkbox" id="chkVac" onchange="cmd({action:'setAutomation',vacationMode:this.checked})"> Vacation Mode (Pause Lights)</label>
                <label class="chk"><input type="checkbox" id="chkQuiet" onchange="cmd({action:'setAutomation',quietHoursEnabled:this.checked})"> Quiet Hours Dimming &amp; Mute</label>
                <label class="chk"><input type="checkbox" id="chkNightOff" onchange="cmd({action:'setAutomation',autoShutdownEnabled:this.checked})"> Nightly Auto-Shutdown</label>
                <button class="sec" style="margin-top:6px;" onclick="cmd({action:'setAutomation',text:'clearOverride'})">Clear Manual Rule Override</button>
              </div>

              <div class="card">
                <h2>Interactive, Weather &amp; Safety</h2>
                <label class="chk"><input type="checkbox" id="chkInterOn" onchange="cmd({action:'setInteractive',enabled:this.checked})"> Interactive Mouse Glow &amp; Ripple</label>
                <label class="chk"><input type="checkbox" id="chkProx" onchange="cmd({action:'setInteractive',mouseProximityGlow:this.checked})"> Pointer Proximity Glow</label>
                <label class="chk"><input type="checkbox" id="chkRip" onchange="cmd({action:'setInteractive',mouseRipple:this.checked})"> Strand Ripple Waves</label>
                <label class="chk"><input type="checkbox" id="chkSpk" onchange="cmd({action:'setInteractive',sparkleTrail:this.checked})"> Pointer Sparkle Trail</label>
                <label class="chk"><input type="checkbox" id="chkTod" onchange="cmd({action:'setWeatherAtmosphere',timeOfDayEnabled:this.checked})"> Time-of-Day Brightness Curve</label>
                <label class="field">Weather Simulation
                  <select id="selWeather" onchange="cmd({action:'setWeatherAtmosphere',enabled:true,condition:this.value})">
                    <option value="none">Solar Auto / Normal</option>
                    <option value="snow">Snowfall</option>
                    <option value="rain">Rainy</option>
                    <option value="windy">Windy / Gusts</option>
                    <option value="clearNight">Clear Winter Night</option>
                    <option value="cloudy">Warm Indoor Overcast</option>
                  </select>
                </label>
                <button class="danger" style="margin-top:4px;" onclick="cmd({action:'stopScreenColorSync'})">Stop Ambient Screen Sync</button>
              </div>
            </div>
          </div>
        </div>

        <script>
        let token = sessionStorage.getItem('tk_rem_token') || '';
        let ws = null;
        let catalog = {bulbs:[], tracks:[], wallpapers:[], scenes:[], curTrack:0, activeBulb:'', activeWP:'', activeScene:''};

        function showTab(id, btn){
          document.querySelectorAll('.tabPane').forEach(p=>p.style.display='none');
          document.getElementById(id).style.display='block';
          document.querySelectorAll('.tabBtn').forEach(b=>b.classList.remove('sel'));
          if(btn) btn.classList.add('sel');
        }

        async function apiGet(path){
          const r = await fetch(path, {headers:{'Authorization':'Bearer '+token}});
          if(r.status===401){ logout(); throw new Error('401'); }
          return r.json();
        }

        async function pair(){
          const pin = document.getElementById('pinInput').value.trim();
          const ctrl = document.getElementById('tokInput').value.trim();
          const payload = ctrl ? {controlToken: ctrl} : {pin};
          const r = await fetch('/v1/remote/auth',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
          const j = await r.json();
          if(j.ok && j.sessionToken){
            token = j.sessionToken;
            sessionStorage.setItem('tk_rem_token', token);
            initUI();
          } else {
            document.getElementById('authMsg').innerText = j.error || 'Authentication failed';
          }
        }

        function logout(){
          sessionStorage.removeItem('tk_rem_token');
          token = '';
          if(ws){ try{ws.close();}catch(e){} ws = null; }
          document.getElementById('ctrlUI').style.display='none';
          document.getElementById('authCard').style.display='block';
          document.getElementById('connBadge').innerText='Locked';
        }

        async function cmd(payload){
          if(ws && ws.readyState === 1){
            try{ ws.send(JSON.stringify(payload)); setTimeout(refreshStatus, 80); return; }catch(e){}
          }
          const r = await fetch('/v1/remote/action',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},body:JSON.stringify(payload)});
          if(r.status===401){ logout(); return; }
          setTimeout(refreshStatus, 60);
        }

        async function saveSceneRemote(){
          const nm = document.getElementById('newSceneName').value.trim();
          if(!nm) return;
          await cmd({action:'saveCurrentAsScene', name: nm});
          document.getElementById('newSceneName').value = '';
          const sr = await apiGet('/v1/scenes');
          catalog.scenes = sr.scenes || [];
          renderScenes();
        }

        function renderScenes(){
          const g = document.getElementById('sceneGrid'); g.innerHTML='';
          catalog.scenes.forEach(sc=>{
            const b = document.createElement('button');
            b.className = (catalog.activeScene === sc.id) ? 'active' : 'sec';
            b.innerText = (sc.favorite?'★ ':'') + sc.name;
            b.onclick = ()=>cmd({action:'activateScene', sceneID: sc.id, applyWallpaper: document.getElementById('chkSceneWP').checked});
            g.appendChild(b);
          });
        }

        function renderBulbs(){
          const q = (document.getElementById('bulbSearch').value||'').toLowerCase();
          const box = document.getElementById('bulbList'); box.innerHTML='';
          catalog.bulbs.filter(b=>!q || b.title.toLowerCase().includes(q) || b.collection.toLowerCase().includes(q)).slice(0,120).forEach(b=>{
            const d = document.createElement('div');
            d.className = 'listItem' + (catalog.activeBulb===b.id ? ' cur' : '');
            d.innerHTML = '<span>'+b.title+'</span><small>'+b.collection+'</small>';
            d.onclick = ()=>cmd({action:'setBulbSet', bulbSetID:b.id});
            box.appendChild(d);
          });
        }

        function renderTracks(){
          const q = (document.getElementById('trackSearch').value||'').toLowerCase();
          const box = document.getElementById('trackList'); box.innerHTML='';
          catalog.tracks.filter(t=>!q || t.title.toLowerCase().includes(q)).forEach(t=>{
            const d = document.createElement('div');
            d.className = 'listItem' + (catalog.curTrack===t.index ? ' cur' : '');
            d.innerHTML = '<span>▶ '+t.title+'</span><small>'+Math.round(t.bpm)+' BPM</small>';
            d.onclick = ()=>cmd({action:'musicPlay', trackIndex:t.index});
            box.appendChild(d);
          });
        }

        function renderWallpapers(){
          const q = (document.getElementById('wpSearch').value||'').toLowerCase();
          const box = document.getElementById('wpList'); box.innerHTML='';
          catalog.wallpapers.filter(w=>!q || w.title.toLowerCase().includes(q) || w.category.toLowerCase().includes(q)).slice(0,130).forEach(w=>{
            const d = document.createElement('div');
            d.className = 'listItem' + (catalog.activeWP===w.id ? ' cur' : '');
            d.innerHTML = '<span>'+w.title+'</span><small>'+w.category+'</small>';
            d.onclick = ()=>cmd({action:'setWallpaper', wallpaperID:w.id});
            box.appendChild(d);
          });
        }

        function connectLiveStream(){
          if(ws) try{ws.close();}catch(e){}
          const proto = location.protocol==='https:' ? 'wss://' : 'ws://';
          ws = new WebSocket(proto + location.host + '/v1/stream?format=json&token=' + encodeURIComponent(token));
          const cv = document.getElementById('bulbCanvas');
          const ctx = cv.getContext('2d');
          ws.onopen = ()=>{ document.getElementById('connBadge').innerText='Live WS Synced'; };
          ws.onclose = ()=>{ document.getElementById('connBadge').innerText='Connected (HTTP)'; };
          ws.onmessage = (ev)=>{
            try{
              const pkt = JSON.parse(ev.data);
              if(Array.isArray(pkt.rgb)){
                ctx.fillStyle='#050a14'; ctx.fillRect(0,0,cv.width,cv.height);
                ctx.strokeStyle='#155e22'; ctx.lineWidth=2; ctx.beginPath(); ctx.moveTo(0,10); ctx.lineTo(cv.width,10); ctx.stroke();
                const n = pkt.rgb.length;
                const step = cv.width / Math.max(1, n);
                const rad = Math.min(12, Math.max(4, step*0.36));
                pkt.rgb.forEach((c, idx)=>{
                  const x = (idx + 0.5)*step, y = 27;
                  ctx.fillStyle = 'rgb('+c[0]+','+c[1]+','+c[2]+')';
                  ctx.beginPath(); ctx.arc(x, y, rad, 0, Math.PI*2); ctx.fill();
                });
              }
            }catch(e){}
          };
        }

        async function refreshStatus(){
          try{
            const st = await apiGet('/v1/status');
            document.getElementById('statusText').innerText =
              (st.lightsEnabled ? '💡 ON' : '⚫ OFF') + ' • ' + st.lightingCategoryName +
              ' • ' + st.bulbSet + ' • ♪ ' + (st.currentTrack || 'Stopped');
            btnCatClassic.className = st.lightingCategory===0 ? 'active' : 'sec';
            btnCatModern.className = st.lightingCategory===1 ? 'active' : 'sec';
            brRange.value = Math.round((st.brightness||1)*100); lblBr.innerText = brRange.value+'%';
            spRange.value = Math.round((st.speed||1)*100); lblSp.innerText = (spRange.value/100).toFixed(2)+'x';
            smRange.value = Math.round((st.smoothness||0.75)*100); lblSm.innerText = smRange.value+'%';
            selModernFx.value = st.effectID;
            selModernPal.value = st.paletteID;
            selClassicFlash.value = st.flashMode;
            selClassicColor.value = st.colorMode;
            selRate.value = st.rate;
            selBulbSize.value = st.bulbSize;
            selLoc.value = st.location;
            selDrawMode.value = st.drawMode;
            chkAllMon.checked = !!st.useAllMonitors; chkRev.checked = !!st.reverse; chkInw.checked = !!st.inward;
            chkBare.checked = !!st.bareWire; chkSparse.checked = !!st.notSoMany; chkCorners.checked = !!st.noCorners;
            chkBroken.checked = !!st.broken; chkBurned.checked = !!st.burnedOut;
            volRange.value = Math.round((st.musicVolume||0.85)*100); lblVol.innerText = volRange.value+'%';
            selPlayMode.value = st.musicPlayMode||0; selRepeatMode.value = st.musicRepeatMode||0;
            chkMidiOn.checked = !!st.midiReactiveEnabled; selMidiMode.value = st.midiReactiveMode||0;
            sensRange.value = Math.round((st.midiSensitivity||1)*100); lblSens.innerText = (sensRange.value/100).toFixed(2)+'x';
            selSaver.value = st.ssModule;
            if(document.activeElement !== txtSSMsg) txtSSMsg.value = st.ssMsg || '';
            chkSSScroll.checked = !!st.ssScrollMsg;
            selWpStyle.value = st.wallpaperStyle || 0;
            chkAutoOn.checked = !!st.automationEnabled; chkVac.checked = !!st.vacationMode;
            chkQuiet.checked = !!st.quietHoursEnabled; chkNightOff.checked = !!st.autoShutdownEnabled;
            chkInterOn.checked = !!st.interactiveEnabled; chkProx.checked = !!st.mouseProximityGlow;
            chkRip.checked = !!st.mouseRipple; chkSpk.checked = !!st.sparkleTrail; chkTod.checked = !!st.timeOfDayEnabled;
            selTimeline.value = st.activeTimelineID || '';

            const changedList = catalog.activeScene !== st.activeSceneID || catalog.activeBulb !== st.bulbSet || catalog.curTrack !== st.currentTrackIndex || catalog.activeWP !== st.activeWallpaperID;
            catalog.activeScene = st.activeSceneID;
            catalog.activeBulb = st.bulbSet;
            catalog.curTrack = st.currentTrackIndex;
            catalog.activeWP = st.activeWallpaperID;
            if(changedList){ renderScenes(); renderBulbs(); renderTracks(); renderWallpapers(); }
          }catch(e){}
        }

        async function initUI(){
          document.getElementById('authCard').style.display='none';
          document.getElementById('ctrlUI').style.display='block';
          document.getElementById('connBadge').innerText='Connected';

          const [fx, pal, bulbs, mus, savs, wps, tls, scs] = await Promise.all([
            apiGet('/v1/effects'), apiGet('/v1/palettes'), apiGet('/v1/bulbs'),
            apiGet('/v1/music'), apiGet('/v1/screensavers'), apiGet('/v1/wallpapers'),
            apiGet('/v1/timelines'), apiGet('/v1/scenes')
          ]);

          const fillSel = (el, items, vk, lk) => { el.innerHTML=''; items.forEach(it=>{ const o=document.createElement('option'); o.value=it[vk]; o.innerText=it[lk]; el.appendChild(o); }); };
          fillSel(selModernFx, fx.modern, 'id', 'name');
          fillSel(selClassicFlash, fx.classic, 'id', 'name');
          fillSel(selRate, fx.rates, 'id', 'name');
          fillSel(selMidiMode, fx.midiModes, 'id', 'name');
          fillSel(selModernPal, pal.modern, 'id', 'name');
          fillSel(selClassicColor, pal.classic, 'id', 'name');
          fillSel(selSaver, savs.screensavers, 'id', 'name');
          selTimeline.innerHTML = '<option value="">(None — Use Effect Mode)</option>';
          (tls.timelines||[]).forEach(t=>{ const o=document.createElement('option'); o.value=t.id; o.innerText=t.name; selTimeline.appendChild(o); });

          catalog.bulbs = bulbs.bulbs || [];
          catalog.tracks = mus.tracks || [];
          catalog.wallpapers = wps.wallpapers || [];
          catalog.scenes = scs.scenes || [];

          renderScenes(); renderBulbs(); renderTracks(); renderWallpapers();
          await refreshStatus();
          connectLiveStream();
          setInterval(refreshStatus, 2500);
        }

        if(token){ initUI().catch(()=>{}); }
        </script>
        </body>
        </html>
        """#
    }
}
