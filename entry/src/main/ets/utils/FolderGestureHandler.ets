import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import { SideBarController } from '../component/SideBarComponent/SideBar'
import { FileFolderDataSource } from '../utils/DataUtil'
import FileFolderUtil from '../utils/FileFolderUtil'
import { PathUtils } from '../utils/PathUtils'
import SelectFileUtil from '../utils/SelectFileUtil'
import { Setting } from '../utils/ObservedUtil'
import VideoUtils from '../utils/VideoUtil'

/**
 * 文件夹滑动手势处理器
 * 处理侧边栏展开/收起和文件夹间切换的滑动手势
 */
export class FolderGestureHandler {
  private file_folder_list: FileFolder[]
  private videoListController: VideoListController
  private sideBarController: SideBarController
  private fileFolderSource: FileFolderDataSource
  private onFolderSwitch: (folder: FileFolder, index: number) => void
  private onSideBarScroll: (offset: number) => void

  constructor(
    file_folder_list: FileFolder[],
    videoListController: VideoListController,
    sideBarController: SideBarController,
    fileFolderSource: FileFolderDataSource,
    onFolderSwitch: (folder: FileFolder, index: number) => void,
    onSideBarScroll: (offset: number) => void
  ) {
    this.file_folder_list = file_folder_list
    this.videoListController = videoListController
    this.sideBarController = sideBarController
    this.fileFolderSource = fileFolderSource
    this.onFolderSwitch = onFolderSwitch
    this.onSideBarScroll = onSideBarScroll
  }

  /**
   * 更新文件夹列表引用
   */
  updateFolderList(folders: FileFolder[]): void {
    this.file_folder_list = folders
  }

  /**
   * 处理滑动手势
   */
  handleSwipe(event: GestureEvent): void {
    // 批量选择模式下禁止切换
    if (this.videoListController.multipleChooseState === Visibility.Visible) {
      return
    }

    // 侧边栏展开时（Overlay 模式）：左滑关闭侧边栏
    if (this.sideBarController.visibility === Visibility.Visible &&
      this.sideBarController.mode === SideBarContainerType.Overlay) {
      const rotateAngle = event.angle ?? 0
      if (rotateAngle < -135 || rotateAngle > 135) {
        this.sideBarController.close(true)
      }
      return
    }

    const rotateAngle = event.angle ?? 0
    const isSwipeRight = rotateAngle > -45 && rotateAngle < 45
    const isSwipeLeft = rotateAngle < -135 || rotateAngle > 135

    // 面包屑未开启时：只允许右滑打开侧边栏（仅 Overlay 模式）
    if (!Setting.showToast) {
      if (isSwipeRight && this.sideBarController.mode === SideBarContainerType.Overlay) {
        this.sideBarController.open()
      }
      return
    }

    // 文件夹列表为空或只有一个时：右滑打开侧边栏（仅 Overlay 模式）
    if (this.file_folder_list.length <= 1) {
      if (isSwipeRight && this.sideBarController.mode === SideBarContainerType.Overlay) {
        this.sideBarController.open()
      }
      return
    }

    const currentIndex = this.getCurrentFolderIndex()
    if (currentIndex === -1) {
      console.error(`[FolderGestureHandler] current folder not found in list`)
      return
    }

    const isFirstFolder = currentIndex === 0
    const isLastFolder = currentIndex === this.file_folder_list.length - 1

    if (isSwipeRight) {
      if (isFirstFolder) {
        // 第一个文件夹右滑 -> 打开侧边栏（仅 Overlay 模式）
        if (this.sideBarController.mode === SideBarContainerType.Overlay) {
          this.sideBarController.open()
        }
      } else {
        // 切换到上一个文件夹
        void this.switchToFolder(currentIndex - 1)
      }
    } else if (isSwipeLeft) {
      // 从右向左滑
      if (!isLastFolder) {
        void this.switchToFolder(currentIndex + 1)
      }
    }
  }

  /**
   * 获取当前文件夹在列表中的索引
   */
  getCurrentFolderIndex(): number {
    return this.file_folder_list.findIndex(
      folder => folder.date === this.videoListController?.folder?.date
    )
  }

  /**
   * 切换到指定索引的文件夹
   */
  async switchToFolder(index: number): Promise<void> {
    if (index < 0 || index >= this.file_folder_list.length) {
      return
    }

    const targetFolder = this.file_folder_list[index]
    if (this.videoListController.folder?.date === targetFolder.date) {
      return
    }

    await this.performFolderSwitch(targetFolder, index)
  }

  /**
   * 执行文件夹切换
   */
  private async performFolderSwitch(targetFolder: FileFolder, index: number): Promise<void> {
    // 刷新文件夹列表（确保数据最新）
    const updatedFolders = await FileFolderUtil.getAllFolderAsync(PathUtils.appContext!)
    this.fileFolderSource.updateData(updatedFolders)

    // 获取目标文件夹的最新数据
    const currentFolder = this.fileFolderSource.getFileFolder(targetFolder.name)
    if (currentFolder) {
      animateTo({
        duration: 200,
        curve: Curve.EaseInOut
      }, () => {
        this.videoListController.videoDataSource.updateData(currentFolder.video_list)
        this.videoListController.updateData(
          this.videoListController.videoDataSource,
          currentFolder
        )
      })
    }

    // 触发回调
    this.onFolderSwitch(targetFolder, index)

    // 计算侧边栏滚动位置并触发滚动
    const estimatedOffset = index > 0 ? 260 + (index - 1) * 70 : 0
    animateToImmediately({
      duration: 200,
      curve: Curve.Ease
    }, () => {
      this.onSideBarScroll(estimatedOffset)
    })
  }

  /**
   * 带搜索过滤的文件夹切换
   */
  async switchToFolderWithSearch(index: number, searchValue: string): Promise<void> {
    if (index < 0 || index >= this.file_folder_list.length) {
      return
    }

    const targetFolder = this.file_folder_list[index]
    if (this.videoListController.folder?.date === targetFolder.date) {
      return
    }

    // 刷新文件夹列表
    const updatedFolders = await FileFolderUtil.getAllFolderAsync(PathUtils.appContext!)
    this.fileFolderSource.updateData(updatedFolders)

    // 获取目标文件夹的最新数据
    const currentFolder = this.fileFolderSource.getFileFolder(targetFolder.name)
    if (currentFolder) {
      // 如果有搜索值，在新文件夹中过滤视频
      let filteredVideos = currentFolder.video_list
      if (searchValue.length > 0) {
        filteredVideos = SelectFileUtil.getItemFromSearch(currentFolder.video_list, searchValue)
      }
      animateTo({
        duration: 200,
        curve: Curve.EaseInOut
      }, () => {
        this.videoListController.videoDataSource.updateData(filteredVideos)
        this.videoListController.updateData(
          this.videoListController.videoDataSource,
          currentFolder
        )
      })
    }

    // 触发回调
    this.onFolderSwitch(targetFolder, index)

    // 侧边栏滚动
    const estimatedOffset = index > 0 ? 260 + (index - 1) * 70 : 0
    animateToImmediately({
      duration: 200,
      curve: Curve.Ease
    }, () => {
      this.onSideBarScroll(estimatedOffset)
    })
  }
}
