export interface IMenuItem {
  icon: Resource
  content: ResourceStr
  shortcut?: string
  onAction?: () => void
}
