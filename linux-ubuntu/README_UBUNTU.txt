RE: TWINKLE BULBS — VERSION 7: NEXT GENERATION (UBUNTU DEBIAN PACKAGE)
======================================================================

INSTALLATION:
  Ubuntu x86_64 (Intel/AMD):
    sudo apt install ./re-twinkle-bulbs_7.0.0_amd64.deb

  Ubuntu ARM64:
    sudo apt install ./re-twinkle-bulbs_7.0.0_arm64.deb

DEPENDENCIES:
  Core daemon, Web Command Center, Classic/Modern Engine & TwinkleSynth DSP
  are compiled into the single static native ELF binary /usr/bin/twinklebulbs.
  Desktop GTK3/Cairo transparent click-through overlay uses Python 3 + GTK3
  (installed automatically by apt via Recommends: python3-gi gir1.2-gtk-3.0
   python3-cairo; for Wayland sessions run `GDK_BACKEND=x11 twinklebulbs` if
   compositor restricts top-level overlay placement).

COMMANDS:
  twinklebulbs              Launch bulbs overlay, GTK control panel, audio & Web UI
  twinklebulbs --no-gui     Run headless API + audio + engine daemon (:19697)
  twinklebulbs --open-web   Start and open http://127.0.0.1:19697/remote
  twinklebulbs --docs       Read full restoration history, manual & Freeware credits
  twinklebulbs --verify     Run self-check diagnostics and exit

TRIBUTE & FREEWARE LICENSE:
  All credit goes to original authors Don Metzler and Barefoot Productions.
  Distributed as Freeware out of love for the original program.
