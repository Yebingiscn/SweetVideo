export interface IMenuItem {
  key?: string
  content: ResourceStr
  shortcut?: string
  onAction?: () => void
}
