import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { VideoView } from '../VideoItemComponent/VideoViewComponent'
import { ImportProgressBuilder } from '../VideoItemComponent/ImportProgressBuilder'
import { SideBarController } from '../SideBarComponent/SideBar'
import { Setting } from '../../utils/ObservedUtil'

/**
 * 主内容区组件
 * 包含 VideoView、导入进度遮罩
 */
@Component
export struct MainContentBuilder {
  @Link loading: boolean
  @Prop processedItems: number
  @Prop totalItems: number
  @Link videoListController: VideoListController
  @Link sideBarController: SideBarController
  @Link searchValue: string

  build() {
    Stack() {
      VideoView({
        loading: this.loading,
        searchValue: this.searchValue,
        videoListController: this.videoListController
      })
      .scale({
        x: this.sideBarController.isShow === true ? 0.95 : 1,
        y: this.sideBarController.isShow ? 0.95 : 1
      })
      .animation({ duration: 300, curve: Curve.Ease })

      if (this.loading) {
        ImportProgressBuilder({
          processedItems: this.processedItems,
          totalItems: this.totalItems
        })
      }
    }
    .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.start_window_background'))
  }
}
