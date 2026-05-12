@ObservedV2
export class SideBarController {
  @Trace mode: SideBarContainerType = SideBarContainerType.Embed
  @Trace visibility: Visibility = Visibility.Hidden
  @Trace overlay: boolean = false
  @Trace isShow: boolean = false

  public open() {
    if (this.mode === SideBarContainerType.Overlay) {
      this.visibility = Visibility.Visible
      this.overlay = true
      this.isShow = true
    }
    if (this.visibility == Visibility.Hidden) {
      this.overlay = false
    }
  }

  public close(isPlayAnimation: boolean) {
    if (this.mode === SideBarContainerType.Overlay) {
      this.visibility = Visibility.Hidden
      isPlayAnimation ? setTimeout(() => {
        this.isShow = false
        this.overlay = false
      }, 200) : this.isShow = false
    }
    this.overlay = false
  }
}