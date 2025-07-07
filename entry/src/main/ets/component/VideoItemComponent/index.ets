import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import VideoCardItem from './VideoCardItemComponent'
import VideoListItem from './VideoListItemComponent'
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
import FileFolderUtil from '../../utils/FileFolderUtil';
import { SideBarController } from '../SideBarComponent/SideBar';
import { FileFolderMenu } from '../FileFolderComponent/FileFolderMenu';


@Component
export struct VideoItem {
  @Prop item: VideoMetadata
  @Prop index: number
  @StorageLink('is_list_display') isListDisplay: boolean = false
  videoListController: VideoListController = new VideoListController([])

  build() {
    Row() {
      if (this.isListDisplay) {
        VideoListItem({
          item: this.item,
          index: this.index,
          videoListController: this.videoListController
        })
      } else {
        VideoCardItem({
          item: this.item,
          index: this.index,
          videoListController: this.videoListController
        })
      }
    }
    .padding(10)
  }
}

@Observed
export class VideoListController {
  listScroller: ListScroller = new ListScroller()
  videoMetaDataList: VideoMetadata[]
  multipleChooseState: Visibility = Visibility.None
  itemMultipleChoose: boolean = false
  listLine: number = 1
  videoDataSource: VideoDataSource
  private listeners: DataChangeListener[] = [];

  constructor(videoMetaDataList: VideoMetadata[]) {
    this.videoMetaDataList = videoMetaDataList
    this.videoDataSource = new VideoDataSource(this.videoMetaDataList)
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

  // 通知方法
  protected notifyDataReloaded(): void {
    this.listeners.forEach(listener => listener.onDataReloaded());
  }

  protected notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => listener.onDataDelete(index));
  }

  updateData(videoDataSource: VideoDataSource): void {
    this.videoDataSource = videoDataSource;
    this.videoMetaDataList = this.videoDataSource.getAllData()
    this.notifyDataReloaded();
  }

  public closeMultipleChoose() {
    this.itemMultipleChoose = false;
    this.multipleChooseState = Visibility.None;
  }

  public refresh(width: number, isListDisplay: boolean) {
    const base = Math.floor(width / 500);
    this.listLine = isListDisplay ? base + 1 : base + 2;
    // 增加判断，旋转时保持滚动位置不变
    if (this.listScroller.currentOffset().yOffset == -55) {
      this.listScroller.scrollEdge(Edge.Top)
    }
  }
}

@Component
export struct VideoList {
  @ObjectLink videoListController: VideoListController
  @ObjectLink fileFolderSource: FileFolderDataSource

  sideBarController: SideBarController = new SideBarController()
  searchController: SearchController = new SearchController()
  @State MenuBuilderState: boolean = false
  @State file_folder_list: FileFolder[] = []
  @StorageLink('is_list_display') isListDisplay: boolean = false
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageProp('screen_width') screen_width: number = 0
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  delConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: delConfirmDialog({
      confirm: async (confirm_del: boolean | undefined) => {
        if (!confirm_del) {
          return
        }
        await new Promise<void>((resolve, reject) => {
          this.videoListController.videoDataSource.deleteItem(resolve, reject);
        });
        if (DataSyncUtil.delMultipleList.length > 0) {
          this.videoListController.videoDataSource.refreshData()
          const deletePromises = DataSyncUtil.delMultipleList.map(item => {
            return new Promise<void>((resolve, reject) => {
              DataSyncUtil.editing_video = JSON.stringify(item);
              this.videoListController.videoDataSource.deleteItem(resolve, reject);
              this.videoListController.closeMultipleChoose!()
            });
          });
          await Promise.all(deletePromises);
        } else {
          this.videoListController.closeMultipleChoose!()
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
        const editingVideo = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata;
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
    List({ scroller: this.videoListController.listScroller }) {
      LazyForEach(this.videoListController.videoDataSource, (item: VideoMetadata, index: number) => { // 加载视频列表
        ListItem() {
          VideoItem({
            item: item,
            index: index,
            videoListController: this.videoListController
          })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
        .width('100%')
        .bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress)
        .swipeAction({
          start: this.itemStart(),
          edgeEffect: SwipeEdgeEffect.Spring
        })
        .onClick(async () => {
          if (!this.videoListController.videoMetaDataList.some(i => i.date == item?.date!)) {
            ToolsUtil.showToast('数据正在加载中，请重试')
            this.videoListController.videoDataSource.refreshData()
            return
          }
          if (this.MenuBuilderState || this.videoListController.multipleChooseState != Visibility.None) {
            this.MenuBuilderState = false
            return
          }
          this.videoListController.listScroller.closeAllSwipeActions()
          await ToolsUtil.isFileExist(item) ?
          ToolsUtil.routerWhere(this.pathStack, 'Player', item, this.videoListController.videoMetaDataList) :
          this.videoListController.videoDataSource.deleteUnExistFile(item)
        })
      }, (item: VideoMetadata) => JSON.stringify(item))
    }
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
            this.videoListController.videoDataSource.refreshData()
            return
          }
          await ToolsUtil.isFileExist(target_item) ?
          ToolsUtil.routerWhere(this.pathStack, 'FFMpegPlayer', item!, this.videoListController.videoMetaDataList) :
          this.videoListController.videoDataSource.deleteUnExistFile(target_item)
        }, 200)
      })
      MenuItem({ startIcon: $r("app.media.RedPlayer"), content: '红薯播放器' }).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          let target_item = SelectFileUtil.getItem(this.videoListController.videoMetaDataList, item?.date!)
          if (!this.videoListController.videoMetaDataList.find(i => i.date == item?.date!)) {
            ToolsUtil.showToast('数据正在加载中，请重试')
            this.videoListController.videoDataSource.refreshData()
            return
          }
          await ToolsUtil.isFileExist(target_item) ?
          ToolsUtil.routerWhere(this.pathStack, 'RedPlayer', item!, this.videoListController.videoMetaDataList) :
          this.videoListController.videoDataSource.deleteUnExistFile(target_item)
        }, 200)
      })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
        .onClick(() => {
          DataSyncUtil.editing_video = JSON.stringify(item)
          this.VideoDetailDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: "添加到文件夹",
        builder: (): void => this.FileFolderMenuBuilder(item)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(() => {
          DataSyncUtil.editing_video = JSON.stringify(item)
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
    })
  }

  @Builder
  MenuBuilderExtend(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')), content: $r('app.string.edit')
      })
        .onClick(() => {
          DataSyncUtil.editing_video = JSON.stringify(item)
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
  itemStart() {
    Stack() {
    }
    .onVisibleAreaChange([0, 1], (visible: boolean, a: number) => {
      if (visible && a > 0.999999) {
        this.sideBarController.openSideBar()
        setTimeout(() => this.videoListController.listScroller.closeAllSwipeActions(), 100)
      }
    }).width(50).height(1)
  }

  @Builder
  FileFolderMenuBuilder(video_item: VideoMetadata | undefined) {
    FileFolderMenu({
      videoListController: this.videoListController,
      fileFolderSource: this.fileFolderSource,
      video_item: video_item
    })
  }
}