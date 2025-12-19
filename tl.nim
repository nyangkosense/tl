# tl - tinylauncher
#
# see LICENSE for copyright and license details.
# 
# (c) 2025 sebastian michalk <sebastian.michalk@pm.me>

import posix
import x11/x
import x11/xlib
import x11/xutil
import x11/keysym
import x11/xft
import x11/xrender

# compile-time conf
const
  barH: cint = 56
  fontName = "monospace:size=18"
  prompt = "launch: "
  maxLen = 256

  colBg  = 0xFFFFFF'u32    # white
  colFg  = 0x000000'u32    # black
  colSel = 0xDD6666'u32    # highlight

type
  App = object
    d: PDisplay
    win: Window
    gc: GC
    xftd: PXftDraw
    xftFont: PXftFont
    colFgXft: XftColor
    colSelXft: XftColor
    buf: array[maxLen, char]
    len: int

proc die(msg: string) {.noreturn.} =
  stderr.writeLine msg
  quit(1)

proc draw(app: var App) =
  discard XClearWindow(app.d, app.win)
  discard XSetForeground(app.d, app.gc, colBg)
  let screen = DefaultScreen(app.d)
  discard XFillRectangle(app.d, app.win, app.gc, 0, 0, cuint(DisplayWidth(app.d, screen)), cuint(barH))
  let baseline = barH div 2 + app.xftFont.ascent div 2

  var pExt, iExt: XGlyphInfo
  XftTextExtentsUtf8(app.d, app.xftFont, cast[PFcChar8](prompt.cstring), prompt.len.cint, addr pExt)
  XftTextExtentsUtf8(app.d, app.xftFont, cast[PFcChar8](addr app.buf[0]), app.len.cint, addr iExt)

  XftDrawStringUtf8(app.xftd, addr app.colSelXft, app.xftFont, cint(8), cint(baseline), cast[PFcChar8](prompt.cstring), prompt.len.cint)
  XftDrawStringUtf8(app.xftd, addr app.colFgXft, app.xftFont, cint(8 + pExt.xOff), cint(baseline), cast[PFcChar8](addr app.buf[0]), app.len.cint)
  discard XFlush(app.d)

proc spawn(cmd: cstring) =
  let pid = fork()
  if pid < 0: die("fork failed")
  if pid == 0:
    discard setsid()
    let args = allocCStringArray(@[$cmd])
    discard execvp(cmd, args)
    quit(1)

proc handleKey(app: var App, e: var XKeyEvent) =
  var keybuf: array[32, char]
  var keysym: KeySym = 0
  let n = XLookupString(addr e, cast[cstring](addr keybuf[0]), keybuf.len.cint, addr keysym, nil)

  case keysym
  of XK_Return:
    if app.len > 0:
      app.buf[app.len] = '\0'
      spawn(cast[cstring](addr app.buf[0]))
      quit(0)
  of XK_Escape:
    quit(0)
  of XK_BackSpace:
    if app.len > 0: app.len.dec
  else:
    if n > 0 and app.len + n < maxLen:
      for i in 0 ..< n:
        app.buf[app.len + i] = keybuf[i]
      app.len += n

proc setFloatingHints(app: var App) =
  let atomWindowType = XInternAtom(app.d, "_NET_WM_WINDOW_TYPE".cstring, XBool(0))
  let atomDialog = XInternAtom(app.d, "_NET_WM_WINDOW_TYPE_DIALOG".cstring, XBool(0))
  let atomAtom = XInternAtom(app.d, "ATOM".cstring, XBool(0))
  if atomWindowType != 0 and atomDialog != 0 and atomAtom != 0:
    var types = [atomDialog]
    discard XChangeProperty(app.d, app.win, atomWindowType, atomAtom, 32, PropModeReplace, cast[cstring](addr types[0]), types.len.cint)

  let atomState = XInternAtom(app.d, "_NET_WM_STATE".cstring, XBool(0))
  let atomAbove = XInternAtom(app.d, "_NET_WM_STATE_ABOVE".cstring, XBool(0))
  let atomSticky = XInternAtom(app.d, "_NET_WM_STATE_STICKY".cstring, XBool(0))
  var states: array[2, Atom]
  var count = 0
  if atomAbove != 0:
    states[count] = atomAbove
    inc count
  if atomSticky != 0:
    states[count] = atomSticky
    inc count
  if atomState != 0 and atomAtom != 0 and count > 0:
    discard XChangeProperty(app.d, app.win, atomState, atomAtom, 32, PropModeReplace, cast[cstring](addr states[0]), count.cint)

proc main() =
  var app: App
  app.d = XOpenDisplay(nil)
  if app.d.isNil: die("cannot open display")

  let screen = DefaultScreen(app.d)
  let sw = DisplayWidth(app.d, screen)
  let sh = DisplayHeight(app.d, screen)

  let w: cuint = cuint(sw div 4)
  let h: cuint = cuint(barH)
  let x: cint = cint((sw - cint(w)) div 2)
  let y: cint = cint((sh - cint(h)) div 2)

  app.win = XCreateSimpleWindow(app.d, RootWindow(app.d, screen), x, y, w, h, 0, colFg, colBg)
  discard XSelectInput(app.d, app.win, ExposureMask or KeyPressMask)
  discard XStoreName(app.d, app.win, "zmen-nim")
  setFloatingHints(app)
  discard XMapWindow(app.d, app.win)

  app.gc = XCreateGC(app.d, app.win, 0, nil)
  let cmap = DefaultColormap(app.d, screen)
  app.xftFont = XftFontOpenName(app.d, screen, fontName.cstring)
  if app.xftFont.isNil: die("failed to load xft font")
  if XftColorAllocName(app.d, DefaultVisual(app.d, screen), cmap, "#000000".cstring, addr app.colFgXft) == 0:
    die("failed to alloc fg color")
  if XftColorAllocName(app.d, DefaultVisual(app.d, screen), cmap, "#dd6666".cstring, addr app.colSelXft) == 0:
    die("failed to alloc sel color")
  app.xftd = XftDrawCreate(app.d, app.win, DefaultVisual(app.d, screen), cmap)
  if app.xftd.isNil: die("failed to create xft draw")

  while true:
    var ev: XEvent
    discard XNextEvent(app.d, addr ev)
    case ev.theType
    of Expose:
      draw(app)
    of KeyPress:
      var ke = cast[PXKeyEvent](addr ev)
      handleKey(app, ke[])
      draw(app)
    else:
      discard

  discard XCloseDisplay(app.d)

when isMainModule:
  main()
