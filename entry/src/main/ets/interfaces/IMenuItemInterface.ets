export interface IMenuItem {
  key?: string
  icon: Resource
  content: ResourceStr
  shortcut?: string
  onAction?: () => void
}
