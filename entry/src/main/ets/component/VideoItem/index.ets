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


@Component
export struct VideoItem {
  @Prop item: VideoMetadata
  @Prop index: number
  @StorageLink('is_list_display') is_list_display: boolean = false
  videoListController: VideoListController = new VideoListController([])

  build() {
    Row() {
      if (this.is_list_display) {
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
    .padding({
      left: 10,
      right: 10,
      top: 5,
      bottom: 5
    })
  }
}

@Observed
export class VideoListController {
  listScroller: ListScroller = new ListScroller()
  video_meta_data_list: VideoMetadata[]
  multipleChooseState: Visibility = Visibility.None
  itemMultipleChoose: boolean = false
  list_line: number = 1
  videoDataSource: VideoDataSource


  constructor(video_meta_data_list: VideoMetadata[]) {
    this.video_meta_data_list = video_meta_data_list
    this.videoDataSource = new VideoDataSource(this.video_meta_data_list)
  }

  public closeMultipleChoose() {
    this.itemMultipleChoose = false;
    this.multipleChooseState = Visibility.None;
  }

  public refresh(width: number, is_list_display: boolean) {
    const base = Math.floor(width / 500);
    this.list_line = is_list_display ? base + 1 : base + 2;
    // 增加判断，旋转时保持滚动位置不变
    if (this.listScroller.currentOffset().yOffset == -55) {
      this.listScroller.scrollEdge(Edge.Top)
    }
  }
}

@Component
export struct VideoList {
  @ObjectLink videoListController: VideoListController
  sideBarController: SideBarController = new SideBarController()
  searchController: SearchController = new SearchController()

  @State MenuBuilderState: boolean = false

  @State file_folder_list: FileFolder[] = []
  @State fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])

  @StorageLink('is_list_display') is_list_display: boolean = false

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
        const targetIndex = SelectFileUtil.getItemIndex(this.videoListController.video_meta_data_list, editingVideo);
        if (targetIndex === -1) {
          return;
        }
        const titleSet = new Set(this.videoListController.video_meta_data_list.map(v => v.title));
        if (titleSet.has(title)) {
          return;
        }
        this.videoListController.video_meta_data_list[targetIndex].title = title.trim();
        this.videoListController.videoDataSource.updateData(this.videoListController.video_meta_data_list)
        Preferences.saveVideoMetaData(PathUtils.appContext!, this.videoListController.video_meta_data_list)
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  aboutToAppear(): void {
    this.fileFolderSource = new FileFolderDataSource(this.file_folder_list)
  }

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
          if (!this.videoListController.video_meta_data_list.some(i => i.date == item?.date!)) {
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
          ToolsUtil.routerWhere(this.pathStack, 'Player', item, this.videoListController.video_meta_data_list) :
          this.videoListController.videoDataSource.deleteUnExistFile(item)
        })
      }, (item: VideoMetadata) => JSON.stringify(item))
    }
    .cachedCount(3)
    .contentStartOffset(this.topSafeHeight + 55)
    .contentEndOffset(this.bottomSafeHeight)
    .lanes(this.videoListController.list_line)
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
          let target_item = SelectFileUtil.getItem(this.videoListController.video_meta_data_list, item?.date!)
          if (!this.videoListController.video_meta_data_list.find(i => i.date == item?.date!)) {
            ToolsUtil.showToast('数据正在加载中，请重试')
            this.videoListController.videoDataSource.refreshData()
            return
          }
          await ToolsUtil.isFileExist(target_item) ?
          ToolsUtil.routerWhere(this.pathStack, 'FFMpegPlayer', item!, this.videoListController.video_meta_data_list) :
          this.videoListController.videoDataSource.deleteUnExistFile(target_item)
        }, 200)
      })
      MenuItem({ startIcon: $r("app.media.RedPlayer"), content: '红薯播放器' }).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          let target_item = SelectFileUtil.getItem(this.videoListController.video_meta_data_list, item?.date!)
          if (!this.videoListController.video_meta_data_list.find(i => i.date == item?.date!)) {
            ToolsUtil.showToast('数据正在加载中，请重试')
            this.videoListController.videoDataSource.refreshData()
            return
          }
          await ToolsUtil.isFileExist(target_item) ?
          ToolsUtil.routerWhere(this.pathStack, 'RedPlayer', item!, this.videoListController.video_meta_data_list) :
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
        builder: (): void => this.FileFolderMenu(item)
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
  FileFolderMenu(video_item: VideoMetadata | undefined) {
    Menu() {
      LazyForEach(this.fileFolderSource, (item: FileFolder) => {
        MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.folder")), content: item.name })
          .onClick(async () => {
            if (DataSyncUtil.delMultipleList.length > 0) {
              for (let i = 0; i < DataSyncUtil.delMultipleList.length; i++) {
                await this.addVideoToFileFolder(DataSyncUtil.delMultipleList[i], item)
              }
              DataSyncUtil.delMultipleList = []
              this.videoListController.closeMultipleChoose!()
            } else if (this.videoListController.multipleChooseState === Visibility.None) {
              await this.addVideoToFileFolder(video_item!, item)
            }
          })
      }, (item: FileFolder) => item.date)
    }.attributeModifier(new MenuModifier())
  }

  async addVideoToFileFolder(video_item: VideoMetadata, item: FileFolder) {
    if (!item.video_list.some(v => v.title === video_item.title)) {
      this.file_folder_list = await FileFolderUtil.addVideoInFileFolder(PathUtils.appContext!, video_item!, item.date)
      this.videoListController.videoDataSource.deleteData(this.videoListController.video_meta_data_list.findIndex(i => i.date === video_item.date))
      this.videoListController.video_meta_data_list = this.videoListController.video_meta_data_list.filter(i => i.date !== video_item?.date)
      Preferences.saveVideoMetaData(PathUtils.appContext!, this.videoListController.video_meta_data_list)
    }
  }
}