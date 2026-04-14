import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { VideoView } from '../VideoItemComponent/VideoViewComponent'
import { ImportProgressBuilder } from '../VideoItemComponent/ImportProgressBuilder'
import { SideBarController } from '../SideBarComponent/SideBar'
import { Setting } from '../../utils/ObservedUtil'

/**
 * 主内容区构建参数
 */
export interface MainContentBuilderParams {
  loading: boolean
  processedItems: number
  totalItems: number
  videoListController: VideoListController
  sideBarController: SideBarController
}

/**
 * 主内容区组件
 * 包含 VideoView、导入进度遮罩
 */
@Component
export struct MainContentBuilder {
  @ObjectLink params: MainContentBuilderParams

  build() {
    Stack() {
      VideoView({
        loading: this.params.loading,
        searchValue: '',
        videoListController: this.params.videoListController
      })
      .scale({
        x: this.params.sideBarController.isShow === true ? 0.95 : 1,
        y: this.params.sideBarController.isShow ? 0.95 : 1
      })
      .animation({ duration: 300, curve: Curve.Ease })

      if (this.params.loading) {
        ImportProgressBuilder({
          processedItems: this.params.processedItems,
          totalItems: this.params.totalItems
        })
      }
    }
    .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.start_window_background'))
  }
}
