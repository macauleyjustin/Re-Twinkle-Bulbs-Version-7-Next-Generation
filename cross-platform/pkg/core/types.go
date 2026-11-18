package core

import (
	"fmt"
	"math"
	"math/rand"
	"sync"
	"time"
)

type RGBA struct {
	R, G, B, A uint8
}

type FlashMode int

const (
	FlashNone FlashMode = iota
	FlashRandom
	FlashAllTogether
	FlashChase
	FlashAlternating
	FlashSomeFlash
	FlashSingle
	FlashPairs
	FlashPingPong
)

var FlashModeNames = []string{
	"None (Always On)",
	"Random",
	"All Together",
	"Chase",
	"Alternating",
	"Some Bulbs Flash",
	"Single",
	"Pairs",
	"Ping-Pong",
}

type FlashRate int

const (
	RateSlow FlashRate = iota
	RateSlowMed
	RateMedium
	RateMedFast
	RateFast
	RateVeryFast
)

var FlashRateNames = []string{
	"Slow (1200ms)",
	"Slow/Med (800ms)",
	"Medium (500ms)",
	"Med/Fast (350ms)",
	"Fast (200ms)",
	"Very Fast (80ms)",
}

var FlashRateIntervalsMS = [6]int{1200, 800, 500, 350, 200, 80}

type PlacementMode int

const (
	PlaceTop PlacementMode = iota
	PlaceTopBottom
	PlaceAround
	PlaceSides
	PlaceTopSides
	PlaceBottom
)

var PlacementNames = []string{
	"Top",
	"Top & Bottom",
	"Around Screen",
	"Sides Only",
	"Top & Sides",
	"Bottom Only",
}

type ModernEffect int

const (
	EffectGentleTwinkle ModernEffect = iota
	EffectTwinklefox
	EffectSlowGlow
	EffectColorWave
	EffectRainbowChase
	EffectMeteor
	EffectCandleFlicker
	EffectFireworks
	EffectGlitter
	EffectRipple
	EffectCandyCane
	EffectHeartbeat
	EffectScanner
	EffectSoftRandomFade
	EffectAutoCycle
)

var ModernEffectNames = []string{
	"Gentle Twinkle",
	"Twinklefox",
	"Slow Glow",
	"Color Wave",
	"Rainbow Chase",
	"Meteor",
	"Candle Flicker",
	"Fireworks",
	"Glitter",
	"Ripple",
	"Candy Cane",
	"Heartbeat",
	"Scanner",
	"Soft Random Fade",
	"Auto-Cycle",
}

type ModernPalette int

const (
	PalClassicChristmas ModernPalette = iota
	PalWarmWhite
	PalIceBlueWhite
	PalHalloween
	PalPatriotic
	PalValentines
	PalAutumnHarvest
	PalStPatricks
	PalRainbow
)

var ModernPaletteNames = []string{
	"Classic Christmas",
	"Warm White",
	"Ice Blue & White",
	"Halloween Spooky",
	"Patriotic Red/White/Blue",
	"Valentine's Rose",
	"Autumn Harvest",
	"St. Patrick's Emerald",
	"Full Rainbow",
}

// Classic 8 color indices: 0 Purple, 1 Blue, 2 Red, 3 Green, 4 Yellow, 5 LightBlue, 6 White, 7 Gold/Orange
var ClassicBasePalette = [8]RGBA{
	{168, 52, 235, 255}, // 0 Purple
	{42, 118, 255, 255}, // 1 Blue
	{244, 42, 42, 255},  // 2 Red
	{44, 214, 72, 255},  // 3 Green
	{255, 224, 38, 255}, // 4 Yellow
	{84, 210, 255, 255}, // 5 Light Blue
	{255, 252, 244, 255},// 6 White
	{255, 168, 44, 255}, // 7 Amber
}

var ColorModeNames = []string{
	"Random",
	"Purple",
	"Blue",
	"Red",
	"Green",
	"Yellow",
	"Light Blue",
	"White",
	"Red/Green",
	"Multi-Color",
	"Blues",
	"All Colors + White",
	"Red/Blue",
	"Purple/Green",
	"Red/Yellow/Green",
	"Red/Green/Blue",
	"Cool Colors",
	"Yellow/White",
	"Red/Yellow",
	"R/G/Y/B",
	"Red/White/Blue",
}

var ClassicColorSequences = [21][]int{
	{2, 3, 4, 1, 0, 5},       // 0 Random (handled specially with zero repeats)
	{0},                      // 1 Purple
	{1},                      // 2 Blue
	{2},                      // 3 Red
	{3},                      // 4 Green
	{4},                      // 5 Yellow
	{5},                      // 6 Light Blue
	{6},                      // 7 White
	{3, 2},                   // 8 Red/Green
	{2, 3, 4, 1, 0},          // 9 Multi-Color
	{1, 5, 6},                // 10 Blues
	{2, 3, 4, 1, 0, 5, 6},    // 11 All Colors + White
	{2, 1},                   // 12 Red/Blue
	{0, 3},                   // 13 Purple/Green
	{2, 4, 3},                // 14 Red/Yellow/Green
	{2, 3, 1},                // 15 Red/Green/Blue
	{1, 5, 0, 6},             // 16 Cool Colors
	{4, 6},                   // 17 Yellow/White
	{2, 4},                   // 18 Red/Yellow
	{2, 3, 4, 1},             // 19 R/G/Y/B
	{2, 6, 1},                // 20 Red/White/Blue
}

type BulbSetInfo struct {
	ID         int    `json:"id"`
	Name       string `json:"name"`
	Collection string `json:"collection"`
	ShapeKind  int    `json:"shapeKind"`
}

func BuildBulbSetCatalog() []BulbSetInfo {
	classicNames := []string{
		"Outdoor", "Normal", "Large", "Bare Bulbs", "Peppers",
		"Candy Canes", "Candles", "Stars", "Holly", "Icicles",
		"Minibulbs", "Trees", "Presents", "Stockings", "Flowers",
	}
	out := make([]BulbSetInfo, 0, 265)
	for i, n := range classicNames {
		out = append(out, BulbSetInfo{ID: i, Name: n, Collection: "Classic Original (15)", ShapeKind: i})
	}
	collections := []string{
		"Traditional Christmas", "Victorian Parlor", "Winter Frost", "North Pole Workshop", "Candy Land",
		"Candles & Lanterns", "Celestial Stars", "Woodland Forest", "Snowman Friends", "Reindeer Games",
		"Santa's Sleigh", "Gingerbread Village", "Hanukkah Lights", "New Year's Eve", "Valentine Hearts",
		"St. Patrick's Shamrocks", "Easter & Spring", "Summer Patriot", "Halloween Haunt", "Autumn Harvest",
		"Neon Retro", "Crystal Prism", "Nordic Hygge", "Cyber Glow", "Golden Elegance",
	}
	id := 15
	for cIdx, col := range collections {
		for k := 1; k <= 10; k++ {
			out = append(out, BulbSetInfo{
				ID:         id,
				Name:       fmt.Sprintf("%s #%d", col, k),
				Collection: col,
				ShapeKind:  (cIdx*3 + k) % 15,
			})
			id++
		}
	}
	return out
}

type HolidayScene struct {
	ID             string        `json:"id"`
	Name           string        `json:"name"`
	Category       string        `json:"category"`
	Description    string        `json:"description"`
	ClassicMode    bool          `json:"classicMode"`
	BulbSetID      int           `json:"bulbSetId"`
	BulbSize       int           `json:"bulbSize"`
	FlashMode      FlashMode     `json:"flashMode"`
	FlashRate      FlashRate     `json:"flashRate"`
	ColorMode      int           `json:"colorMode"`
	Placement      PlacementMode `json:"placement"`
	ModernEffect   ModernEffect  `json:"modernEffect"`
	ModernPalette  ModernPalette `json:"modernPalette"`
	Speed          float64       `json:"speed"`
	Brightness     float64       `json:"brightness"`
	MusicTrack     int           `json:"musicTrack"`
	ScreenSaver    string        `json:"screenSaver"`
	BuiltIn        bool          `json:"builtIn"`
}

func BuiltInHolidayScenes() []HolidayScene {
	return []HolidayScene{
		{ID: "classic-christmas", Name: "Classic Christmas", Category: "Christmas", Description: "Authentic v6.0 Outdoor bulbs with Red/Green Chase and Jingle Bells.", ClassicMode: true, BulbSetID: 0, BulbSize: 32, FlashMode: FlashChase, FlashRate: RateMedium, ColorMode: 8, Placement: PlaceAround, Brightness: 1.0, Speed: 1.0, MusicTrack: 0, ScreenSaver: "Snowfall", BuiltIn: true},
		{ID: "victorian-christmas", Name: "Victorian Christmas", Category: "Christmas", Description: "Warm candlelight flicker and amber parlor bulbs.", ClassicMode: false, BulbSetID: 6, BulbSize: 48, ModernEffect: EffectCandleFlicker, ModernPalette: PalWarmWhite, Placement: PlaceTop, Brightness: 0.9, Speed: 0.85, MusicTrack: 1, ScreenSaver: "Fireplace", BuiltIn: true},
		{ID: "winter-wonderland", Name: "Winter Wonderland", Category: "Winter", Description: "Crisp ice-blue and silver shimmer with gentle snowfall.", ClassicMode: false, BulbSetID: 9, BulbSize: 32, ModernEffect: EffectGentleTwinkle, ModernPalette: PalIceBlueWhite, Placement: PlaceAround, Brightness: 0.95, Speed: 1.0, MusicTrack: 6, ScreenSaver: "Ice Crystals", BuiltIn: true},
		{ID: "christmas-fireplace", Name: "Christmas Fireplace", Category: "Christmas", Description: "Cozy hearth embers with warm glow and carols.", ClassicMode: false, BulbSetID: 12, BulbSize: 48, ModernEffect: EffectSlowGlow, ModernPalette: PalWarmWhite, Placement: PlaceBottom, Brightness: 0.88, Speed: 0.8, MusicTrack: 1, ScreenSaver: "Hearth Embers", BuiltIn: true},
		{ID: "snowy-village", Name: "Snowy Village", Category: "Winter", Description: "Twinklefox cottage lights circling your monitor.", ClassicMode: false, BulbSetID: 11, BulbSize: 32, ModernEffect: EffectTwinklefox, ModernPalette: PalClassicChristmas, Placement: PlaceAround, Brightness: 0.92, Speed: 1.0, MusicTrack: 2, ScreenSaver: "Winter Village", BuiltIn: true},
		{ID: "new-years-celebration", Name: "New Year's Celebration", Category: "Celebration", Description: "Sparkling midnight glitter and fireworks bursts.", ClassicMode: false, BulbSetID: 7, BulbSize: 48, ModernEffect: EffectFireworks, ModernPalette: PalRainbow, Placement: PlaceAround, Brightness: 1.0, Speed: 1.35, MusicTrack: 3, ScreenSaver: "Fireworks", BuiltIn: true},
		{ID: "valentines-romance", Name: "Valentine's Romance", Category: "Romance", Description: "Soft rose and ruby heartbeat pulses.", ClassicMode: false, BulbSetID: 1, BulbSize: 32, ModernEffect: EffectHeartbeat, ModernPalette: PalValentines, Placement: PlaceAround, Brightness: 0.88, Speed: 0.9, MusicTrack: 4, ScreenSaver: "Floating Hearts", BuiltIn: true},
		{ID: "st-patricks-day", Name: "St. Patrick's Day", Category: "Spring", Description: "Emerald and gold wave across the desktop frame.", ClassicMode: false, BulbSetID: 14, BulbSize: 32, ModernEffect: EffectColorWave, ModernPalette: PalStPatricks, Placement: PlaceTop, Brightness: 0.95, Speed: 1.1, MusicTrack: 2, ScreenSaver: "Emerald Clover", BuiltIn: true},
		{ID: "easter-garden", Name: "Easter Garden", Category: "Spring", Description: "Pastel spring blooms in gentle ripple motion.", ClassicMode: false, BulbSetID: 14, BulbSize: 32, ModernEffect: EffectRipple, ModernPalette: PalRainbow, Placement: PlaceTopBottom, Brightness: 0.9, Speed: 0.95, MusicTrack: 5, ScreenSaver: "Spring Meadow", BuiltIn: true},
		{ID: "spring-awakening", Name: "Spring Awakening", Category: "Spring", Description: "Soft random fade through blooming blossom tones.", ClassicMode: false, BulbSetID: 14, BulbSize: 32, ModernEffect: EffectSoftRandomFade, ModernPalette: PalStPatricks, Placement: PlaceTop, Brightness: 0.85, Speed: 0.85, MusicTrack: 5, ScreenSaver: "Sunbeams", BuiltIn: true},
		{ID: "summer-nights", Name: "Summer Nights", Category: "Summer", Description: "Firefly glitter lights along the upper horizon.", ClassicMode: false, BulbSetID: 10, BulbSize: 32, ModernEffect: EffectGlitter, ModernPalette: PalIceBlueWhite, Placement: PlaceTop, Brightness: 0.85, Speed: 0.9, MusicTrack: 4, ScreenSaver: "Fireflies", BuiltIn: true},
		{ID: "fourth-of-july", Name: "Fourth of July", Category: "Patriotic", Description: "Classic Red/White/Blue fireworks & patriotic chase.", ClassicMode: false, BulbSetID: 7, BulbSize: 48, ModernEffect: EffectFireworks, ModernPalette: PalPatriotic, Placement: PlaceAround, Brightness: 1.0, Speed: 1.4, MusicTrack: 5, ScreenSaver: "Fireworks", BuiltIn: true},
		{ID: "autumn-harvest", Name: "Autumn Harvest", Category: "Autumn", Description: "Warm amber, pumpkin, and leaf tones in a cozy wave.", ClassicMode: false, BulbSetID: 4, BulbSize: 32, ModernEffect: EffectColorWave, ModernPalette: PalAutumnHarvest, Placement: PlaceAround, Brightness: 0.9, Speed: 0.85, MusicTrack: 7, ScreenSaver: "Falling Leaves", BuiltIn: true},
		{ID: "haunted-halloween", Name: "Haunted Halloween", Category: "Halloween", Description: "Eerie purple & pumpkin meteors for October nights.", ClassicMode: false, BulbSetID: 3, BulbSize: 48, ModernEffect: EffectMeteor, ModernPalette: PalHalloween, Placement: PlaceAround, Brightness: 0.95, Speed: 1.25, MusicTrack: 6, ScreenSaver: "Midnight Moon", BuiltIn: true},
		{ID: "thanksgiving", Name: "Thanksgiving", Category: "Autumn", Description: "Steady warm candle glow for autumn gratitude.", ClassicMode: false, BulbSetID: 6, BulbSize: 32, ModernEffect: EffectCandleFlicker, ModernPalette: PalAutumnHarvest, Placement: PlaceTopBottom, Brightness: 0.85, Speed: 0.75, MusicTrack: 7, ScreenSaver: "Harvest Hearth", BuiltIn: true},
		{ID: "peaceful-winter-evening", Name: "Peaceful Winter Evening", Category: "Winter", Description: "Quiet softly breathing warm lights before bedtime.", ClassicMode: false, BulbSetID: 10, BulbSize: 32, ModernEffect: EffectSlowGlow, ModernPalette: PalWarmWhite, Placement: PlaceTop, Brightness: 0.75, Speed: 0.65, MusicTrack: 1, ScreenSaver: "Silent Night Stars", BuiltIn: true},
	}
}

type AutomationConfig struct {
	Enabled      bool    `json:"enabled"`
	VacationMode bool    `json:"vacationMode"`
	QuietStart   int     `json:"quietStartHour"` // 0-23
	QuietEnd     int     `json:"quietEndHour"`   // 0-23
	QuietEnabled bool    `json:"quietEnabled"`
	Latitude     float64 `json:"latitude"`
	Longitude    float64 `json:"longitude"`
	SolarSunset  bool    `json:"solarSunset"`
}

type Settings struct {
	ClassicMode    bool             `json:"classicMode"`
	Enabled        bool             `json:"enabled"`
	Blackout       bool             `json:"blackout"`
	BulbSetID      int              `json:"bulbSetId"`
	BulbSize       int              `json:"bulbSize"` // 32 or 48
	FlashMode      FlashMode        `json:"flashMode"`
	FlashRate      FlashRate        `json:"flashRate"`
	ColorMode      int              `json:"colorMode"`
	Placement      PlacementMode    `json:"placement"`
	AlwaysOnTop    bool             `json:"alwaysOnTop"`
	BareWire       bool             `json:"bareWire"`
	NoCorners      bool             `json:"noCorners"`
	SparseSpacing  bool             `json:"sparseSpacing"`
	ModernEffect   ModernEffect     `json:"modernEffect"`
	ModernPalette  ModernPalette    `json:"modernPalette"`
	Speed          float64          `json:"speed"`
	Brightness     float64          `json:"brightness"`
	MusicPlaying   bool             `json:"musicPlaying"`
	MusicTrack     int              `json:"musicTrack"`
	MusicVolume    float64          `json:"musicVolume"`
	ActiveSceneID  string           `json:"activeSceneId"`
	Automation     AutomationConfig `json:"automation"`
	APIEnabled     bool             `json:"apiEnabled"`
	APIPort        int              `json:"apiPort"`
	AllowRemoteCmd bool             `json:"allowRemoteCommands"`
	PairingPIN     string           `json:"pairingPin"`
}

func DefaultSettings() Settings {
	return Settings{
		ClassicMode:    true,
		Enabled:        true,
		Blackout:       false,
		BulbSetID:      0, // Outdoor
		BulbSize:       32,
		FlashMode:      FlashChase,
		FlashRate:      RateMedium,
		ColorMode:      8, // Red/Green (authentic classic default!)
		Placement:      PlaceTop,
		AlwaysOnTop:    true,
		BareWire:       true,
		NoCorners:      true,
		SparseSpacing:  true,
		ModernEffect:   EffectGentleTwinkle,
		ModernPalette:  PalClassicChristmas,
		Speed:          1.0,
		Brightness:     1.0,
		MusicPlaying:   false,
		MusicTrack:     0,
		MusicVolume:    0.75,
		ActiveSceneID:  "classic-christmas",
		Automation:     AutomationConfig{Enabled: false, QuietStart: 23, QuietEnd: 7, Latitude: 40.71, Longitude: -74.0},
		APIEnabled:     true,
		APIPort:        19697,
		AllowRemoteCmd: true,
		PairingPIN:     "122570",
	}
}

type BulbCoord struct {
	Index      int     `json:"index"`
	X          int     `json:"x"`
	Y          int     `json:"y"`
	Edge       int     `json:"edge"` // 0=top, 1=right, 2=bottom, 3=left
	RotDegrees int     `json:"rot"`  // 0, +90, 180, -90
	BareSpacer bool    `json:"bareSpacer"`
	On         bool    `json:"on"`
	Intensity  float64 `json:"intensity"`
	Color      RGBA    `json:"color"`
}

// ComputeLayout computes exact perimeter coordinates matching Re: Twinkle Bulbs v6/v7 rules.
func ComputeLayout(screenW, screenH int, cfg Settings) []BulbCoord {
	size := cfg.BulbSize
	if size != 48 {
		size = 32
	}
	step := size
	if cfg.SparseSpacing {
		step = int(float64(size) * 1.45)
	}
	if screenW < size*2 {
		screenW = size * 2
	}
	if screenH < size*2 {
		screenH = size * 2
	}

	coords := make([]BulbCoord, 0, 256)
	idx := 0

	addEdge := func(edge int) {
		switch edge {
		case 0: // Top
			startX, endX := 0, screenW-size
			if cfg.NoCorners {
				startX += size
				endX -= size
			}
			for x := startX; x <= endX; x += step {
				bare := cfg.BareWire && (idx%4 == 3)
				coords = append(coords, BulbCoord{Index: idx, X: x, Y: 0, Edge: 0, RotDegrees: 0, BareSpacer: bare})
				idx++
			}
		case 1: // Right
			startY, endY := 0, screenH-size
			if cfg.NoCorners {
				startY += size
				endY -= size
			}
			for y := startY; y <= endY; y += step {
				bare := cfg.BareWire && (idx%4 == 3)
				coords = append(coords, BulbCoord{Index: idx, X: screenW - size, Y: y, Edge: 1, RotDegrees: 90, BareSpacer: bare})
				idx++
			}
		case 2: // Bottom
			startX, endX := screenW-size, 0
			if cfg.NoCorners {
				startX -= size
				endX += size
			}
			for x := startX; x >= endX; x -= step {
				bare := cfg.BareWire && (idx%4 == 3)
				coords = append(coords, BulbCoord{Index: idx, X: x, Y: screenH - size, Edge: 2, RotDegrees: 180, BareSpacer: bare})
				idx++
			}
		case 3: // Left
			startY, endY := screenH-size, 0
			if cfg.NoCorners {
				startY -= size
				endY += size
			}
			for y := startY; y >= endY; y -= step {
				bare := cfg.BareWire && (idx%4 == 3)
				coords = append(coords, BulbCoord{Index: idx, X: 0, Y: y, Edge: 3, RotDegrees: -90, BareSpacer: bare})
				idx++
			}
		}
	}

	switch cfg.Placement {
	case PlaceTop:
		addEdge(0)
	case PlaceTopBottom:
		addEdge(0)
		addEdge(2)
	case PlaceAround:
		addEdge(0)
		addEdge(1)
		addEdge(2)
		addEdge(3)
	case PlaceSides:
		addEdge(1)
		addEdge(3)
	case PlaceTopSides:
		addEdge(0)
		addEdge(1)
		addEdge(3)
	case PlaceBottom:
		addEdge(2)
	}
	return coords
}

// Engine manages real-time Classic (50ms) and Modern (60fps) animation frames plus Scenes.
type Engine struct {
	mu              sync.RWMutex
	cfg             Settings
	prevCfg         Settings
	bulbs           []BulbCoord
	screenW         int
	screenH         int
	rng             *rand.Rand
	tickCount       int64
	lastStepMS      int64
	stepIndex       int
	pingPongDir     int
	randNextToggle  []int64
	scenes          []HolidayScene
	catalog         []BulbSetInfo
	onChange        func(Settings)
}

func NewEngine(screenW, screenH int) *Engine {
	e := &Engine{
		cfg:         DefaultSettings(),
		prevCfg:     DefaultSettings(),
		screenW:     screenW,
		screenH:     screenH,
		rng:         rand.New(rand.NewSource(time.Now().UnixNano())),
		pingPongDir: 1,
		scenes:      BuiltInHolidayScenes(),
		catalog:     BuildBulbSetCatalog(),
	}
	e.rebuildLayoutLocked()
	return e
}

func (e *Engine) OnConfigChange(fn func(Settings)) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.onChange = fn
}

func (e *Engine) Config() Settings {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.cfg
}

func (e *Engine) Scenes() []HolidayScene {
	e.mu.RLock()
	defer e.mu.RUnlock()
	out := make([]HolidayScene, len(e.scenes))
	copy(out, e.scenes)
	return out
}

func (e *Engine) Catalog() []BulbSetInfo {
	return e.catalog
}

func (e *Engine) Resize(w, h int) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if w > 100 && h > 100 && (w != e.screenW || h != e.screenH) {
		e.screenW = w
		e.screenH = h
		e.rebuildLayoutLocked()
	}
}

func (e *Engine) UpdateSettings(fn func(*Settings)) {
	e.mu.Lock()
	old := e.cfg
	fn(&e.cfg)
	relayout := old.BulbSize != e.cfg.BulbSize || old.Placement != e.cfg.Placement ||
		old.NoCorners != e.cfg.NoCorners || old.SparseSpacing != e.cfg.SparseSpacing ||
		old.BareWire != e.cfg.BareWire || old.ColorMode != e.cfg.ColorMode
	if relayout {
		e.rebuildLayoutLocked()
	}
	cb := e.onChange
	cfgCopy := e.cfg
	e.mu.Unlock()
	if cb != nil {
		cb(cfgCopy)
	}
}

func (e *Engine) ActivateScene(id string) bool {
	e.mu.Lock()
	var found *HolidayScene
	for i := range e.scenes {
		if e.scenes[i].ID == id {
			found = &e.scenes[i]
			break
		}
	}
	if found == nil {
		e.mu.Unlock()
		return false
	}
	e.prevCfg = e.cfg
	e.cfg.ActiveSceneID = found.ID
	e.cfg.ClassicMode = found.ClassicMode
	e.cfg.BulbSetID = found.BulbSetID
	e.cfg.BulbSize = found.BulbSize
	e.cfg.FlashMode = found.FlashMode
	e.cfg.FlashRate = found.FlashRate
	e.cfg.ColorMode = found.ColorMode
	e.cfg.Placement = found.Placement
	e.cfg.ModernEffect = found.ModernEffect
	e.cfg.ModernPalette = found.ModernPalette
	e.cfg.Speed = found.Speed
	e.cfg.Brightness = found.Brightness
	e.cfg.MusicTrack = found.MusicTrack
	e.cfg.Blackout = false
	e.cfg.Enabled = true
	e.rebuildLayoutLocked()
	cb := e.onChange
	cfgCopy := e.cfg
	e.mu.Unlock()
	if cb != nil {
		cb(cfgCopy)
	}
	return true
}

func (e *Engine) RestorePrevious() {
	e.mu.Lock()
	e.cfg = e.prevCfg
	e.rebuildLayoutLocked()
	cb := e.onChange
	cfgCopy := e.cfg
	e.mu.Unlock()
	if cb != nil {
		cb(cfgCopy)
	}
}

func (e *Engine) ReturnToClassic() {
	e.UpdateSettings(func(s *Settings) {
		def := DefaultSettings()
		s.ClassicMode = true
		s.Enabled = true
		s.Blackout = false
		s.BulbSetID = def.BulbSetID
		s.BulbSize = def.BulbSize
		s.FlashMode = def.FlashMode
		s.FlashRate = def.FlashRate
		s.ColorMode = def.ColorMode
		s.Placement = def.Placement
		s.Brightness = 1.0
		s.Speed = 1.0
		s.ActiveSceneID = "classic-christmas"
	})
}

func (e *Engine) rebuildLayoutLocked() {
	e.bulbs = ComputeLayout(e.screenW, e.screenH, e.cfg)
	e.randNextToggle = make([]int64, len(e.bulbs))
	prevColor := -1
	seq := ClassicColorSequences[0]
	if e.cfg.ColorMode >= 0 && e.cfg.ColorMode < len(ClassicColorSequences) {
		seq = ClassicColorSequences[e.cfg.ColorMode]
	}
	for i := range e.bulbs {
		var cidx int
		if e.cfg.ColorMode == 0 { // Random without consecutive repeat
			cidx = e.rng.Intn(7)
			if cidx == prevColor {
				cidx = (cidx + 1 + e.rng.Intn(6)) % 7
			}
			prevColor = cidx
		} else {
			cidx = seq[i%len(seq)]
		}
		e.bulbs[i].Color = ClassicBasePalette[cidx]
		e.bulbs[i].On = true
		e.bulbs[i].Intensity = 1.0
		e.randNextToggle[i] = int64(e.rng.Intn(1200))
	}
	e.stepIndex = 0
}

func ChaseStrideForCount(n int) int {
	switch {
	case n <= 20:
		return 4
	case n <= 25:
		return 5
	case n <= 32:
		return 8
	case n <= 36:
		return 6
	case n <= 40:
		return 8
	case n <= 50:
		return 10
	default:
		return 2
	}
}

// Step advances simulation by dtMS milliseconds and returns a snapshot of bulb states.
func (e *Engine) Step(dtMS int64, now time.Time) []BulbCoord {
	e.mu.Lock()
	defer e.mu.Unlock()

	e.tickCount += dtMS
	n := len(e.bulbs)
	if n == 0 {
		return nil
	}

	// Safe Blackout or Automation Vacation/Quiet check
	blackout := e.cfg.Blackout || !e.cfg.Enabled || e.cfg.Automation.VacationMode
	brightMul := e.cfg.Brightness
	if e.cfg.Automation.Enabled && e.cfg.Automation.QuietEnabled {
		h := now.Hour()
		inQuiet := false
		if e.cfg.Automation.QuietStart > e.cfg.Automation.QuietEnd {
			inQuiet = h >= e.cfg.Automation.QuietStart || h < e.cfg.Automation.QuietEnd
		} else {
			inQuiet = h >= e.cfg.Automation.QuietStart && h < e.cfg.Automation.QuietEnd
		}
		if inQuiet {
			brightMul *= 0.25
		}
	}

	if blackout {
		out := make([]BulbCoord, n)
		copy(out, e.bulbs)
		for i := range out {
			out[i].On = false
			out[i].Intensity = 0
		}
		return out
	}

	if e.cfg.ClassicMode {
		rateIdx := int(e.cfg.FlashRate)
		if rateIdx < 0 || rateIdx >= len(FlashRateIntervalsMS) {
			rateIdx = int(RateMedium)
		}
		interval := int64(FlashRateIntervalsMS[rateIdx])
		advanceStep := false
		if e.tickCount-e.lastStepMS >= interval {
			e.lastStepMS = e.tickCount
			advanceStep = true
			if e.cfg.FlashMode == FlashPingPong {
				e.stepIndex += e.pingPongDir
				if e.stepIndex >= n-1 {
					e.stepIndex = n - 1
					e.pingPongDir = -1
				} else if e.stepIndex <= 0 {
					e.stepIndex = 0
					e.pingPongDir = 1
				}
			} else {
				e.stepIndex++
			}
		}

		stride := ChaseStrideForCount(n)
		for i := range e.bulbs {
			if e.bulbs[i].BareSpacer {
				e.bulbs[i].On = false
				e.bulbs[i].Intensity = 0
				continue
			}
			on := true
			switch e.cfg.FlashMode {
			case FlashNone:
				on = true
			case FlashRandom:
				if e.tickCount >= e.randNextToggle[i] {
					e.bulbs[i].On = !e.bulbs[i].On
					span := interval*2 + 200
					e.randNextToggle[i] = e.tickCount + interval/2 + int64(e.rng.Int63n(span))
				}
				on = e.bulbs[i].On
			case FlashAllTogether:
				on = (e.stepIndex % 2) == 0
			case FlashChase:
				on = ((i - (e.stepIndex % stride) + stride*4) % stride) == 0
			case FlashAlternating:
				on = (i % 2) == (e.stepIndex % 2)
			case FlashSomeFlash:
				if i%3 == 0 {
					on = (e.stepIndex % 2) == 0
				} else {
					on = true
				}
			case FlashSingle:
				target := n - 1 - (e.stepIndex % n)
				on = (i == target)
			case FlashPairs:
				if advanceStep || true {
					pairIdx := (e.stepIndex % ((n + 1) / 2)) * 2
					on = (i == pairIdx || i == pairIdx+1)
				}
			case FlashPingPong:
				on = (i == e.stepIndex)
			}
			e.bulbs[i].On = on
			if on {
				e.bulbs[i].Intensity = brightMul
			} else {
				e.bulbs[i].Intensity = 0.25 * brightMul
			}
		}
	} else {
		// Modern 60fps Engine
		tSec := float64(e.tickCount) / 1000.0 * math.Max(0.25, e.cfg.Speed)
		eff := e.cfg.ModernEffect
		if eff == EffectAutoCycle {
			eff = ModernEffect(int(tSec/8.0) % int(EffectAutoCycle))
		}
		palColors := modernPaletteColors(e.cfg.ModernPalette)
		for i := range e.bulbs {
			if e.bulbs[i].BareSpacer {
				e.bulbs[i].On = false
				e.bulbs[i].Intensity = 0
				continue
			}
			frac := float64(i) / float64(n)
			var val float64
			col := palColors[i%len(palColors)]

			switch eff {
			case EffectGentleTwinkle, EffectTwinklefox:
				phase := tSec*2.4 + float64((i*73)%37)*0.41
				val = 0.35 + 0.65*(0.5+0.5*math.Sin(phase))
			case EffectSlowGlow:
				val = 0.25 + 0.75*(0.5+0.5*math.Sin(tSec*1.3+frac*1.2))
			case EffectColorWave:
				val = 0.45 + 0.55*(0.5+0.5*math.Sin(tSec*3.2-frac*12.0))
			case EffectRainbowChase:
				hue := math.Mod(frac*2.0+tSec*0.35, 1.0)
				col = hsvToRGBA(hue, 0.92, 1.0)
				val = 0.95
			case EffectMeteor:
				head := math.Mod(tSec*0.45, 1.0)
				d := math.Mod(head-frac+1.0, 1.0)
				if d < 0.22 {
					val = math.Pow(1.0-d/0.22, 2.2)
				} else {
					val = 0.12
				}
			case EffectCandleFlicker:
				n1 := math.Sin(tSec*17.0 + float64(i)*3.1)
				n2 := math.Sin(tSec*31.0 + float64(i)*7.7)
				val = 0.65 + 0.20*n1 + 0.15*n2
			case EffectFireworks, EffectGlitter:
				spark := math.Sin(tSec*9.0 + float64(i*i%97))
				if spark > 0.88 {
					val = 1.0
					col = RGBA{255, 255, 255, 255}
				} else {
					val = 0.18 + 0.3*(0.5+0.5*math.Sin(tSec+frac*6.0))
				}
			case EffectRipple:
				dist := math.Abs(frac - 0.5)
				val = 0.25 + 0.75*(0.5+0.5*math.Cos(dist*24.0-tSec*5.0))
			case EffectCandyCane:
				shift := int(tSec * 4.0)
				if ((i + shift) / 2 % 2) == 0 {
					col = RGBA{244, 38, 38, 255}
				} else {
					col = RGBA{252, 252, 252, 255}
				}
				val = 0.95
			case EffectHeartbeat:
				beat := math.Mod(tSec*1.2, 1.0)
				if beat < 0.12 || (beat > 0.22 && beat < 0.34) {
					val = 1.0
				} else {
					val = 0.18
				}
			case EffectScanner:
				pos := 0.5 + 0.5*math.Sin(tSec*2.5)
				d := math.Abs(frac - pos)
				val = math.Max(0.12, 1.0-d*8.0)
			default: // Soft Random Fade
				val = 0.3 + 0.7*(0.5+0.5*math.Sin(tSec*1.8+float64((i*53)%29)))
			}
			if val < 0 {
				val = 0
			} else if val > 1 {
				val = 1
			}
			e.bulbs[i].Color = col
			e.bulbs[i].On = val > 0.45
			e.bulbs[i].Intensity = val * brightMul
		}
	}

	out := make([]BulbCoord, n)
	copy(out, e.bulbs)
	return out
}

func modernPaletteColors(p ModernPalette) []RGBA {
	switch p {
	case PalWarmWhite:
		return []RGBA{{255, 214, 150, 255}, {255, 194, 120, 255}, {255, 232, 190, 255}}
	case PalIceBlueWhite:
		return []RGBA{{120, 210, 255, 255}, {225, 245, 255, 255}, {65, 155, 255, 255}}
	case PalHalloween:
		return []RGBA{{255, 125, 20, 255}, {165, 50, 235, 255}, {75, 225, 65, 255}}
	case PalPatriotic:
		return []RGBA{{240, 40, 45, 255}, {250, 250, 255, 255}, {40, 105, 245, 255}}
	case PalValentines:
		return []RGBA{{245, 35, 95, 255}, {255, 130, 175, 255}, {220, 25, 55, 255}}
	case PalAutumnHarvest:
		return []RGBA{{245, 110, 25, 255}, {220, 55, 25, 255}, {245, 190, 40, 255}}
	case PalStPatricks:
		return []RGBA{{35, 210, 75, 255}, {25, 150, 55, 255}, {255, 215, 45, 255}}
	case PalRainbow:
		return []RGBA{{245, 45, 45, 255}, {255, 165, 35, 255}, {250, 230, 40, 255}, {45, 210, 75, 255}, {45, 130, 255, 255}, {175, 60, 240, 255}}
	default: // Classic Christmas
		return []RGBA{{244, 42, 42, 255}, {44, 214, 72, 255}, {255, 224, 38, 255}, {42, 118, 255, 255}}
	}
}

func hsvToRGBA(h, s, v float64) RGBA {
	i := math.Floor(h * 6)
	f := h*6 - i
	p := v * (1 - s)
	q := v * (1 - f*s)
	t := v * (1 - (1-f)*s)
	var r, g, b float64
	switch int(i) % 6 {
	case 0:
		r, g, b = v, t, p
	case 1:
		r, g, b = q, v, p
	case 2:
		r, g, b = p, v, t
	case 3:
		r, g, b = p, q, v
	case 4:
		r, g, b = t, p, v
	case 5:
		r, g, b = v, p, q
	}
	return RGBA{uint8(r * 255), uint8(g * 255), uint8(b * 255), 255}
}

// ComputeNOAA returns approximate sunrise and sunset hours (local UTC+offset-free solar hour or UTC) and handles polar day/night cleanly.
func ComputeNOAA(latDeg, lonDeg float64, t time.Time) (sunriseMin, sunsetMin float64, ok bool) {
	dayOfYear := float64(t.YearDay())
	lat := latDeg * math.Pi / 180.0
	gamma := 2.0 * math.Pi / 365.0 * (dayOfYear - 1.0)
	eqTime := 229.18 * (0.000075 + 0.001868*math.Cos(gamma) - 0.032077*math.Sin(gamma) - 0.014615*math.Cos(2*gamma) - 0.040849*math.Sin(2*gamma))
	decl := 0.006918 - 0.399912*math.Cos(gamma) + 0.070257*math.Sin(gamma) - 0.006758*math.Cos(2*gamma) + 0.000907*math.Sin(2*gamma) - 0.002697*math.Cos(3*gamma) + 0.00148*math.Sin(3*gamma)
	zenith := 90.833 * math.Pi / 180.0
	cosHA := math.Cos(zenith)/(math.Cos(lat)*math.Cos(decl)) - math.Tan(lat)*math.Tan(decl)
	if cosHA > 1.0 || cosHA < -1.0 {
		return 0, 0, false
	}
	haDeg := math.Acos(cosHA) * 180.0 / math.Pi
	_, tzOff := t.Zone()
	tzHours := float64(tzOff) / 3600.0
	solarNoon := 720.0 - 4.0*lonDeg - eqTime + tzHours*60.0
	return solarNoon - haDeg*4.0, solarNoon + haDeg*4.0, true
}
