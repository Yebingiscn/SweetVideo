import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoDataSource } from '../utils/DataUtil'
import { PathUtils } from '../utils/PathUtils'
import Preferences from '../database/Preferences'
import { Setting } from '../utils/ObservedUtil'
import { ListDisplayMode } from '../common/enum/DisplayMode'
import { XAnimation } from '../utils/AnimationUtil'
import DataSyncUtil from '../utils/DataSyncUtil'

@ObservedV2
export class VideoListController {
  @Trace public folder: FileFolder
  @Trace homeReady: boolean = false
  @Trace directoryMode: boolean = false
  @Trace directoryOverview: boolean = false
  @Trace directoryTransitioning: boolean = false
  @Trace directoryTarget: string = ''
  @Trace directoryRequest: number = 0
  listScroller: ListScroller = new ListScroller()
  waterFlowScroller: ListScroller = new ListScroller()
  directoryScroller: ListScroller = new ListScroller()
  directoryWaterFlowScroller: ListScroller = new ListScroller()
  directoryOffsets: Map<string, number> = new Map()
  directoryFirstIndexes: Map<string, number> = new Map()
  @Trace videoMetaDataList: VideoMetadata[]
  @Trace multipleChooseState: Visibility = Visibility.None
  @Trace listLine: number = 1
  @Trace videoDataSource: VideoDataSource
  private listeners: DataChangeListener[] = []

  constructor(folder?: FileFolder) {
    if (folder) {
      this.folder = folder
    } else {
      this.folder = Preferences.getFileFolder(PathUtils.appContext!)[0]
    }
    this.videoMetaDataList = this.folder?.video_list || []
    this.videoDataSource = new VideoDataSource(this.videoMetaDataList)
  }

  getActiveScroller(): ListScroller {
    if (this.directoryMode) {
      return Setting.listDisplayMode === ListDisplayMode.CARD_DISPLAY ? this.directoryWaterFlowScroller :
        this.directoryScroller
    }
    return Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY ? this.listScroller : this.waterFlowScroller
  }

  setDirectoryView(enabled: boolean): void {
    if (this.directoryMode === enabled) { return }
    this.closeMultipleChoose()
    this.directoryOverview = false
    this.directoryMode = enabled
    Preferences.saveDirectoryView(PathUtils.appContext!, enabled)
  }

  requestDirectory(date: string | null): void {
    if (!this.directoryMode || this.directoryTransitioning || this.multipleChooseState === Visibility.Visible) {
      return
    }
    this.directoryTarget = date ?? ''
    this.directoryRequest++
  }

  requestDirectoryBack(): void {
    if (!this.directoryOverview) {
      this.requestDirectory(this.folder?.parent_date ?? null)
    }
  }

  openSideBarTip(searchValue: string = ''): boolean {
    // 如果有搜索值但结果为空，是搜索无结果，不显示提示
    if (searchValue.length > 0) {
      return false
    }
    // 文件夹真正为空时显示提示
    if (this.videoDataSource.totalCount() == 0) {
      return true
    }
    return false
  }

  /**
   * 检查是否是搜索无结果状态
   */
  isSearchEmpty(searchValue: string): boolean {
    // 有搜索值且结果为空
    return searchValue.length > 0 && this.videoDataSource.totalCount() == 0
  }

  // 公共方法实现
  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener)
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  updateData(videoDataSource: VideoDataSource | undefined, folder: FileFolder): void {
    this.folder = folder
    this.videoMetaDataList = folder.video_list
    if (videoDataSource) {
      this.videoDataSource.updateData(videoDataSource.getAllData())
    } else {
      this.videoDataSource.updateData(this.videoMetaDataList)
    }
    this.notifyDataReloaded()
  }

  public closeMultipleChoose() {
    XAnimation.runWithAnimation(() => {
      this.multipleChooseState = Visibility.None
    })
    DataSyncUtil.delMultipleList = []
  }

  public refresh(width: number, listDisplayMode: ListDisplayMode) {
    const base = Math.floor(Math.abs(width) / 500)
    let listLine = listDisplayMode === ListDisplayMode.LIST_DISPLAY ? base + 1 : base + 2
    this.listLine = Math.min(listLine, Setting.maxListLine)
    try {
      const scroller = this.getActiveScroller()
      if (scroller.currentOffset()?.yOffset == -90) {
        scroller.scrollEdge(Edge.Top)
      }
    } catch (_error) {
      // scroller 未绑定组件时 currentOffset 可能异常，忽略
    }
  }

  // 通知方法
  protected notifyDataReloaded(): void {
    this.listeners.forEach(listener => listener.onDataReloaded())
  }

  protected notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => listener.onDataDelete(index))
  }
}

