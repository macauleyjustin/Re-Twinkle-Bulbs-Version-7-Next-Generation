import Cocoa

final class PreferencesSecondaryTabsCoordinator: NSObject {
    private unowned let owner: PreferencesWindowController

    // Music tab (Restored Programmable Jukebox & Sound Bank)
    private let musicEnableCheck = NSButton(checkboxWithTitle: "Enable Background Holiday Music", target: nil, action: nil)
    private let musicOrderPopup = NSPopUpButton()
    private let musicRepeatPopup = NSPopUpButton()
    private let musicTrackDelayField = NSTextField()
    private let musicVolumeSlider = NSSlider(value: 0.85, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let musicDirField = NSTextField()
    private let soundBankLabel = NSTextField(labelWithString: "MIDI Synth: Built-in TwinkleSynth GM (64-Voice DSP)")
    private let musicOnlySSCheck = NSButton(checkboxWithTitle: "Play Music Only During Screen Saver", target: nil, action: nil)
    private let musicPauseCheck = NSButton(checkboxWithTitle: "Auto-Pause After (min):", target: nil, action: nil)
    private let musicPauseField = NSTextField()
    private let musicPopup = NSPopUpButton()
    private let nowPlayingLbl = NSTextField(labelWithString: "Status: Stopped")

    // Screen Saver tab
    private let ssEnableCheck = NSButton(checkboxWithTitle: "Enable Automatic Screen Saver After (min):", target: nil, action: nil)
    private let ssDelayField = NSTextField()
    private let ssModulePopup = NSPopUpButton()
    private let ssLightsCheck = NSButton(checkboxWithTitle: "Show Twinkle Bulbs Around Screen Saver", target: nil, action: nil)
    private let ssLogoCheck = NSButton(checkboxWithTitle: "Show Re: Twinkle Bulbs Watermark", target: nil, action: nil)
    private let ssEnableMsgCheck = NSButton(checkboxWithTitle: "Display Message:", target: nil, action: nil)
    private let ssMsgField = NSTextField()
    private let ssMsgColorWell = NSColorWell()
    private let ssMsgBoldCheck = NSButton(checkboxWithTitle: "Bold", target: nil, action: nil)
    private let ssScrollMsgCheck = NSButton(checkboxWithTitle: "Scroll Message", target: nil, action: nil)
    private let ssMouseClickCheck = NSButton(checkboxWithTitle: "Exit on Click", target: nil, action: nil)
    private let ssMouseMoveCheck = NSButton(checkboxWithTitle: "Exit on Move", target: nil, action: nil)
    private let ssKeyboardCheck = NSButton(checkboxWithTitle: "Exit on Keypress", target: nil, action: nil)
    private let ssHotCornersCheck = NSButton(checkboxWithTitle: "Hot Corner (Top-Right Screen Corner Launches Saver)", target: nil, action: nil)
    private var ssMiniPreview: ScreenSaverCanvasView?
    private var ssMiniTimer: Timer?

    // Wallpaper tab
    private let wpCategoryPopup = NSPopUpButton()
    private let wallpaperPopup = NSPopUpButton()
    private let wpFavBtn = NSButton(title: "☆ Favorite", target: nil, action: nil)
    private let wpMonitorPopup = NSPopUpButton()
    private let wpStylePopup = NSPopUpButton()
    private let wpAutoRotateCheck = NSButton(checkboxWithTitle: "Auto-Rotate Wallpapers Every (min):", target: nil, action: nil)
    private let wpFreqField = NSTextField()
    private let wpPreviewImage = NSImageView()
    private let wpCountLabel = NSTextField(labelWithString: "130 Seasonal Wallpapers")

    // Calendar tab
    private let holidayPopup = NSPopUpButton()
    private let countdownStatusLbl = NSTextField(labelWithString: "")
    private let eventMsgsCheck = NSButton(checkboxWithTitle: "Show Startup Greeting Messages for Matching Dates", target: nil, action: nil)
    private let customNameField = NSTextField()
    private let customDateField = NSTextField()

    init(owner: PreferencesWindowController) {
        self.owner = owner
        super.init()
    }

    deinit {
        ssMiniTimer?.invalidate()
    }

    // MARK: - Music Tab (DIALOG/133)

    func makeMusicTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "music")
        item.label = "Music"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 710, height: 440))

        let box = NSBox(frame: NSRect(x: 16, y: 14, width: 678, height: 412))
        box.title = "Holiday Music Jukebox (MIDI / RMI / MP3 / WAV / AIFF)"

        musicEnableCheck.frame = NSRect(x: 16, y: 360, width: 300, height: 22)
        musicEnableCheck.target = self; musicEnableCheck.action = #selector(controlChanged)

        let dirLbl = NSTextField(labelWithString: "Music Folder:")
        dirLbl.frame = NSRect(x: 16, y: 326, width: 100, height: 18)
        musicDirField.frame = NSRect(x: 120, y: 324, width: 320, height: 22)
        musicDirField.placeholderString = "(Optional custom folder; also scans ImportedMusic)"
        let browseDirBtn = NSButton(title: "Choose Folder...", target: self, action: #selector(chooseMusicDirectory))
        browseDirBtn.frame = NSRect(x: 448, y: 321, width: 120, height: 26)
        let clearDirBtn = NSButton(title: "Clear", target: self, action: #selector(clearMusicDirectory))
        clearDirBtn.frame = NSRect(x: 574, y: 321, width: 70, height: 26)

        let lblTrack = NSTextField(labelWithString: "Playlist Track:")
        lblTrack.frame = NSRect(x: 16, y: 286, width: 100, height: 18)
        musicPopup.frame = NSRect(x: 120, y: 282, width: 360, height: 26)
        let impBtn = NSButton(title: "Open / Import Files...", target: self, action: #selector(importMusicFiles))
        impBtn.frame = NSRect(x: 488, y: 282, width: 156, height: 26)

        let playBtn = NSButton(title: "Play", target: self, action: #selector(playSelectedTrack))
        playBtn.frame = NSRect(x: 16, y: 240, width: 76, height: 28)
        let pauseBtn = NSButton(title: "Pause / Resume", target: self, action: #selector(pauseResumeMusic))
        pauseBtn.frame = NSRect(x: 98, y: 240, width: 124, height: 28)
        let stopBtn = NSButton(title: "Stop", target: self, action: #selector(stopMusic))
        stopBtn.frame = NSRect(x: 228, y: 240, width: 76, height: 28)
        let prevBtn = NSButton(title: "Previous", target: self, action: #selector(previousTrack))
        prevBtn.frame = NSRect(x: 310, y: 240, width: 88, height: 28)
        let nextBtn = NSButton(title: "Next", target: self, action: #selector(nextTrack))
        nextBtn.frame = NSRect(x: 404, y: 240, width: 78, height: 28)

        let volLbl = NSTextField(labelWithString: "Volume:")
        volLbl.frame = NSRect(x: 16, y: 198, width: 96, height: 18)
        musicVolumeSlider.frame = NSRect(x: 120, y: 196, width: 210, height: 20)
        musicVolumeSlider.isContinuous = true
        musicVolumeSlider.target = self; musicVolumeSlider.action = #selector(volumeSliderChanged)

        let delayLbl = NSTextField(labelWithString: "Delay Between Tracks (s):")
        delayLbl.frame = NSRect(x: 360, y: 198, width: 166, height: 18)
        musicTrackDelayField.frame = NSRect(x: 530, y: 196, width: 64, height: 22)

        let ordLbl = NSTextField(labelWithString: "Play Order:")
        ordLbl.frame = NSRect(x: 16, y: 158, width: 96, height: 18)
        musicOrderPopup.addItems(withTitles: ["Sequential", "Shuffle (Random)"])
        musicOrderPopup.frame = NSRect(x: 120, y: 154, width: 170, height: 24)
        musicOrderPopup.target = self; musicOrderPopup.action = #selector(controlChanged)

        let repLbl = NSTextField(labelWithString: "Repeat:")
        repLbl.frame = NSRect(x: 360, y: 158, width: 60, height: 18)
        musicRepeatPopup.addItems(withTitles: MusicRepeatMode.allCases.map(\.displayName))
        musicRepeatPopup.frame = NSRect(x: 424, y: 154, width: 170, height: 24)
        musicRepeatPopup.target = self; musicRepeatPopup.action = #selector(controlChanged)

        musicOnlySSCheck.frame = NSRect(x: 16, y: 116, width: 290, height: 22)
        musicOnlySSCheck.target = self; musicOnlySSCheck.action = #selector(controlChanged)
        musicPauseCheck.frame = NSRect(x: 360, y: 116, width: 170, height: 22)
        musicPauseCheck.target = self; musicPauseCheck.action = #selector(controlChanged)
        musicPauseField.frame = NSRect(x: 534, y: 116, width: 52, height: 22)

        soundBankLabel.frame = NSRect(x: 16, y: 74, width: 390, height: 18)
        let bankBtn = NSButton(title: "Custom .SF2 Bank...", target: self, action: #selector(chooseSoundBank))
        bankBtn.frame = NSRect(x: 416, y: 70, width: 148, height: 26)
        let resetBankBtn = NSButton(title: "Built-In Synth", target: self, action: #selector(resetSoundBank))
        resetBankBtn.frame = NSRect(x: 570, y: 70, width: 100, height: 26)

        nowPlayingLbl.frame = NSRect(x: 16, y: 20, width: 640, height: 34)
        nowPlayingLbl.textColor = .secondaryLabelColor
        nowPlayingLbl.maximumNumberOfLines = 2

        for v: NSView in [
            musicEnableCheck, dirLbl, musicDirField, browseDirBtn, clearDirBtn,
            lblTrack, musicPopup, impBtn, playBtn, pauseBtn, stopBtn, prevBtn, nextBtn,
            volLbl, musicVolumeSlider, delayLbl, musicTrackDelayField,
            ordLbl, musicOrderPopup, repLbl, musicRepeatPopup,
            musicOnlySSCheck, musicPauseCheck, musicPauseField,
            soundBankLabel, bankBtn, resetBankBtn, nowPlayingLbl
        ] {
            box.contentView?.addSubview(v)
        }
        view.addSubview(box)
        item.view = view
        return item
    }

    // MARK: - Screen Saver Tab (DIALOG/134)

    func makeScreenSaverTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "screensaver")
        item.label = "Screen Saver"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 710, height: 440))

        let leftBox = NSBox(frame: NSRect(x: 16, y: 16, width: 406, height: 410))
        leftBox.title = "Built-in Twinkle Bulbs Screen Saver"

        let modLbl = NSTextField(labelWithString: "Module (25):")
        modLbl.frame = NSRect(x: 14, y: 356, width: 76, height: 18)
        ssModulePopup.removeAllItems()
        ssModulePopup.addItems(withTitles: ScreenSaverModuleID.allCases.map(\.displayName))
        ssModulePopup.frame = NSRect(x: 92, y: 352, width: 174, height: 24)
        ssModulePopup.target = self; ssModulePopup.action = #selector(ssControlChanged)

        let cfgBtn = NSButton(title: "Configure...", target: self, action: #selector(configureSSModule))
        cfgBtn.frame = NSRect(x: 274, y: 352, width: 112, height: 26)

        ssEnableCheck.frame = NSRect(x: 14, y: 318, width: 290, height: 22)
        ssEnableCheck.target = self; ssEnableCheck.action = #selector(ssControlChanged)
        ssDelayField.frame = NSRect(x: 310, y: 318, width: 48, height: 22)

        ssLightsCheck.frame = NSRect(x: 14, y: 286, width: 290, height: 22)
        ssLightsCheck.target = self; ssLightsCheck.action = #selector(ssControlChanged)
        ssLogoCheck.frame = NSRect(x: 14, y: 256, width: 290, height: 22)
        ssLogoCheck.target = self; ssLogoCheck.action = #selector(ssControlChanged)
        ssHotCornersCheck.frame = NSRect(x: 14, y: 226, width: 372, height: 22)
        ssHotCornersCheck.target = self; ssHotCornersCheck.action = #selector(ssControlChanged)

        ssEnableMsgCheck.frame = NSRect(x: 14, y: 186, width: 140, height: 22)
        ssEnableMsgCheck.target = self; ssEnableMsgCheck.action = #selector(ssControlChanged)
        ssMsgField.frame = NSRect(x: 160, y: 184, width: 226, height: 22)
        ssMsgColorWell.frame = NSRect(x: 14, y: 146, width: 54, height: 26)
        ssMsgColorWell.target = self; ssMsgColorWell.action = #selector(ssControlChanged)
        ssMsgBoldCheck.frame = NSRect(x: 80, y: 148, width: 70, height: 22)
        ssMsgBoldCheck.target = self; ssMsgBoldCheck.action = #selector(ssControlChanged)
        ssScrollMsgCheck.frame = NSRect(x: 160, y: 148, width: 150, height: 22)
        ssScrollMsgCheck.target = self; ssScrollMsgCheck.action = #selector(ssControlChanged)

        ssMouseClickCheck.frame = NSRect(x: 14, y: 100, width: 110, height: 22)
        ssMouseMoveCheck.frame = NSRect(x: 132, y: 100, width: 118, height: 22)
        ssKeyboardCheck.frame = NSRect(x: 258, y: 100, width: 132, height: 22)
        for c in [ssMouseClickCheck, ssMouseMoveCheck, ssKeyboardCheck] {
            c.target = self; c.action = #selector(ssControlChanged)
        }

        let testBtn = NSButton(title: "Test Screen Saver Full Screen", target: self, action: #selector(testScreenSaver))
        testBtn.frame = NSRect(x: 14, y: 20, width: 220, height: 30)

        for v: NSView in [modLbl, ssModulePopup, cfgBtn, ssEnableCheck, ssDelayField, ssLightsCheck, ssLogoCheck, ssHotCornersCheck, ssEnableMsgCheck, ssMsgField, ssMsgColorWell, ssMsgBoldCheck, ssScrollMsgCheck, ssMouseClickCheck, ssMouseMoveCheck, ssKeyboardCheck, testBtn] {
            leftBox.contentView?.addSubview(v)
        }
        view.addSubview(leftBox)

        let prevBox = NSBox(frame: NSRect(x: 432, y: 120, width: 264, height: 306))
        prevBox.title = "Screen Saver Live Preview"
        let mini = ScreenSaverCanvasView(frame: NSRect(x: 8, y: 14, width: 244, height: 264), settings: owner.draft, preview: true)
        ssMiniPreview = mini
        prevBox.contentView?.addSubview(mini)
        view.addSubview(prevBox)

        ssMiniTimer = Timer.scheduledTimer(withTimeInterval: 0.050, repeats: true) { [weak self] _ in
            guard let self, self.owner.window?.isVisible == true else { return }
            self.ssMiniPreview?.stepFrame()
        }

        item.view = view
        return item
    }

    // MARK: - Wallpaper Tab (DIALOG/135 — 130 Seasonal Collections + Per-Monitor Apply)

    func makeWallpaperTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "wallpaper")
        item.label = "Wallpaper"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 750, height: 480))

        let box = NSBox(frame: NSRect(x: 16, y: 16, width: 360, height: 450))
        box.title = "Seasonal Wallpapers (130 Built-in + User Imports)"

        let catLbl = NSTextField(labelWithString: "Collection:")
        catLbl.frame = NSRect(x: 14, y: 394, width: 72, height: 18)
        wpCategoryPopup.removeAllItems()
        wpCategoryPopup.addItem(withTitle: "All Collections (130+)")
        wpCategoryPopup.addItem(withTitle: "Favorites ★")
        for c in WallpaperThemeCategory.allCases where c != .all {
            wpCategoryPopup.addItem(withTitle: c.rawValue)
        }
        wpCategoryPopup.frame = NSRect(x: 90, y: 390, width: 252, height: 24)
        wpCategoryPopup.target = self; wpCategoryPopup.action = #selector(wpCategoryChanged)

        let lbl = NSTextField(labelWithString: "Wallpaper:")
        lbl.frame = NSRect(x: 14, y: 358, width: 72, height: 18)
        wallpaperPopup.frame = NSRect(x: 90, y: 354, width: 174, height: 24)
        wallpaperPopup.target = self; wallpaperPopup.action = #selector(wallpaperSelectionChanged)
        wpFavBtn.frame = NSRect(x: 270, y: 353, width: 72, height: 26)
        wpFavBtn.font = .systemFont(ofSize: 10.5)
        wpFavBtn.target = self; wpFavBtn.action = #selector(toggleFavoriteWallpaper)

        wpCountLabel.font = .systemFont(ofSize: 10.5)
        wpCountLabel.textColor = .secondaryLabelColor
        wpCountLabel.frame = NSRect(x: 14, y: 330, width: 320, height: 16)

        let sLbl = NSTextField(labelWithString: "Placement Style:")
        sLbl.frame = NSRect(x: 14, y: 292, width: 110, height: 18)
        wpStylePopup.removeAllItems()
        wpStylePopup.addItems(withTitles: WallpaperStyle.allCases.map(\.displayName))
        wpStylePopup.frame = NSRect(x: 130, y: 288, width: 170, height: 24)
        wpStylePopup.target = self; wpStylePopup.action = #selector(controlChanged)

        let mLbl = NSTextField(labelWithString: "Target Monitor:")
        mLbl.frame = NSRect(x: 14, y: 254, width: 110, height: 18)
        wpMonitorPopup.removeAllItems()
        wpMonitorPopup.addItem(withTitle: "All Displays")
        for (idx, scr) in NSScreen.screens.enumerated() {
            wpMonitorPopup.addItem(withTitle: "Display \(idx + 1) (\(Int(scr.frame.width))×\(Int(scr.frame.height)))")
        }
        wpMonitorPopup.frame = NSRect(x: 130, y: 250, width: 212, height: 24)

        wpAutoRotateCheck.frame = NSRect(x: 14, y: 210, width: 236, height: 22)
        wpAutoRotateCheck.target = self; wpAutoRotateCheck.action = #selector(controlChanged)
        wpFreqField.frame = NSRect(x: 256, y: 210, width: 52, height: 22)

        let applyWpBtn = NSButton(title: "Set Desktop Wallpaper Now", target: self, action: #selector(applyWallpaperNow))
        applyWpBtn.frame = NSRect(x: 14, y: 146, width: 220, height: 30)

        let importWpBtn = NSButton(title: "Import Wallpaper Images...", target: self, action: #selector(importWallpapers))
        importWpBtn.frame = NSRect(x: 14, y: 102, width: 220, height: 28)

        for v: NSView in [catLbl, wpCategoryPopup, lbl, wallpaperPopup, wpFavBtn, wpCountLabel, sLbl, wpStylePopup, mLbl, wpMonitorPopup, wpAutoRotateCheck, wpFreqField, applyWpBtn, importWpBtn] {
            box.contentView?.addSubview(v)
        }
        view.addSubview(box)

        let pBox = NSBox(frame: NSRect(x: 388, y: 80, width: 344, height: 386))
        pBox.title = "Live Wallpaper Preview"
        wpPreviewImage.frame = NSRect(x: 12, y: 18, width: 318, height: 336)
        wpPreviewImage.imageScaling = .scaleProportionallyUpOrDown
        pBox.contentView?.addSubview(wpPreviewImage)
        view.addSubview(pBox)

        item.view = view
        return item
    }

    // MARK: - Calendar Tab (DIALOG/132)

    func makeCalendarTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "calendar")
        item.label = "Calendar"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 710, height: 440))

        let box = NSBox(frame: NSRect(x: 16, y: 100, width: 678, height: 320))
        box.title = "Holiday Countdown & Event Calendar"

        let lbl = NSTextField(labelWithString: "Menu Bar Holiday Countdown:")
        lbl.frame = NSRect(x: 16, y: 266, width: 200, height: 18)
        holidayPopup.addItems(withTitles: HolidayCountdownType.allCases.map(\.displayName))
        holidayPopup.frame = NSRect(x: 220, y: 262, width: 210, height: 26)
        holidayPopup.target = self; holidayPopup.action = #selector(calendarChanged)

        countdownStatusLbl.font = .boldSystemFont(ofSize: 15)
        countdownStatusLbl.frame = NSRect(x: 16, y: 218, width: 600, height: 24)

        let custLbl = NSTextField(labelWithString: "Custom Holiday Name & MM/DD:")
        custLbl.frame = NSRect(x: 16, y: 170, width: 210, height: 18)
        customNameField.frame = NSRect(x: 230, y: 168, width: 180, height: 22)
        customDateField.frame = NSRect(x: 420, y: 168, width: 70, height: 22)

        eventMsgsCheck.frame = NSRect(x: 16, y: 124, width: 420, height: 22)
        eventMsgsCheck.target = self; eventMsgsCheck.action = #selector(calendarChanged)

        let openCalBtn = NSButton(title: "Open Holiday & Events Calendar Editor...", target: self, action: #selector(openCalendarModal))
        openCalBtn.frame = NSRect(x: 16, y: 40, width: 290, height: 30)

        let openAdventBtn = NSButton(title: "Open 24-Day Advent Calendar...", target: self, action: #selector(openAdventModal))
        openAdventBtn.frame = NSRect(x: 320, y: 40, width: 250, height: 30)

        for v: NSView in [lbl, holidayPopup, countdownStatusLbl, custLbl, customNameField, customDateField, eventMsgsCheck, openCalBtn, openAdventBtn] {
            box.contentView?.addSubview(v)
        }
        view.addSubview(box)
        item.view = view
        return item
    }

    // MARK: - Help & Tools Tab (DIALOG/142 & 3513)

    func makeHelpAndToolsTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "help")
        item.label = "Help"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 750, height: 480))

        let scroll = NSScrollView(frame: NSRect(x: 16, y: 56, width: 718, height: 408))
        scroll.hasVerticalScroller = true
        let tv = NSTextView(frame: scroll.bounds)
        tv.isEditable = false
        tv.font = .systemFont(ofSize: 12)
        tv.string = ProgramDocumentation.fullDocumentText
        scroll.documentView = tv
        view.addSubview(scroll)

        let openSupportBtn = NSButton(title: "Open Application Support Folder", target: self, action: #selector(openAppSupportFolder))
        openSupportBtn.frame = NSRect(x: 16, y: 14, width: 240, height: 28)
        view.addSubview(openSupportBtn)

        item.view = view
        return item
    }

    // MARK: - Sync & Actions

    func loadFromSettings(_ s: AppSettings) {
        musicEnableCheck.state = s.musicEnabled ? .on : .off
        musicOrderPopup.selectItem(at: max(0, min(1, s.musicPlayMode)))
        musicRepeatPopup.selectItem(at: s.musicRepeatMode.rawValue)
        musicTrackDelayField.doubleValue = s.musicTrackDelaySeconds
        musicVolumeSlider.doubleValue = s.musicVolume
        musicDirField.stringValue = s.musicDirectoryPath
        let bankName = s.customSoundBankPath.isEmpty ? "Built-in TwinkleSynth GM (64-Voice DSP)" : (s.customSoundBankPath as NSString).lastPathComponent
        soundBankLabel.stringValue = "MIDI Synth: \(bankName)"
        musicOnlySSCheck.state = s.ssMusic ? .on : .off
        musicPauseCheck.state = s.enablePause ? .on : .off
        musicPauseField.integerValue = s.pauseMinutes
        refreshMusicDropdown()

        if let idx = ScreenSaverModuleID.allCases.firstIndex(of: s.ssModule) {
            ssModulePopup.selectItem(at: idx)
        }
        ssEnableCheck.state = s.ssEnable ? .on : .off
        ssDelayField.integerValue = s.ssDelayMinutes
        ssLightsCheck.state = s.ssLights ? .on : .off
        ssLogoCheck.state = s.ssLogo ? .on : .off
        ssEnableMsgCheck.state = s.ssEnableMsg ? .on : .off
        ssMsgField.stringValue = s.ssMsg
        ssMsgColorWell.color = NSColor(hex: s.ssMsgColorHex, fallback: .red)
        ssMsgBoldCheck.state = s.ssMsgBold ? .on : .off
        ssScrollMsgCheck.state = s.ssScrollMsg ? .on : .off
        ssMouseClickCheck.state = s.ssMouseClick ? .on : .off
        ssMouseMoveCheck.state = s.ssMouseMove ? .on : .off
        ssKeyboardCheck.state = s.ssKeyboard ? .on : .off
        ssHotCornersCheck.state = s.useHotCorners ? .on : .off
        ssMiniPreview?.settings = s
        ssMiniPreview?.reinitializeScene()

        refreshWallpaperDropdown(selectedID: s.activeWallpaperID)
        wpStylePopup.selectItem(at: s.wallpaperType.rawValue)
        wpAutoRotateCheck.state = s.wallpaperChangeFlag ? .on : .off
        wpFreqField.integerValue = s.wallpaperChangeFreqMinutes

        holidayPopup.selectItem(at: s.countdownHoliday.rawValue)
        eventMsgsCheck.state = s.eventMsgs ? .on : .off
        customNameField.stringValue = s.customHolidayName
        customDateField.stringValue = String(format: "%02d/%02d", s.customHolidayMonth, s.customHolidayDay)
        updateCountdownPreview()
    }

    func commitFieldsIntoDraft() {
        owner.draft.bulbChangeFreqMinutes = max(1, owner.draft.bulbChangeFreqMinutes)
        owner.draft.musicEnabled = musicEnableCheck.state == .on
        owner.draft.musicPlayMode = max(0, musicOrderPopup.indexOfSelectedItem)
        owner.draft.musicRepeatMode = MusicRepeatMode(rawValue: max(0, musicRepeatPopup.indexOfSelectedItem)) ?? .repeatAll
        owner.draft.musicTrackDelaySeconds = musicTrackDelayField.doubleValue
        owner.draft.musicVolume = musicVolumeSlider.doubleValue
        owner.draft.musicDirectoryPath = musicDirField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        owner.draft.ssMusic = musicOnlySSCheck.state == .on
        owner.draft.enablePause = musicPauseCheck.state == .on
        owner.draft.pauseMinutes = max(1, musicPauseField.integerValue)

        let mods = ScreenSaverModuleID.allCases
        owner.draft.ssModule = mods[max(0, min(mods.count - 1, ssModulePopup.indexOfSelectedItem))]
        owner.draft.ssEnable = ssEnableCheck.state == .on
        owner.draft.ssDelayMinutes = max(1, ssDelayField.integerValue)
        owner.draft.ssLights = ssLightsCheck.state == .on
        owner.draft.ssLogo = ssLogoCheck.state == .on
        owner.draft.ssEnableMsg = ssEnableMsgCheck.state == .on
        owner.draft.ssMsg = ssMsgField.stringValue
        owner.draft.ssMsgColorHex = ssMsgColorWell.color.hexString
        owner.draft.ssMsgBold = ssMsgBoldCheck.state == .on
        owner.draft.ssScrollMsg = ssScrollMsgCheck.state == .on
        owner.draft.ssMouseClick = ssMouseClickCheck.state == .on
        owner.draft.ssMouseMove = ssMouseMoveCheck.state == .on
        owner.draft.ssKeyboard = ssKeyboardCheck.state == .on
        owner.draft.useHotCorners = ssHotCornersCheck.state == .on

        if let id = wallpaperPopup.selectedItem?.representedObject as? String {
            owner.draft.activeWallpaperID = id
        }
        owner.draft.wallpaperType = WallpaperStyle(rawValue: wpStylePopup.indexOfSelectedItem) ?? .tile
        owner.draft.wallpaperChangeFlag = wpAutoRotateCheck.state == .on
        owner.draft.wallpaperChangeFreqMinutes = max(1, wpFreqField.integerValue)

        owner.draft.countdownHoliday = HolidayCountdownType(rawValue: holidayPopup.indexOfSelectedItem) ?? .christmas
        owner.draft.eventMsgs = eventMsgsCheck.state == .on
        owner.draft.customHolidayName = customNameField.stringValue
        let parts = customDateField.stringValue.split(separator: "/")
        if parts.count == 2 {
            owner.draft.customHolidayMonth = max(1, min(12, Int(parts[0]) ?? 12))
            owner.draft.customHolidayDay = max(1, min(31, Int(parts[1]) ?? 25))
        }
    }

    private func updateMusicStatusLabel() {
        let ae = AudioEngineService.shared
        if let err = ae.lastErrorMessage, !err.isEmpty {
            nowPlayingLbl.textColor = .systemRed
            nowPlayingLbl.stringValue = "Error: \(err)"
        } else {
            nowPlayingLbl.textColor = .secondaryLabelColor
            let stateText = ae.isPaused ? "Paused" : (ae.isPlaying ? "Playing" : "Stopped")
            let info = ae.currentTrackFormatInfo.isEmpty ? "" : " (\(ae.currentTrackFormatInfo))"
            nowPlayingLbl.stringValue = "Status: \(stateText) — \(ae.currentTrackTitle)\(info)"
        }
    }

    private func refreshMusicDropdown() {
        musicPopup.removeAllItems()
        for t in AudioEngineService.shared.tracks {
            let tag = t.id.hasPrefix("builtin:") ? "[GM] " : "[User] "
            musicPopup.addItem(withTitle: "\(tag)\(t.title)")
        }
        let idx = min(AudioEngineService.shared.currentTrackIndex, max(0, AudioEngineService.shared.tracks.count - 1))
        if AudioEngineService.shared.tracks.count > 0 {
            musicPopup.selectItem(at: idx)
        }
        updateMusicStatusLabel()
    }

    private func refreshWallpaperDropdown(selectedID: String) {
        let allItems = WallpaperService.shared.items
        let catSel = wpCategoryPopup.indexOfSelectedItem
        let favs = owner.draft.favoriteWallpaperIDs
        let filtered = allItems.filter { item in
            if catSel == 1 {
                return favs.contains(item.id)
            } else if catSel >= 2 {
                let cats = WallpaperThemeCategory.allCases.filter { $0 != .all }
                let idx = catSel - 2
                if idx >= 0, idx < cats.count {
                    return item.category == cats[idx]
                }
            }
            return true
        }

        wallpaperPopup.removeAllItems()
        for item in filtered {
            let star = favs.contains(item.id) ? "★ " : ""
            wallpaperPopup.addItem(withTitle: "\(star)\(item.title)")
            wallpaperPopup.lastItem?.representedObject = item.id
        }
        if let idx = filtered.firstIndex(where: { $0.id == selectedID }) {
            wallpaperPopup.selectItem(at: idx)
        } else if !filtered.isEmpty {
            wallpaperPopup.selectItem(at: 0)
            if let fid = wallpaperPopup.selectedItem?.representedObject as? String {
                owner.draft.activeWallpaperID = fid
            }
        }
        wpCountLabel.stringValue = "Showing \(filtered.count) of \(allItems.count) wallpapers"
        updateWallpaperPreview()
    }

    private func updateWallpaperPreview() {
        guard let selID = wallpaperPopup.selectedItem?.representedObject as? String,
              let item = WallpaperService.shared.items.first(where: { $0.id == selID }) else { return }
        wpPreviewImage.image = WallpaperService.shared.previewImage(for: item)
        wpFavBtn.title = owner.draft.favoriteWallpaperIDs.contains(selID) ? "★ Fav" : "☆ Favorite"
    }

    private func updateCountdownPreview() {
        commitFieldsIntoDraft()
        countdownStatusLbl.stringValue = CalendarService.shared.countdownSummary(settings: owner.draft)?.headline ?? "Countdown disabled"
    }

    @objc private func controlChanged() { commitFieldsIntoDraft() }

    @objc private func ssControlChanged() {
        commitFieldsIntoDraft()
        ssMiniPreview?.settings = owner.draft
        ssMiniPreview?.reinitializeScene()
    }

    @objc private func playSelectedTrack() {
        commitFieldsIntoDraft()
        AudioEngineService.shared.play(trackIndex: musicPopup.indexOfSelectedItem, settings: owner.draft)
        updateMusicStatusLabel()
    }

    @objc private func pauseResumeMusic() {
        commitFieldsIntoDraft()
        AudioEngineService.shared.togglePause(settings: owner.draft)
        updateMusicStatusLabel()
    }

    @objc private func stopMusic() {
        AudioEngineService.shared.stop()
        updateMusicStatusLabel()
    }

    @objc private func previousTrack() {
        commitFieldsIntoDraft()
        AudioEngineService.shared.playPrevious(settings: owner.draft)
        refreshMusicDropdown()
    }

    @objc private func nextTrack() {
        commitFieldsIntoDraft()
        AudioEngineService.shared.playNext(settings: owner.draft)
        refreshMusicDropdown()
    }

    @objc private func volumeSliderChanged() {
        commitFieldsIntoDraft()
        AudioEngineService.shared.setVolume(owner.draft.musicVolume)
    }

    @objc private func chooseMusicDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let dirURL = panel.url {
            musicDirField.stringValue = dirURL.path
            commitFieldsIntoDraft()
            AudioEngineService.shared.rebuildTrackList(musicDirectoryPath: dirURL.path)
            refreshMusicDropdown()
        }
    }

    @objc private func clearMusicDirectory() {
        musicDirField.stringValue = ""
        commitFieldsIntoDraft()
        AudioEngineService.shared.rebuildTrackList(musicDirectoryPath: "")
        refreshMusicDropdown()
    }

    @objc private func chooseSoundBank() {
        let panel = NSOpenPanel()
        panel.title = "Choose Optional .SF2 SoundFont Bank"
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let bankURL = panel.url {
            owner.draft.customSoundBankPath = bankURL.path
            soundBankLabel.stringValue = "MIDI Synth: \(bankURL.lastPathComponent)"
            AudioEngineService.shared.playEffect(.softTick, enabled: owner.draft.soundFX)
        }
    }

    @objc private func resetSoundBank() {
        owner.draft.customSoundBankPath = ""
        soundBankLabel.stringValue = "MIDI Synth: Built-in TwinkleSynth GM (64-Voice DSP)"
    }

    @objc private func importMusicFiles() {
        let panel = NSOpenPanel()
        panel.title = "Import MIDI / RMI / MP3 / WAV / AIFF Files"
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for u in panel.urls {
                let d = AudioEngineService.importedMusicDirectory.appendingPathComponent(u.lastPathComponent)
                try? FileManager.default.removeItem(at: d)
                try? FileManager.default.copyItem(at: u, to: d)
            }
            AudioEngineService.shared.rebuildTrackList(musicDirectoryPath: owner.draft.musicDirectoryPath)
            refreshMusicDropdown()
        }
    }

    @objc private func configureSSModule() {
        commitFieldsIntoDraft()
        let alert = NSAlert()
        let mod = owner.draft.ssModule
        alert.messageText = "Configure \(mod.displayName) Screen Saver"
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 320, height: 110))
        stack.orientation = .vertical
        stack.alignment = .leading

        switch mod {
        case .blank:
            alert.informativeText = "Blank Screen renders pure black with optional perimeter twinkle bulbs and greeting message."
        case .clock:
            let bounceChk = NSButton(checkboxWithTitle: "Bounce Clock Position Around Screen", target: nil, action: nil)
            bounceChk.state = owner.draft.clockConfig.bouncePosition ? .on : .off
            let h24Chk = NSButton(checkboxWithTitle: "Use 24-Hour Clock Format", target: nil, action: nil)
            h24Chk.state = owner.draft.clockConfig.use24Hour ? .on : .off
            let secChk = NSButton(checkboxWithTitle: "Show Seconds", target: nil, action: nil)
            secChk.state = owner.draft.clockConfig.showSeconds ? .on : .off
            let dateChk = NSButton(checkboxWithTitle: "Show Date Below Time", target: nil, action: nil)
            dateChk.state = owner.draft.clockConfig.showDate ? .on : .off
            [bounceChk, h24Chk, secChk, dateChk].forEach { stack.addArrangedSubview($0) }
            alert.accessoryView = stack
            alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                owner.draft.clockConfig.bouncePosition = bounceChk.state == .on
                owner.draft.clockConfig.use24Hour = h24Chk.state == .on
                owner.draft.clockConfig.showSeconds = secChk.state == .on
                owner.draft.clockConfig.showDate = dateChk.state == .on
                ssControlChanged()
            }
            return
        case .fireworks:
            let skyChk = NSButton(checkboxWithTitle: "Show Night Skyline Silhouette", target: nil, action: nil)
            skyChk.state = owner.draft.fireworksConfig.showSkyline ? .on : .off
            let sndChk = NSButton(checkboxWithTitle: "Play Burst Sound Effects", target: nil, action: nil)
            sndChk.state = owner.draft.fireworksConfig.soundEnabled ? .on : .off
            [skyChk, sndChk].forEach { stack.addArrangedSubview($0) }
            alert.accessoryView = stack
            alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                owner.draft.fireworksConfig.showSkyline = skyChk.state == .on
                owner.draft.fireworksConfig.soundEnabled = sndChk.state == .on
                ssControlChanged()
            }
            return
        case .snowfall:
            let blizChk = NSButton(checkboxWithTitle: "Blizzard Intensity Mode", target: nil, action: nil)
            blizChk.state = owner.draft.snowfallConfig.blizzardMode ? .on : .off
            let windChk = NSButton(checkboxWithTitle: "Gusting Wind Sway", target: nil, action: nil)
            windChk.state = owner.draft.snowfallConfig.windEnabled ? .on : .off
            let accChk = NSButton(checkboxWithTitle: "Accumulate Snow Drifts Along Bottom", target: nil, action: nil)
            accChk.state = owner.draft.snowfallConfig.accumulateSnow ? .on : .off
            let sceneChk = NSButton(checkboxWithTitle: "Show Holiday Tree, Snowman & Santa", target: nil, action: nil)
            sceneChk.state = owner.draft.snowfallConfig.showTreeAndSnowman ? .on : .off
            [blizChk, windChk, accChk, sceneChk].forEach { stack.addArrangedSubview($0) }
            alert.accessoryView = stack
            alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                owner.draft.snowfallConfig.blizzardMode = blizChk.state == .on
                owner.draft.snowfallConfig.windEnabled = windChk.state == .on
                owner.draft.snowfallConfig.accumulateSnow = accChk.state == .on
                owner.draft.snowfallConfig.showTreeAndSnowman = sceneChk.state == .on
                owner.draft.snowfallConfig.showSanta = sceneChk.state == .on
                ssControlChanged()
            }
            return
        default:
            // Unified configuration modal for all 20 Seasonal Screen Savers & Wallpaper Slideshow
            let speedSlider = NSSlider(value: owner.draft.seasonalSSConfig.speed, minValue: 0.3, maxValue: 2.5, target: nil, action: nil)
            let densSlider = NSSlider(value: owner.draft.seasonalSSConfig.density, minValue: 0.3, maxValue: 2.0, target: nil, action: nil)
            let brtSlider = NSSlider(value: owner.draft.seasonalSSConfig.brightness, minValue: 0.3, maxValue: 1.0, target: nil, action: nil)
            let windPop = NSPopUpButton()
            windPop.addItems(withTitles: AutumnLeavesWind.allCases.map(\.displayName))
            windPop.selectItem(at: owner.draft.seasonalSSConfig.windCondition.rawValue)
            let bgPop = NSPopUpButton()
            bgPop.addItems(withTitles: AutumnLeavesBackground.allCases.map(\.displayName))
            bgPop.selectItem(at: owner.draft.seasonalSSConfig.leavesBackground.rawValue)
            let countdownChk = NSButton(checkboxWithTitle: "Show Midnight New Year's Countdown", target: nil, action: nil)
            countdownChk.state = owner.draft.seasonalSSConfig.showMidnightCountdown ? .on : .off
            let rmChk = NSButton(checkboxWithTitle: "Reduce Motion", target: nil, action: nil)
            rmChk.state = owner.draft.seasonalSSConfig.reduceMotion ? .on : .off

            let sLbl = NSTextField(labelWithString: "Speed / Density / Brightness:")
            stack.addArrangedSubview(sLbl)
            stack.addArrangedSubview(speedSlider)
            stack.addArrangedSubview(densSlider)
            stack.addArrangedSubview(brtSlider)
            if mod == .fallingAutumnLeaves || mod == .autumnForest {
                stack.addArrangedSubview(windPop)
                stack.addArrangedSubview(bgPop)
            }
            if mod == .newYearsCelebration {
                stack.addArrangedSubview(countdownChk)
            }
            stack.addArrangedSubview(rmChk)
            alert.accessoryView = stack
            alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                owner.draft.seasonalSSConfig.speed = speedSlider.doubleValue
                owner.draft.seasonalSSConfig.density = densSlider.doubleValue
                owner.draft.seasonalSSConfig.brightness = brtSlider.doubleValue
                owner.draft.seasonalSSConfig.windCondition = AutumnLeavesWind(rawValue: max(0, windPop.indexOfSelectedItem)) ?? .breezy
                owner.draft.seasonalSSConfig.leavesBackground = AutumnLeavesBackground(rawValue: max(0, bgPop.indexOfSelectedItem)) ?? .twilightSunset
                owner.draft.seasonalSSConfig.showMidnightCountdown = countdownChk.state == .on
                owner.draft.seasonalSSConfig.reduceMotion = rmChk.state == .on
                ssControlChanged()
            }
            return
        }
    }

    @objc private func wpCategoryChanged() {
        refreshWallpaperDropdown(selectedID: owner.draft.activeWallpaperID)
    }

    @objc private func toggleFavoriteWallpaper() {
        guard let selID = wallpaperPopup.selectedItem?.representedObject as? String else { return }
        var favs = owner.draft.favoriteWallpaperIDs
        if let idx = favs.firstIndex(of: selID) { favs.remove(at: idx) } else { favs.append(selID) }
        owner.draft.favoriteWallpaperIDs = favs
        refreshWallpaperDropdown(selectedID: selID)
    }

    @objc private func testScreenSaver() {
        owner.applyPressed()
        owner.onStartScreenSaverNow?()
    }

    @objc private func wallpaperSelectionChanged() {
        commitFieldsIntoDraft()
        updateWallpaperPreview()
    }

    @objc private func applyWallpaperNow() {
        commitFieldsIntoDraft()
        let mIdx = wpMonitorPopup.indexOfSelectedItem
        let targetScreen: NSScreen? = (mIdx >= 1 && mIdx - 1 < NSScreen.screens.count) ? NSScreen.screens[mIdx - 1] : nil
        _ = WallpaperService.shared.applyWallpaper(id: owner.draft.activeWallpaperID, style: owner.draft.wallpaperType, screen: targetScreen)
        AudioEngineService.shared.playEffect(.celebrate, enabled: owner.draft.soundFX)
    }

    @objc private func importWallpapers() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for u in panel.urls {
                let d = WallpaperService.importedWallpaperDir.appendingPathComponent(u.lastPathComponent)
                try? FileManager.default.removeItem(at: d)
                try? FileManager.default.copyItem(at: u, to: d)
            }
            WallpaperService.shared.reloadList()
            refreshWallpaperDropdown(selectedID: owner.draft.activeWallpaperID)
        }
    }

    @objc private func calendarChanged() { updateCountdownPreview() }
    @objc private func openCalendarModal() { owner.onOpenCalendarViewer?() }
    @objc private func openAdventModal() { owner.onOpenAdventCalendar?() }

    @objc private func openAppSupportFolder() {
        let dir = BulbArtworkRegistry.importedBulbsDirectory.deletingLastPathComponent()
        NSWorkspace.shared.open(dir)
    }
}
