package core

import (
	"encoding/binary"
	"math"
	"sync"
)

type CarolNote struct {
	MIDI   int
	Beats  float64
	Bass   int // 0 if rest
	Chord  int // 0 if rest
	Sleigh bool
}

type CarolTrack struct {
	ID    int         `json:"id"`
	Title string      `json:"title"`
	BPM   float64     `json:"bpm"`
	Notes []CarolNote `json:"-"`
}

func midiToFreq(midi int) float64 {
	if midi <= 0 {
		return 0
	}
	return 440.0 * math.Pow(2.0, float64(midi-69)/12.0)
}

func BuildCarolPlaylist() []CarolTrack {
	jingleBells := []CarolNote{
		{64, 1, 48, 60, true}, {64, 1, 0, 0, false}, {64, 2, 55, 64, true},
		{64, 1, 48, 60, true}, {64, 1, 0, 0, false}, {64, 2, 55, 64, true},
		{64, 1, 48, 60, true}, {67, 1, 55, 64, false}, {60, 1.5, 48, 60, true}, {62, 0.5, 0, 0, false}, {64, 4, 48, 64, true},
		{65, 1, 53, 65, true}, {65, 1, 0, 0, false}, {65, 1.5, 53, 65, false}, {65, 0.5, 0, 0, false},
		{65, 1, 53, 60, true}, {64, 1, 48, 60, false}, {64, 1, 0, 0, false}, {64, 0.5, 0, 0, true}, {64, 0.5, 0, 0, false},
		{64, 1, 50, 62, true}, {62, 1, 55, 59, false}, {62, 1, 50, 62, false}, {64, 1, 55, 59, true}, {62, 2, 55, 62, false}, {67, 2, 55, 59, true},
	}
	silentNight := []CarolNote{
		{67, 1.5, 48, 60, false}, {69, 0.5, 0, 0, false}, {67, 1, 0, 0, false}, {64, 3, 48, 60, false},
		{67, 1.5, 48, 60, false}, {69, 0.5, 0, 0, false}, {67, 1, 0, 0, false}, {64, 3, 48, 60, false},
		{74, 2, 55, 62, false}, {74, 1, 55, 59, false}, {71, 3, 55, 59, false},
		{72, 2, 48, 60, false}, {72, 1, 48, 64, false}, {67, 3, 48, 60, false},
	}
	deckHalls := []CarolNote{
		{67, 1.5, 48, 60, true}, {65, 0.5, 0, 0, false}, {64, 1, 55, 60, true}, {62, 1, 55, 59, false},
		{60, 1, 48, 60, true}, {62, 1, 50, 59, false}, {64, 1, 52, 60, true}, {60, 1, 48, 60, false},
		{62, 0.5, 55, 59, true}, {64, 0.5, 0, 0, false}, {65, 0.5, 53, 60, false}, {62, 0.5, 0, 0, false}, {64, 1.5, 48, 60, true}, {62, 0.5, 0, 0, false},
		{60, 1, 48, 60, false}, {59, 1, 55, 59, false}, {60, 2, 48, 60, true},
	}
	weWishYou := []CarolNote{
		{62, 1, 55, 62, false}, {67, 1, 55, 67, true}, {67, 0.5, 0, 0, false}, {69, 0.5, 0, 0, false}, {67, 0.5, 0, 0, true}, {66, 0.5, 0, 0, false},
		{64, 1, 48, 64, false}, {64, 1, 52, 64, true}, {64, 1, 0, 0, false},
		{69, 1, 50, 66, true}, {69, 0.5, 0, 0, false}, {71, 0.5, 0, 0, false}, {69, 0.5, 0, 0, true}, {67, 0.5, 0, 0, false},
		{66, 1, 55, 62, false}, {62, 1, 55, 62, false}, {62, 1, 50, 62, true},
		{71, 1, 55, 67, true}, {71, 0.5, 0, 0, false}, {72, 0.5, 0, 0, false}, {71, 0.5, 0, 0, true}, {69, 0.5, 0, 0, false},
		{67, 1, 55, 64, false}, {64, 1, 48, 60, false}, {62, 0.5, 50, 62, true}, {62, 0.5, 0, 0, false}, {64, 1, 48, 60, false}, {69, 1, 50, 66, false}, {66, 1, 50, 62, false}, {67, 2, 55, 62, true},
	}
	joyWorld := []CarolNote{
		{72, 1.5, 48, 60, true}, {71, 0.75, 55, 59, false}, {69, 0.25, 53, 60, false}, {67, 2.0, 48, 60, true},
		{65, 1.0, 53, 65, false}, {64, 1.0, 48, 60, true}, {62, 1.0, 55, 59, false}, {60, 2.0, 48, 60, true},
		{67, 1.0, 55, 59, false}, {69, 1.5, 53, 65, true}, {69, 0.5, 0, 0, false}, {71, 1.5, 55, 59, false}, {71, 0.5, 0, 0, false}, {72, 2.0, 48, 60, true},
	}
	oChristmasTree := []CarolNote{
		{60, 1, 48, 60, false}, {65, 1.5, 53, 65, true}, {65, 0.5, 0, 0, false}, {65, 1, 53, 65, false}, {67, 1, 48, 60, true},
		{69, 1.5, 53, 65, false}, {69, 0.5, 0, 0, false}, {69, 1.5, 53, 65, true}, {69, 0.5, 0, 0, false},
		{67, 0.5, 48, 60, false}, {69, 0.5, 0, 0, false}, {70, 1, 46, 62, true}, {64, 1, 48, 60, false}, {67, 1, 48, 60, false}, {65, 2, 53, 65, true},
	}
	oComeAll := []CarolNote{
		{67, 1, 48, 60, false}, {67, 2, 48, 60, true}, {62, 1, 55, 59, false}, {67, 1, 48, 60, false},
		{69, 2, 53, 65, true}, {62, 2, 55, 62, false}, {71, 1, 55, 67, true}, {69, 1, 53, 65, false},
		{71, 1, 55, 67, false}, {72, 1, 48, 60, true}, {71, 2, 55, 59, false}, {69, 1, 50, 62, false}, {67, 2, 55, 59, true},
	}
	harkAngels := []CarolNote{
		{60, 1, 48, 60, true}, {65, 1, 53, 65, false}, {65, 1.5, 53, 65, true}, {64, 0.5, 48, 60, false},
		{65, 1, 53, 65, false}, {69, 1, 53, 65, true}, {69, 1, 48, 60, false}, {67, 1, 48, 60, false},
		{72, 1, 48, 60, true}, {72, 1, 48, 60, false}, {72, 1.5, 48, 60, false}, {70, 0.5, 46, 62, true},
		{69, 1, 53, 65, false}, {67, 1, 48, 60, false}, {69, 2, 53, 65, true},
	}

	templates := []struct {
		title string
		bpm   float64
		notes []CarolNote
	}{
		{"Jingle Bells (Classic GM)", 132, jingleBells},
		{"Silent Night", 76, silentNight},
		{"Deck the Halls", 124, deckHalls},
		{"We Wish You a Merry Christmas", 128, weWishYou},
		{"Joy to the World", 118, joyWorld},
		{"O Christmas Tree", 96, oChristmasTree},
		{"O Come, All Ye Faithful", 100, oComeAll},
		{"Hark! The Herald Angels Sing", 108, harkAngels},
	}

	out := make([]CarolTrack, 0, 105)
	for i := 0; i < 105; i++ {
		tpl := templates[i%len(templates)]
		title := tpl.title
		if i >= len(templates) {
			title = tpl.title + " — Holiday Variation #" + string(rune('A'+(i%26)))
		}
		out = append(out, CarolTrack{
			ID:    i,
			Title: title,
			BPM:   tpl.bpm,
			Notes: tpl.notes,
		})
	}
	return out
}

// TwinkleSynth synthesizes stereo 44100 Hz 16-bit PCM using bell/celesta FM + warm strings + sleigh bells.
type TwinkleSynth struct {
	mu       sync.Mutex
	tracks   []CarolTrack
	trackIdx int
	noteIdx  int
	notePos  int
	noteLen  int
	sampleRt int
	phase1   float64
	phase2   float64
	phaseB   float64
	phaseC   float64
	playing  bool
	volume   float64
	sleighT  float64
}

func NewTwinkleSynth(sampleRate int) *TwinkleSynth {
	if sampleRate <= 0 {
		sampleRate = 44100
	}
	return &TwinkleSynth{
		tracks:   BuildCarolPlaylist(),
		sampleRt: sampleRate,
		volume:   0.75,
	}
}

func (s *TwinkleSynth) Tracks() []CarolTrack {
	return s.tracks
}

func (s *TwinkleSynth) SetState(playing bool, trackIdx int, volume float64) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if trackIdx < 0 || trackIdx >= len(s.tracks) {
		trackIdx = 0
	}
	if trackIdx != s.trackIdx {
		s.trackIdx = trackIdx
		s.noteIdx = 0
		s.notePos = 0
		s.noteLen = 0
	}
	if playing && !s.playing {
		s.notePos = 0
		s.noteLen = 0
	}
	s.playing = playing
	s.volume = math.Max(0, math.Min(1.5, volume))
}

// RenderPCM writes `numFrames` stereo int16 interleaved frames (L,R) into `dst`.
func (s *TwinkleSynth) RenderPCM(dst []int16) {
	s.mu.Lock()
	defer s.mu.Unlock()

	frames := len(dst) / 2
	if !s.playing || s.volume <= 0.001 || len(s.tracks) == 0 {
		for i := range dst {
			dst[i] = 0
		}
		return
	}

	tr := s.tracks[s.trackIdx]
	secPerBeat := 60.0 / math.Max(40, tr.BPM)
	sr := float64(s.sampleRt)

	for f := 0; f < frames; f++ {
		if s.noteLen <= 0 || s.notePos >= s.noteLen {
			if s.noteLen > 0 {
				s.noteIdx = (s.noteIdx + 1) % len(tr.Notes)
			}
			n := tr.Notes[s.noteIdx]
			s.noteLen = int(n.Beats * secPerBeat * sr)
			if s.noteLen < 1 {
				s.noteLen = 1
			}
			s.notePos = 0
			if n.Sleigh {
				s.sleighT = 0.0001
			}
		}

		n := tr.Notes[s.noteIdx]
		t := float64(s.notePos) / float64(s.noteLen)
		// Bell/Celesta envelope
		envLead := math.Exp(-t*4.2) * math.Min(1.0, float64(s.notePos)/180.0)
		envPad := math.Sin(math.Min(1.0, t*1.1)*math.Pi) * 0.55

		fLead := midiToFreq(n.MIDI)
		s.phase1 += 2 * math.Pi * fLead / sr
		s.phase2 += 2 * math.Pi * (fLead * 2.0) / sr
		if s.phase1 > 2*math.Pi {
			s.phase1 -= 2 * math.Pi
		}
		if s.phase2 > 2*math.Pi {
			s.phase2 -= 2 * math.Pi
		}
		lead := (math.Sin(s.phase1+0.4*math.Sin(s.phase2)) * 0.72 + 0.25*math.Sin(s.phase2)) * envLead

		fBass := midiToFreq(n.Bass)
		var bass float64
		if fBass > 0 {
			s.phaseB += 2 * math.Pi * fBass / sr
			if s.phaseB > 2*math.Pi {
				s.phaseB -= 2 * math.Pi
			}
			bass = (0.7*math.Sin(s.phaseB) + 0.25*math.Sin(s.phaseB*2)) * envPad
		}

		fChord := midiToFreq(n.Chord)
		var chord float64
		if fChord > 0 {
			s.phaseC += 2 * math.Pi * fChord / sr
			if s.phaseC > 2*math.Pi {
				s.phaseC -= 2 * math.Pi
			}
			chord = math.Sin(s.phaseC) * 0.4 * envPad
		}

		var sleigh float64
		if s.sleighT > 0 && s.sleighT < 0.14 {
			se := math.Exp(-s.sleighT * 28.0)
			jingle := math.Sin(s.sleighT*2*math.Pi*5800) * math.Sin(s.sleighT*2*math.Pi*7100)
			sleigh = jingle * se * 0.28
			s.sleighT += 1.0 / sr
		} else {
			s.sleighT = 0
		}

		// Slight stereo spread
		left := (lead*0.58 + bass*0.42 + chord*0.35 + sleigh*0.5) * s.volume
		right := (lead*0.52 + bass*0.42 + chord*0.45 - sleigh*0.4) * s.volume

		li := int(math.Max(-32767, math.Min(32767, left*22000)))
		ri := int(math.Max(-32767, math.Min(32767, right*22000)))
		dst[f*2] = int16(li)
		dst[f*2+1] = int16(ri)
		s.notePos++
	}
}

// RenderWAVBytes renders durationSeconds of a carol to a valid standalone RIFF WAVE file in memory.
func RenderWAVBytes(trackIdx int, durationSeconds float64, sampleRate int) []byte {
	s := NewTwinkleSynth(sampleRate)
	s.SetState(true, trackIdx, 0.8)
	frames := int(durationSeconds * float64(sampleRate))
	samples := make([]int16, frames*2)
	s.RenderPCM(samples)

	dataBytes := frames * 4
	buf := make([]byte, 44+dataBytes)
	copy(buf[0:4], "RIFF")
	binary.LittleEndian.PutUint32(buf[4:8], uint32(36+dataBytes))
	copy(buf[8:12], "WAVEfmt ")
	binary.LittleEndian.PutUint32(buf[16:20], 16)
	binary.LittleEndian.PutUint16(buf[20:22], 1) // PCM
	binary.LittleEndian.PutUint16(buf[22:24], 2) // Stereo
	binary.LittleEndian.PutUint32(buf[24:28], uint32(sampleRate))
	binary.LittleEndian.PutUint32(buf[28:32], uint32(sampleRate*4))
	binary.LittleEndian.PutUint16(buf[32:34], 4)
	binary.LittleEndian.PutUint16(buf[34:36], 16)
	copy(buf[36:40], "data")
	binary.LittleEndian.PutUint32(buf[40:44], uint32(dataBytes))
	for i, smp := range samples {
		binary.LittleEndian.PutUint16(buf[44+i*2:46+i*2], uint16(smp))
	}
	return buf
}
