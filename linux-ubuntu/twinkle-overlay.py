#!/usr/bin/env python3
"""
Re: Twinkle Bulbs Version 7: Next Generation — Ubuntu GTK3/Cairo Desktop Overlay & Control Panel
Restored out of love for the original program — All credit to Don Metzler & Barefoot Productions (Freeware)
"""
import argparse
import json
import math
import threading
import time
import urllib.request
import webbrowser

import cairo
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk


class ApiClient:
    def __init__(self, base_url: str, pin: str):
        self.base_url = base_url.rstrip("/")
        self.pin = pin

    def _headers(self):
        return {"X-Twinkle-PIN": self.pin, "Content-Type": "application/json"}

    def get_json(self, path: str):
        req = urllib.request.Request(self.base_url + path, headers=self._headers())
        with urllib.request.urlopen(req, timeout=1.5) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def get_text(self, path: str):
        req = urllib.request.Request(self.base_url + path, headers=self._headers())
        with urllib.request.urlopen(req, timeout=2.0) as resp:
            return resp.read().decode("utf-8")

    def post_json(self, path: str, payload: dict):
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            self.base_url + path, data=data, headers=self._headers(), method="POST"
        )
        with urllib.request.urlopen(req, timeout=1.5) as resp:
            return json.loads(resp.read().decode("utf-8"))


class ControlWindow(Gtk.Window):
    def __init__(self, api: ApiClient, catalog: dict, docs_text: str):
        super().__init__(title="Re: Twinkle Bulbs — Version 7: Next Generation")
        self.api = api
        self.set_default_size(720, 520)
        self.set_position(Gtk.WindowPosition.CENTER)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        vbox.set_border_width(10)
        self.add(vbox)

        hdr = Gtk.Label()
        hdr.set_markup(
            "<b>Re: Twinkle Bulbs v7.0.0</b> — Restored for Ubuntu Linux "
            "<small>(Tribute to Don Metzler &amp; Barefoot Productions • Freeware)</small>"
        )
        hdr.set_xalign(0)
        vbox.pack_start(hdr, False, False, 0)

        nb = Gtk.Notebook()
        vbox.pack_start(nb, True, True, 0)

        # Tab 1: Lights & Effects
        t1 = Gtk.Grid(column_spacing=10, row_spacing=8)
        t1.set_border_width(10)

        mode_combo = Gtk.ComboBoxText()
        mode_combo.append_text("Classic v6.0 Authentic Engine")
        mode_combo.append_text("Modern 60fps Shader Engine")
        mode_combo.set_active(0)
        mode_combo.connect("changed", lambda w: self._ctrl({"classicMode": w.get_active() == 0}))
        t1.attach(Gtk.Label(label="Engine Mode:", xalign=0), 0, 0, 1, 1)
        t1.attach(mode_combo, 1, 0, 1, 1)

        flash_combo = Gtk.ComboBoxText()
        for name in catalog.get("flashModes", []):
            flash_combo.append_text(name)
        flash_combo.set_active(3)
        flash_combo.connect("changed", lambda w: self._ctrl({"classicMode": True, "flashMode": w.get_active()}))
        t1.attach(Gtk.Label(label="Classic Flash Mode:", xalign=0), 0, 1, 1, 1)
        t1.attach(flash_combo, 1, 1, 1, 1)

        eff_combo = Gtk.ComboBoxText()
        for name in catalog.get("modernEffects", []):
            eff_combo.append_text(name)
        eff_combo.set_active(0)
        eff_combo.connect("changed", lambda w: self._ctrl({"classicMode": False, "modernEffect": w.get_active()}))
        t1.attach(Gtk.Label(label="Modern 60fps Effect:", xalign=0), 0, 2, 1, 1)
        t1.attach(eff_combo, 1, 2, 1, 1)

        place_combo = Gtk.ComboBoxText()
        for name in catalog.get("placements", []):
            place_combo.append_text(name)
        place_combo.set_active(0)
        place_combo.connect("changed", lambda w: self._ctrl({"placement": w.get_active()}))
        t1.attach(Gtk.Label(label="Edge Placement:", xalign=0), 0, 3, 1, 1)
        t1.attach(place_combo, 1, 3, 1, 1)

        btn_row = Gtk.Box(spacing=8)
        b_blackout = Gtk.Button(label="Safe Blackout")
        b_blackout.connect("clicked", lambda _: self._post("/v1/blackout", {"blackout": True}))
        b_resume = Gtk.Button(label="Resume Lights")
        b_resume.connect("clicked", lambda _: self._post("/v1/blackout", {"blackout": False}))
        b_classic = Gtk.Button(label="Return to Classic")
        b_classic.connect("clicked", lambda _: self._post("/v1/scene", {"action": "classic"}))
        b_web = Gtk.Button(label="Open Full Web Command Center")
        b_web.connect("clicked", lambda _: webbrowser.open(self.api.base_url + "/remote"))
        for b in (b_resume, b_blackout, b_classic, b_web):
            btn_row.pack_start(b, True, True, 0)
        t1.attach(btn_row, 0, 4, 2, 1)
        nb.append_page(t1, Gtk.Label(label="Lighting Controls"))

        # Tab 2: Holiday Scenes & Carols
        t2 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        t2.set_border_width(10)
        sc_flow = Gtk.FlowBox()
        sc_flow.set_max_children_per_line(4)
        sc_flow.set_selection_mode(Gtk.SelectionMode.NONE)
        for sc in catalog.get("scenes", []):
            btn = Gtk.Button(label=sc["name"])
            sid = sc["id"]
            btn.connect("clicked", lambda _, s=sid: self._post("/v1/scene", {"action": "activate", "sceneId": s}))
            sc_flow.add(btn)
        sw_sc = Gtk.ScrolledWindow()
        sw_sc.add(sc_flow)
        t2.pack_start(sw_sc, True, True, 0)

        m_row = Gtk.Box(spacing=8)
        b_play = Gtk.Button(label="Play Holiday Carol")
        b_play.connect("clicked", lambda _: self._ctrl({"musicPlaying": True}))
        b_stop = Gtk.Button(label="Stop Music")
        b_stop.connect("clicked", lambda _: self._ctrl({"musicPlaying": False}))
        m_row.pack_start(b_play, False, False, 0)
        m_row.pack_start(b_stop, False, False, 0)
        t2.pack_start(m_row, False, False, 0)
        nb.append_page(t2, Gtk.Label(label="16 Holiday Scenes & Music"))

        # Tab 3: Complete History, Manual & Credits
        tv = Gtk.TextView()
        tv.set_editable(False)
        tv.set_wrap_mode(Gtk.WrapMode.WORD)
        tv.get_buffer().set_text(docs_text)
        sw_doc = Gtk.ScrolledWindow()
        sw_doc.add(tv)
        nb.append_page(sw_doc, Gtk.Label(label="History, Manual & Freeware Credits"))

        footer = Gtk.Box(spacing=8)
        quit_btn = Gtk.Button(label="Quit Re: Twinkle Bulbs")
        quit_btn.connect("clicked", lambda _: Gtk.main_quit())
        hide_btn = Gtk.Button(label="Hide Panel (Keep Bulbs On)")
        hide_btn.connect("clicked", lambda _: self.hide())
        footer.pack_end(quit_btn, False, False, 0)
        footer.pack_end(hide_btn, False, False, 0)
        vbox.pack_start(footer, False, False, 0)
        self.connect("delete-event", lambda w, e: (w.hide(), True)[1])

    def _ctrl(self, payload):
        threading.Thread(target=lambda: self._post("/v1/control", payload), daemon=True).start()

    def _post(self, path, payload):
        try:
            self.api.post_json(path, payload)
        except Exception:
            pass


class OverlayWindow(Gtk.Window):
    def __init__(self, api: ApiClient):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.api = api
        self.bulbs = []
        self.cfg = {"bulbSize": 32, "enabled": True, "blackout": False}

        display = Gdk.Display.get_default()
        mon = display.get_primary_monitor() or display.get_monitor(0)
        geom = mon.get_geometry()
        self.screen_w = geom.width
        self.screen_h = geom.height

        self.set_app_paintable(True)
        visual = self.get_screen().get_rgba_visual()
        if visual is not None:
            self.set_visual(visual)

        self.set_decorated(False)
        self.set_accept_focus(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_keep_above(True)
        self.set_default_size(self.screen_w, self.screen_h)
        self.move(geom.x, geom.y)

        self.connect("realize", self._on_realize)
        self.connect("map-event", self._make_click_through)
        self.connect("draw", self._on_draw)

        self.show_all()
        threading.Thread(target=self._poll_loop, daemon=True).start()
        GLib.timeout_add(40, self._redraw_tick)

    def _on_realize(self, *_):
        self._make_click_through()

    def _make_click_through(self, *_):
        gdk_win = self.get_window()
        if gdk_win is not None:
            gdk_win.set_pass_through(True)
            gdk_win.input_shape_combine_region(cairo.Region(), 0, 0)

    def _poll_loop(self):
        while True:
            try:
                data = self.api.get_json("/v1/status")
                self.bulbs = data.get("bulbs", [])
                self.cfg = data.get("config", self.cfg)
            except Exception:
                pass
            time.sleep(0.045)

    def _redraw_tick(self):
        self.queue_draw()
        return True

    def _on_draw(self, _widget, cr: cairo.Context):
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)

        if not self.cfg.get("enabled", True) or self.cfg.get("blackout", False):
            return False

        sz = float(self.cfg.get("bulbSize", 32))
        for b in self.bulbs:
            bx = float(b["x"])
            by = float(b["y"])
            rot = int(b.get("rot", 0))
            it = float(b.get("intensity", 0.0))
            bare = bool(b.get("bareSpacer", False))
            col = b.get("color", {"R": 240, "G": 40, "B": 40})
            r, g, bl = col["R"] / 255.0, col["G"] / 255.0, col["B"] / 255.0

            cr.save()
            cr.translate(bx + sz * 0.5, by + sz * 0.5)
            cr.rotate(math.radians(rot))
            cr.translate(-sz * 0.5, -sz * 0.5)

            # Continuous green cord wire
            cr.set_source_rgba(0.07, 0.36, 0.13, 1.0)
            cr.rectangle(0, 1, sz, max(2.0, sz * 0.09))
            cr.fill()

            if not bare:
                # Brass/Green socket
                cr.set_source_rgba(0.16, 0.46, 0.18, 1.0)
                cr.rectangle(sz * 0.38, sz * 0.09, sz * 0.24, sz * 0.16)
                cr.fill()

                # Corona glow if lit
                if it > 0.45:
                    pat = cairo.RadialGradient(sz * 0.5, sz * 0.58, sz * 0.08, sz * 0.5, sz * 0.58, sz * 0.52)
                    pat.add_color_stop_rgba(0, r, g, bl, 0.48 * it)
                    pat.add_color_stop_rgba(1, r, g, bl, 0.0)
                    cr.set_source(pat)
                    cr.arc(sz * 0.5, sz * 0.58, sz * 0.52, 0, math.tau)
                    cr.fill()

                # Bulb teardrop body
                lit = 0.22 + 0.78 * it
                cr.set_source_rgba(min(1, r * lit), min(1, g * lit), min(1, bl * lit), 0.96)
                cr.save()
                cr.translate(sz * 0.5, sz * 0.58)
                cr.scale(sz * 0.26, sz * 0.34)
                cr.arc(0, 0, 1.0, 0, math.tau)
                cr.restore()
                cr.fill()

                # Specular shine
                if it > 0.35:
                    cr.set_source_rgba(1, 1, 1, 0.48 * it)
                    cr.arc(sz * 0.42, sz * 0.46, sz * 0.08, 0, math.tau)
                    cr.fill()
            cr.restore()
        return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:19697")
    parser.add_argument("--pin", default="122570")
    parser.add_argument("--silent", action="store_true")
    args = parser.parse_args()

    api = ApiClient(args.url, args.pin)
    OverlayWindow(api)

    catalog = {}
    docs_text = ""
    for _ in range(10):
        try:
            catalog = api.get_json("/v1/catalog")
            docs_text = api.get_text("/v1/docs")
            break
        except Exception:
            time.sleep(0.15)

    ctrl = ControlWindow(api, catalog, docs_text)
    if not args.silent:
        ctrl.show_all()

    Gtk.main()


if __name__ == "__main__":
    main()
