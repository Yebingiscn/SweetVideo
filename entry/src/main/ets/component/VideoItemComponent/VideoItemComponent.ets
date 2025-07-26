import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import VideoCardItem from './VideoCardItemComponent';
import VideoListItem from './VideoListItemComponent';
import Preferences from '../../database/Preferences';
import { FileFolderDataSource, VideoDataSource } from '../../utils/DataUtil';
import { PathUtils } from '../../utils/PathUtils';
import ToolsUtil from '../../utils/ToolsUtil';
import SelectFileUtil from '../../utils/SelectFileUtil';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import DataSyncUtil from '../../utils/DataSyncUtil';
import { VideoDetailDialog } from '../../component/Dialog//VideoDetailDialog';
import { DefaultDialogShadow } from '../../common/DefaultDialogShadow';
import { delConfirmDialog } from '../../component/Dialog/DelConfirmDialog';
import { MenuModifier } from '../../utils/AttributeModifierUtil';
import { editMetadataDialog } from '../../component/Dialog//EditMetadataDialog';
import SubtitleUtil from '../../utils/SubtitleUtil';
import { FileFolder } from '../../interfaces/FileFolderInterface';
import { SideBarController } from '../SideBarComponent/SideBar';
import { FileFolderMenu } from '../FileFolderComponent/FileFolderMenu';
import { VideoMetaDataOperator } from '../../database/VideoMetaData';
import VideoUtils from '../../utils/VideoUtil';

@Observed
export class VideoListController {
  public folder: FileFolder
  listScroller: ListScroller = new ListScroller()
  videoMetaDataList: VideoMetadata[]
  multipleChooseState: Visibility = Visibility.None
  listLine: number = 1
  videoDataSource: VideoDataSource
  private listeners: DataChangeListener[] = [];

  constructor(folder?: FileFolder) {
    if (folder) {
      this.folder = folder
    } else {
      this.folder = Preferences.getFileFolder(PathUtils.appContext!)[0]
    }
    this.videoMetaDataList = folder?.video_list || []
    this.videoDataSource = new VideoDataSource(this.videoMetaDataList)
  }

  open_side_bar_tip() {
    if (this.videoDataSource.totalCount() == 0) {
      return true
    } else {
      return false
    }
  }

  // 公共方法实现
  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
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
    this.notifyDataReloaded();
  }

  public closeMultipleChoose() {
    this.multipleChooseState = Visibility.None;
    DataSyncUtil.delMultipleList = [] // 需要进行置空，防止脏数据
  }

  public refresh(width: number, isListDisplay: boolean) {
    const base = Math.floor(width / 500);
    this.listLine = isListDisplay ? base + 1 : base + 2;
    // 增加判断，旋转时保持滚动位置不变
    if (this.listScroller.currentOffset()?.yOffset == -55) {
      this.listScroller.scrollEdge(Edge.Top)
    }
  }

  // 通知方法
  protected notifyDataReloaded(): void {
    this.listeners.forEach(listener => listener.onDataReloaded());
  }

  protected notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => listener.onDataDelete(index));
  }
}

@Component
export struct VideoList {
  @Link videoListController: VideoListController
  @Consume fileFolderSource: FileFolderDataSource
  @Consume sideBarController: SideBarController
  searchController: SearchController = new SearchController()
  @State MenuBuilderState: boolean = false
  @StorageLink('is_list_display') isListDisplay: boolean = false
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageProp('screen_width') screen_width: number = 0
  @Link delMultipleList: VideoMetadata[]
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  delConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: delConfirmDialog({
      confirm: async () => {
        try {
          await VideoMetaDataOperator.deleteItem(this.videoListController, this.fileFolderSource);
          if (DataSyncUtil.delMultipleList.length > 0) {
            this.videoListController.videoDataSource.refreshData(this.videoListController.folder);
            for (const item of DataSyncUtil.delMultipleList) {
              DataSyncUtil.editingVideo = JSON.stringify(item);
              await VideoMetaDataOperator.deleteItem(this.videoListController, this.fileFolderSource);
            }
          }
          this.videoListController.closeMultipleChoose();
        } catch (e) {
          ToolsUtil.showToast(`删除失败:${e}`)
        } finally {
          VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  editMetadataDialogController: CustomDialogController = new CustomDialogController({
    builder: editMetadataDialog({
      confirm: async (title: string | undefined) => {
        if (!title?.trim()) {
          return;
        } // 更严格的空值判断
        const editingVideo = JSON.parse(DataSyncUtil.editingVideo) as VideoMetadata;
        const targetIndex = SelectFileUtil.getItemIndex(this.videoListController.videoMetaDataList, editingVideo);
        if (targetIndex === -1) {
          return;
        }
        const titleSet = new Set(this.videoListController.videoMetaDataList.map(v => v.title));
        if (titleSet.has(title)) {
          return;
        }
        this.videoListController.videoMetaDataList[targetIndex].title = title.trim();
        this.videoListController.videoDataSource.updateData(this.videoListController.videoMetaDataList)
        Preferences.saveVideoMetaData(PathUtils.appContext!, this.videoListController.videoMetaDataList)
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  build() {
    if (this.isListDisplay) {
      List({ scroller: this.videoListController.listScroller }) {
        LazyForEach(this.videoListController.videoDataSource, (item: VideoMetadata, index: number) => { // 加载视频列表
          ListItem() {
            VideoListItem({
              item: item,
              index: index,
              delMultipleList: this.delMultipleList
            }).reuseId('list_item')
          }
          .margin({ bottom: 15 }) // 不知道动了哪里，挤在一起了，先这样改
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
          .width('100%')
          .bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress)
          .bindContextMenu(this.MenuBuilder(item), ResponseType.RightClick)
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              SwipeGesture({ direction: SwipeDirection.Horizontal })
                .onAction((event: GestureEvent) => {
                  if (event) {
                    this.sideBarController.openSideBar()
                  }
                }),
              TapGesture({ count: 1, fingers: 1 })
                .onAction(async (event: GestureEvent | undefined) => {
                  if (this.videoListController.multipleChooseState !== Visibility.Visible) {
                    await this.clickItem(item)
                    return
                  } else {
                    //已存在，标记置反
                    if (this.delMultipleList.some(video => video.uri === item.uri)) {
                      this.delMultipleList =
                        this.delMultipleList.filter(video => video.uri !== item.uri)
                    } else {
                      this.delMultipleList.push(item)
                    }
                  }
                })
            )
          )
        }, (item: VideoMetadata) => item.date + item.last_play + item.title + item.size.toString() +
        this.videoListController.folder.name)
      }
      .padding({ left: 10, right: 10 })
      .cachedCount(3)
      .contentStartOffset(this.topSafeHeight + 55)
      .contentEndOffset(this.bottomSafeHeight)
      .lanes(this.videoListController.listLine)
      .animation({ duration: 300, curve: Curve.Smooth })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
      .chainAnimation(true)
      .width('100%')
      .height('100%') // 新增高度设置
      .onTouch(() => {
        this.searchController.stopEditing()
      })
      .onAppear(() => {
        this.videoListController.listScroller.scrollEdge(Edge.Top)
      })
    } else {
      Scroll() {
        Column() {
          Blank().height(this.topSafeHeight + 55)
          WaterFlow({
            scroller: this.videoListController.listScroller,
            layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW
          }) {
            LazyForEach(this.videoListController.videoDataSource, (item: VideoMetadata, index: number) => {
              FlowItem() {
                VideoCardItem({
                  item: item,
                  index: index,
                  delMultipleList: this.delMultipleList
                }).width('100%').reuseId('card_item')
              }
              .width('100%')
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
              .bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress)
              .bindContextMenu(this.MenuBuilder(item), ResponseType.RightClick)
              .gesture(
                GestureGroup(GestureMode.Exclusive,
                  SwipeGesture({ direction: SwipeDirection.Horizontal })
                    .onAction((event: GestureEvent) => {
                      if (event) {
                        this.sideBarController.openSideBar()
                      }
                    }),
                  TapGesture({ count: 1, fingers: 1 })
                    .onAction(async (event: GestureEvent | undefined) => {
                      if (this.videoListController.multipleChooseState !== Visibility.Visible) {
                        await this.clickItem(item)
                        return
                      } else {
                        //已存在，标记置反
                        if (this.delMultipleList.some(video => video.uri === item.uri)) {
                          this.delMultipleList =
                            this.delMultipleList.filter(video => video.uri !== item.uri)
                        } else {
                          this.delMultipleList.push(item)
                        }
                      }
                    })
                )
              )
            }, (item: VideoMetadata) => item.date + item.last_play + item.title + item.size.toString() +
            this.videoListController.folder.name)
          }
          .columnsTemplate('1fr '.repeat(this.videoListController.listLine).trim())
          .columnsGap(12) // 列间距
          .rowsGap(16) // 行间距
          .cachedCount(6)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .onTouch(() => this.searchController.stopEditing())
          .width('100%')
          .height('100%')
          .padding(10)
          .onAppear(() => {
            this.videoListController.listScroller.scrollEdge(Edge.Top)
          })
          .nestedScroll({
            scrollForward: NestedScrollMode.PARENT_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
        }
      }.scrollBar(BarState.Off)
    }
  }

  async clickItem(item: VideoMetadata) {
    if (!this.videoListController.videoDataSource.getAllData().some(i => i.date == item?.date!)) {
      ToolsUtil.showToast('数据正在加载中，请重试')
      this.videoListController.videoDataSource.refreshData(this.videoListController.folder)
      return
    }
    if (this.MenuBuilderState || this.videoListController.multipleChooseState != Visibility.None) {
      this.MenuBuilderState = false
      return
    }
    this.videoListController.listScroller.closeAllSwipeActions()
    await ToolsUtil.isFileExist(item) ?
    ToolsUtil.routerWhere(this.pathStack, 'Player', item, this.videoListController.videoMetaDataList) :
      await this.videoListController.videoDataSource.deleteUnExistFile(item, this.videoListController,
        this.fileFolderSource)
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          let target_item = SelectFileUtil.getItem(this.videoListController.videoMetaDataList, item?.date!)
          if (!this.videoListController.videoMetaDataList.find(i => i.date == item?.date!)) {
            ToolsUtil.showToast('数据正在加载中，请重试')
            this.videoListController.videoDataSource.refreshData(this.videoListController.folder)
            return
          }
          await ToolsUtil.isFileExist(target_item) ?
          ToolsUtil.routerWhere(this.pathStack, 'FFMpegPlayer', item!, this.videoListController.videoMetaDataList) :
            await this.videoListController.videoDataSource.deleteUnExistFile(item, this.videoListController,
              this.fileFolderSource)
        }, 200)
      })
      MenuItem({ startIcon: $r("app.media.RedPlayer"), content: '红薯播放器' }).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          let target_item = SelectFileUtil.getItem(this.videoListController.videoMetaDataList, item?.date!)
          if (!this.videoListController.videoMetaDataList.find(i => i.date == item?.date!)) {
            ToolsUtil.showToast('数据正在加载中，请重试')
            this.videoListController.videoDataSource.refreshData(this.videoListController.folder)
            return
          }
          await ToolsUtil.isFileExist(target_item) ?
          ToolsUtil.routerWhere(this.pathStack, 'RedPlayer', item!, this.videoListController.videoMetaDataList) :
            await this.videoListController.videoDataSource.deleteUnExistFile(item, this.videoListController,
              this.fileFolderSource)
        }, 200)
      })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
        .onClick(() => {
          DataSyncUtil.editingVideo = JSON.stringify(item)
          this.VideoDetailDialog.open()
        })
      // TODO 调整文件夹转移
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: "添加到文件夹",
        builder: (): void => this.FileFolderMenuBuilder(item)
      })
      // TODO  调整删除的方法
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(() => {
          // 将这个item传递给editingVideo
          DataSyncUtil.editingVideo = JSON.stringify(item)
          this.delConfirmDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.checkmark_square_on_square')),
        content: $r('app.string.multiple_choice')
      })
        .onClick(() => {
          this.videoListController.multipleChooseState =
            this.videoListController.multipleChooseState == Visibility.None ? Visibility.Visible : Visibility.None
          DataSyncUtil.delMultipleList.length = 0
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.line_3_horizontal')),
        content: '更多',
        builder: (): void => this.MenuBuilderExtend(item)
      })
    }.attributeModifier(new MenuModifier()).onAppear(() => {
      ToolsUtil.startVibration()
      this.MenuBuilderState = true
    }).onDisAppear(() => {
      this.MenuBuilderState = false
    })
  }

  @Builder
  MenuBuilderExtend(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')), content: $r('app.string.edit')
      })
        .onClick(() => {
          DataSyncUtil.editingVideo = JSON.stringify(item)
          this.editMetadataDialogController.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat_size_square')), content: '导入或删除字幕'
      })
        .onClick(async () => {
          await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath, item?.date!) ?
          SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item?.date!) :
          SubtitleUtil.selectExternalSubtitles(PathUtils.subtitlePath, item?.date!)
        })
    }
  }

  @Builder
  FileFolderMenuBuilder(video_item: VideoMetadata | undefined) {
    FileFolderMenu({ video_item: video_item })
  }
}