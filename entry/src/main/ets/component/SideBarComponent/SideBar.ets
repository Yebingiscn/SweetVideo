import { ImageFancyModifier } from '../../utils/AttributeModifierUtil';

@Component
export struct AppInfo {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;

  build() {
    Stack() {
      Image($r("app.media.Background"))
        .attributeModifier(new ImageFancyModifier(16, '100%', 120))
        .zIndex(1)
      Row() {
        Image($r("app.media.Foreground"))
          .attributeModifier(new ImageFancyModifier(0, 50, 50))
        Text($r('app.string.EntryAbility_label'))
          .fontSize(20)
          .fontColor('#ffff')
          .margin({ left: 5, right: 12 })
      }.width('100%')
      .justifyContent(FlexAlign.Center)
      .zIndex(2)
    }.margin({ top: this.topSafeHeight })
  }
}

@Observed
export class SideBarController {
  side_bar_mode: SideBarContainerType = SideBarContainerType.Embed
  sideBarStatusTmp: Visibility = Visibility.Hidden
  mask_state: boolean = false
  sideBarStatus: boolean = false

  public openSideBar() {
    if (this.side_bar_mode === SideBarContainerType.Overlay) {
      this.sideBarStatusTmp = Visibility.Visible
      this.mask_state = true
      this.sideBarStatus = true
    }
    if (this.sideBarStatusTmp == Visibility.Hidden) {
      this.mask_state = false
    }
  }

  public closeSideBar(isPlayAnimation: boolean) {
    if (this.side_bar_mode === SideBarContainerType.Overlay) {
      this.sideBarStatusTmp = Visibility.Hidden
      isPlayAnimation ? setTimeout(() => {
        this.sideBarStatus = false
        this.mask_state = false
      }, 200) : this.sideBarStatus = false
    }
    this.mask_state = false
  }
}