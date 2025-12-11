export interface IMenuItem {
  icon: Resource
  content: ResourceStr
  onAction?: () => void
}