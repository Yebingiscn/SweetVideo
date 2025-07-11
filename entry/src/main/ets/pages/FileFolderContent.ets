import ToolsUtil from '../utils/ToolsUtil';
import { ImageModifier, MenuModifier, SymbolGlyphModifier } from '@kit.ArkUI';
import DataSyncUtil from '../utils/DataSyncUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { JSON } from '@kit.ArkTS';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { VideoDataSource } from '../utils/DataUtil';
import { VideoDetailDialog } from '../component/Dialog/VideoDetailDialog';
import FileFolderUtil from '../utils/FileFolderUtil';
import { FileFolder } from '../interfaces/FileFolderInterface';
import { DefaultDialogShadow } from '../common/DefaultDialogShadow';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import Preferences from '../database/Preferences';
import {
  ButtonFancyModifier,
  ImageFancyModifier,
  ShadowModifier,
  SymbolGlyphFancyModifier
} from '../utils/AttributeModifierUtil';
import { VideoInfoComponent } from '../component/VideoInfoComponent';
import VideoInfoUtil from '../utils/VideoInfoUtil';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import SubtitleUtil from '../utils/SubtitleUtil';
import { PathUtils } from '../utils/PathUtils';
import VideoItem from '../component/VideoItem';

@Component
export struct FileFolderContent { // 文件夹页，不同文件夹公用一个页
  @State videoDataSource: VideoDataSource = new VideoDataSource([])
  @State MenuBuilderState: boolean = false
  @State file_folder: FileFolder | undefined = undefined
  @State file_folder_list: FileFolder[] = []
  @State list_line: number = 1
  @State searchValue: string = ''
  @State is_edit: boolean = false
  @StorageLink('is_list_display') is_list_display: boolean = false
  @State image_modifier: ImageModifier = new ImageModifier();
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  searchController: SearchController = new SearchController()
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  private listScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.file_folder = this.pathStack.getParamByName('FileFolderContent')[0] as FileFolder
    this.videoDataSource = new VideoDataSource(this.file_folder?.video_list!);
  }

  @Builder
  FileFolderMenu(video_item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.plus_square")), content: '添加到首页' })
        .onClick(async () => {
          let video_meta_data = Preferences.getVideoMetaData(PathUtils.appContext!)
          video_meta_data.push(video_item!)
          Preferences.saveVideoMetaData(PathUtils.appContext!, video_meta_data)
          await this.deItem(PathUtils.appContext!, video_item!, true)
        })
      ForEach(this.file_folder_list, (item: FileFolder) => {
        if (item.name !== this.file_folder?.name) {
          MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.folder")), content: item.name })
            .onClick(async () => {
              this.file_folder_list =
                await FileFolderUtil.addVideoInFileFolder(PathUtils.appContext!, video_item!, item.date)
              await this.deItem(PathUtils.appContext!, video_item!, true)
            })
        }
      })
    }.attributeModifier(new MenuModifier())
  }

  @Builder
  SortMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat')),
        content: $r('app.string.sort_by_name')
      })
        .onClick(async () => {
          this.file_folder =
            await ToolsUtil.sortByName(PathUtils.appContext!, this.file_folder?.video_list!,
              this.file_folder!) as FileFolder
          this.videoDataSource.updateData(this.file_folder.video_list)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.sort_by_time')
      })
        .onClick(async () => {
          this.file_folder =
            await ToolsUtil.sortByTime(PathUtils.appContext!, this.file_folder?.video_list!,
              this.file_folder!) as FileFolder
          this.videoDataSource.updateData(this.file_folder.video_list)
        })
    }.attributeModifier(new MenuModifier())
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(async () => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          await ToolsUtil.isFileExist(item) ?
          ToolsUtil.routerToVideoFromFileFolder(this.pathStack, 'FFMpegPlayer', item!, this.file_folder!) :
            await this.deItem(PathUtils.appContext!, item!, false)
        }, 200)
      })
      MenuItem({ startIcon: $r("app.media.RedPlayer"), content: '红薯播放器' }).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          await ToolsUtil.isFileExist(item) ?
          ToolsUtil.routerToVideoFromFileFolder(this.pathStack, 'RedPlayer', item!, this.file_folder!) :
            await this.deItem(PathUtils.appContext!, item!, false)
        }, 200)
      })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
        .onClick(() => {
          DataSyncUtil.editing_video = JSON.stringify(item!)
          this.VideoDetailDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(async () => {
          await this.deItem(PathUtils.appContext!, item!, false)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: "添加到其他文件夹",
        builder: (): void => this.FileFolderMenu(item!)
      })
    }.attributeModifier(new MenuModifier()).onAppear(() => {
      ToolsUtil.startVibration()
      this.MenuBuilderState = true
    })
  }

  @Builder
  NavigationMenus() {
    Row({ space: 15 }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindMenu(this.SortMenuBuilder)
    }.margin({ right: 24, top: 10, left: 50 })
  }

  async deItem(context: Context, item: VideoMetadata, move_to_other_file_folder: boolean) {
    this.file_folder!.video_list = this.file_folder!.video_list.filter(i => i.date !== item.date);
    FileFolderUtil.updateFileFolderList(context, this.file_folder!)
    this.videoDataSource.deleteData(this.videoDataSource.getAllData().indexOf(item))
    RecentPlayUtil.delData(context, item)
    if (!move_to_other_file_folder) {
      SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date!)
      fs.access(PathUtils.coverPath + item.date, (err) => {
        if (!err) { // 文件存在
          fs.unlink(PathUtils.coverPath + item.date, (unlinkErr) => {
            if (unlinkErr) {
              ToolsUtil.showToast('删除视频失败：' + item.title + '原因是：' + unlinkErr.message)
              return;
            }
          });
        }
      })
    }
  }

  build() {
    NavDestination() {
      Column() {
        Search({
          controller: this.searchController,
          placeholder: $r('app.string.search_placeholder'),
          value: $$this.searchValue, // $$使得 searchValue 可以动态变化，清空搜索框依赖这个
        })
          .height(40)
          .width('90%')
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .attributeModifier(new ShadowModifier())
          .animation({ duration: 300, curve: Curve.Ease })
          .onChange(() => {
            const newVideoList = SelectFileUtil.getItemFromSearch(
              this.file_folder?.video_list || [],
              this.searchValue,
            );
            if (this.file_folder) {
              this.searchValue === '' ?
                this.file_folder.video_list =
                  Preferences.getFileFolder(PathUtils.appContext!)
                    .find(i => i.date === this.file_folder?.date)?.video_list! :
                this.file_folder.video_list = newVideoList
              this.videoDataSource.updateData(this.file_folder.video_list)
            }
          })
          .onEditChange((isEditing: boolean) => {
            animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
              this.is_edit = isEditing
            })
          })
        if (this.file_folder?.video_list.length === 0) {
          Text('还没有任何视频哦~')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .align(Alignment.Center)
            .height('100%')
            .width('100%')
        }
        List({ scroller: this.listScroller, space: 10 }) {
          LazyForEach(this.videoDataSource, (item: VideoMetadata, index: number) => {
            ListItem() {
              VideoItem({
                item: item,
                video_meta_data_list: this.videoDataSource.getAllData(),
                index: index
              })
            }.onClick(async () => {
              await ToolsUtil.isFileExist(item) ?
              ToolsUtil.routerToVideoFromFileFolder(this.pathStack, 'Player', item, this.file_folder!) :
                await this.deItem(PathUtils.appContext!, item, false)
            }).bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
          }, (item: VideoMetadata) => JSON.stringify(item))
        }
        .cachedCount(3)
        .lanes(this.list_line)
        .layoutWeight(1)
        .padding({ left: 20, right: 20 })
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
        .chainAnimation(true)
        .scrollBar(BarState.Off)
      }.width('100%').height('100%')
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        const width = Number(newValue.width);
        const base = Math.floor(width / 500);
        this.list_line = this.is_list_display
          ? base + 1
          : base + 2;
      })
      .backgroundColor($r('app.color.start_window_background'))
    }
    .onShown(async () => {
      this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
      this.file_folder = this.file_folder_list.find(i => i.date === this.file_folder?.date)
      this.videoDataSource.updateData(this.file_folder?.video_list!)
    })
    .onWillDisappear(() => {
      this.file_folder = undefined
      this.file_folder_list = []
    })
    .title(this.file_folder?.name || '文件夹')
    .menus(this.NavigationMenus)
    .padding({ top: this.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
    .onBackPressed(() => {
      if (this.searchValue.length > 0) {
        this.searchValue = ''
        return true
      } else {
        return false
      }
    })
  }
}