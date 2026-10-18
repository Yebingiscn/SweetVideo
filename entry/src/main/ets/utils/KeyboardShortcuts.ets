import { KeyCode } from '@kit.InputKit'
import { ColorMetrics, CommonModifier, LengthMetrics } from '@kit.ArkUI'

export enum ShortcutAction {
  SEARCH, GLOBAL_SEARCH, IMPORT_FILES, IMPORT_FOLDERS, NEW_FOLDER, SIDEBAR, DIRECTORY,
  LIST, CARD, GRID, PARENT, BACK, SELECT_ALL, RENAME, DELETE, ESCAPE,
  PLAY_PAUSE, SEEK_BACK, SEEK_FORWARD, SEEK_BACK_SMALL, SEEK_FORWARD_SMALL,
  VOLUME_UP, VOLUME_DOWN, BRIGHTNESS_UP, BRIGHTNESS_DOWN, MUTE, FULLSCREEN, PREVIOUS, NEXT, SPEED_DOWN, SPEED_UP,
  SPEED_RESET, SUBTITLE, SUBTITLE_MENU, PLAYLIST
}

// 每个页面持有自己的实例。只处理焦点树中未被控件消费的按键，不注册后台热键。
export class KeyboardShortcuts {
  private held: Set<number> = new Set()
  private repeated: boolean = false
  private lastContinuousTime: number = 0
  private lastContinuousAction: ShortcutAction | undefined = undefined

  get heldKeyCodes(): number[] {
    return Array.from(this.held)
  }

  observe(event: KeyEvent): void {
    if (event.type === KeyType.Up) {
      this.held.delete(event.keyCode)
      return
    }
    this.repeated = this.held.has(event.keyCode)
    this.held.add(event.keyCode)
  }

  reset(): void {
    this.held.clear()
    this.repeated = false
    this.lastContinuousTime = 0
    this.lastContinuousAction = undefined
  }

  accept(action: ShortcutAction): boolean {
    const continuous = action === ShortcutAction.SEEK_BACK || action === ShortcutAction.SEEK_FORWARD ||
      action === ShortcutAction.SEEK_BACK_SMALL || action === ShortcutAction.SEEK_FORWARD_SMALL ||
      action === ShortcutAction.VOLUME_UP || action === ShortcutAction.VOLUME_DOWN ||
      action === ShortcutAction.BRIGHTNESS_UP || action === ShortcutAction.BRIGHTNESS_DOWN
    if (!continuous) return !this.repeated
    const now = Date.now()
    if (action === this.lastContinuousAction && now - this.lastContinuousTime < 80) return false
    this.lastContinuousAction = action
    this.lastContinuousTime = now
    return true
  }

  static modifiers(event: KeyEvent, ctrl: boolean = false, shift: boolean = false, alt: boolean = false): boolean {
    return !event.metaKey && (event.getModifierKeyState?.(['Ctrl']) ?? false) === ctrl &&
      (event.getModifierKeyState?.(['Shift']) ?? false) === shift &&
      (event.getModifierKeyState?.(['Alt']) ?? false) === alt
  }

  static home(event: KeyEvent): ShortcutAction | undefined {
    if (event.type !== KeyType.Down) return undefined
    if (KeyboardShortcuts.modifiers(event, true, true)) {
      switch (event.keyCode) {
        case KeyCode.KEYCODE_F: return ShortcutAction.GLOBAL_SEARCH
        case KeyCode.KEYCODE_O: return ShortcutAction.IMPORT_FOLDERS
        case KeyCode.KEYCODE_N: return ShortcutAction.NEW_FOLDER
      }
    } else if (KeyboardShortcuts.modifiers(event, true)) {
      switch (event.keyCode) {
        case KeyCode.KEYCODE_F: return ShortcutAction.SEARCH
        case KeyCode.KEYCODE_O: return ShortcutAction.IMPORT_FILES
        case KeyCode.KEYCODE_B: return ShortcutAction.SIDEBAR
        case KeyCode.KEYCODE_D: return ShortcutAction.DIRECTORY
        case KeyCode.KEYCODE_1: return ShortcutAction.LIST
        case KeyCode.KEYCODE_2: return ShortcutAction.CARD
        case KeyCode.KEYCODE_3: return ShortcutAction.GRID
        case KeyCode.KEYCODE_A: return ShortcutAction.SELECT_ALL
      }
    } else if (KeyboardShortcuts.modifiers(event, false, false, true)) {
      if (event.keyCode === KeyCode.KEYCODE_DPAD_UP) return ShortcutAction.PARENT
      if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) return ShortcutAction.BACK
    } else if (KeyboardShortcuts.modifiers(event)) {
      switch (event.keyCode) {
        case KeyCode.KEYCODE_F2: return ShortcutAction.RENAME
        case KeyCode.KEYCODE_FORWARD_DEL: return ShortcutAction.DELETE
        case KeyCode.KEYCODE_ESCAPE: return ShortcutAction.ESCAPE
      }
    }
    return undefined
  }

  static player(event: KeyEvent, surfaceFocused: boolean): ShortcutAction | undefined {
    if (event.type !== KeyType.Down) return undefined
    if (KeyboardShortcuts.modifiers(event, false, false, true) && event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) {
      return ShortcutAction.BACK
    }
    if (KeyboardShortcuts.modifiers(event, false, true)) {
      if (!surfaceFocused) return undefined
      if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) return ShortcutAction.SEEK_BACK_SMALL
      if (event.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) return ShortcutAction.SEEK_FORWARD_SMALL
      if (event.keyCode === KeyCode.KEYCODE_DPAD_UP) return ShortcutAction.BRIGHTNESS_UP
      if (event.keyCode === KeyCode.KEYCODE_DPAD_DOWN) return ShortcutAction.BRIGHTNESS_DOWN
      return undefined
    }
    if (!KeyboardShortcuts.modifiers(event)) return undefined
    switch (event.keyCode) {
      case KeyCode.KEYCODE_K: return ShortcutAction.PLAY_PAUSE
      case KeyCode.KEYCODE_SPACE: return surfaceFocused ? ShortcutAction.PLAY_PAUSE : undefined
      case KeyCode.KEYCODE_DPAD_LEFT: return surfaceFocused ? ShortcutAction.SEEK_BACK : undefined
      case KeyCode.KEYCODE_DPAD_RIGHT: return surfaceFocused ? ShortcutAction.SEEK_FORWARD : undefined
      case KeyCode.KEYCODE_DPAD_UP: return surfaceFocused ? ShortcutAction.VOLUME_UP : undefined
      case KeyCode.KEYCODE_DPAD_DOWN: return surfaceFocused ? ShortcutAction.VOLUME_DOWN : undefined
      case KeyCode.KEYCODE_M: return ShortcutAction.MUTE
      case KeyCode.KEYCODE_F:
      case KeyCode.KEYCODE_F11: return ShortcutAction.FULLSCREEN
      case KeyCode.KEYCODE_PAGE_UP: return ShortcutAction.PREVIOUS
      case KeyCode.KEYCODE_PAGE_DOWN: return ShortcutAction.NEXT
      case KeyCode.KEYCODE_LEFT_BRACKET: return ShortcutAction.SPEED_DOWN
      case KeyCode.KEYCODE_RIGHT_BRACKET: return ShortcutAction.SPEED_UP
      case KeyCode.KEYCODE_BACKSLASH: return ShortcutAction.SPEED_RESET
      case KeyCode.KEYCODE_V: return ShortcutAction.SUBTITLE
      case KeyCode.KEYCODE_T: return ShortcutAction.SUBTITLE_MENU
      case KeyCode.KEYCODE_P: return ShortcutAction.PLAYLIST
      case KeyCode.KEYCODE_ESCAPE: return ShortcutAction.ESCAPE
    }
    return undefined
  }

  static activate(event: KeyEvent): boolean {
    return event.type === KeyType.Down && KeyboardShortcuts.modifiers(event) &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_NUMPAD_ENTER ||
        event.keyCode === KeyCode.KEYCODE_SPACE || event.keyCode === KeyCode.KEYCODE_DPAD_CENTER)
  }
}

export class LibraryKeyboard extends KeyboardShortcuts {
  editing: boolean = false
  focusKind: string = ''
  focusDate: string = ''
  focusId: string = ''
  onSearch: (() => void) | undefined = undefined
  onSelectAll: (() => void) | undefined = undefined
  onDeleteVideos: (() => void) | undefined = undefined
  onVideoAction: ((action: ShortcutAction, date: string) => void) | undefined = undefined
  onFolderAction: ((action: ShortcutAction, date: string) => void) | undefined = undefined
  onImport: ((folders: boolean) => Promise<void>) | undefined = undefined
  directoryNavigation: boolean = false
  directoryFocus: Map<string, string> = new Map()

  focus(kind: string, date: string, id: string): void {
    this.editing = false
    this.focusKind = kind
    this.focusDate = date
    this.focusId = id
  }

  blur(id: string): void {
    if (this.focusId === id) this.focusKind = ''
  }
}

export class LibraryItemFocus extends CommonModifier {
  private keyboard: LibraryKeyboard
  private kind: string
  private date: string
  private activateItem: () => void

  constructor(keyboard: LibraryKeyboard, kind: string, date: string, activateItem: () => void) {
    super()
    this.keyboard = keyboard
    this.kind = kind
    this.date = date
    this.activateItem = activateItem
  }

  applyNormalAttribute(attr: CommonAttribute): void {
    const id = `home-${this.kind}:${this.date}`
    attr.id(id).focusable(true).focusOnTouch(true)
      .focusBox({ strokeColor: ColorMetrics.resourceColor($r('app.color.main_color')),
        strokeWidth: LengthMetrics.vp(2), margin: LengthMetrics.vp(2) })
      .onFocus(() => this.keyboard.focus(this.kind, this.date, id))
      .onBlur(() => this.keyboard.blur(id))
      .onKeyEvent((event: KeyEvent): boolean => {
        if (!KeyboardShortcuts.activate(event)) return false
        if (this.keyboard.accept(ShortcutAction.PLAY_PAUSE)) this.activateItem()
        return true
      })
  }
}
