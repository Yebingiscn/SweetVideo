@ObservedV2
export class SideBarController {
  @Trace mode: SideBarContainerType = SideBarContainerType.Embed
  @Trace visibility: Visibility = Visibility.Hidden
  @Trace overlay: boolean = false
  @Trace isShow: boolean = false


  public open() {
    this.visibility = Visibility.Visible
    this.isShow = true
    if (this.mode === SideBarContainerType.Overlay) {
      this.overlay = true
    }
  }

  public close(isPlayAnimation: boolean) {
    this.visibility = Visibility.Hidden
    if (this.mode === SideBarContainerType.Overlay) {
      isPlayAnimation ? setTimeout(() => {
        this.isShow = false
        this.overlay = false
      }, 200) : this.isShow = false
    } else {
      this.isShow = false
    }
    this.overlay = false
  }

  public closeIfOverlay(isPlayAnimation: boolean) {
    if (this.mode === SideBarContainerType.Overlay) {
      this.close(isPlayAnimation)
    }
  }
}