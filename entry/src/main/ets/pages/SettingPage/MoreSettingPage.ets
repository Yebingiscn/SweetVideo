import NavigationAddress from '../../common/NavigationCommon';
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem';
import Preferences from '../../database/Preferences';
import { PathUtils } from '../../utils/PathUtils';
import SelectFileUtil from '../../utils/SelectFileUtil';
import SubtitleUtil from '../../utils/SubtitleUtil';
import ToolsUtil from '../../utils/ToolsUtil';
import { fileIo as fs } from '@kit.CoreFileKit';

@Component
export struct MoreSettingPage {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageLink('backgroundImageSrc') backgroundImageSrc: string = ''
  @StorageLink('backgroundDropBlur') backgroundDropBlur: number = 0
  @Consume('pathStack') pathStack: NavPathStack

  build() {
    NavDestination() {
      List() {
        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.doc_plaintext'),
            message: '崩溃日志',
            onPress: () => {
              this.pathStack.pushPathByName(NavigationAddress.CRASH_PAGE, true)
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.arrow_up_circle'),
            message: '检查更新',
            onPress: () => {
              ToolsUtil.checkUpdate()
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.trash'),
            message: '清理失效文件',
            onPress: async () => {
              const coverFromSandbox = await fs.listFile(PathUtils.coverPath).catch(() => {
                console.error('get cover fail')
              });
              const isNumericStart = (filename: string): boolean => /^\d/.test(filename);
              const coverFromSandboxArray = Array.isArray(coverFromSandbox)
                ? coverFromSandbox.filter(file => isNumericStart(file)) : [];
              const subtitleFromSandbox = await fs.listFile(PathUtils.subtitlePath).catch(() => {
                console.error('get subtitle fail')
              })
              const subtitleFromSandboxArray = Array.isArray(subtitleFromSandbox) ? subtitleFromSandbox : []
              const videoMetaData = Preferences.getVideoMetaData(PathUtils.appContext!)
              const videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
              const fileFolder = Preferences.getFileFolder(PathUtils.appContext!)
              const existingItemsSet = new Set([
                ...videoMetaData.map(v => v.date),
                ...videoMetaDataEncryption.map(v => v.date),
                ...fileFolder.flatMap(folder =>
                folder.video_list?.map(item => item!.date) ?? []
                )
              ])
              const missingCoverFiles = coverFromSandboxArray.filter((file => !existingItemsSet.has(file)))
              const missingSubtitleFiles = subtitleFromSandboxArray.filter(file => !existingItemsSet.has(file));
              const missingFileSum = missingCoverFiles.length + missingSubtitleFiles.length
              await Promise.all([
                ...missingCoverFiles.map((file): Promise<void> => SelectFileUtil.deleteCover(file)),
                ...missingSubtitleFiles.map((file): Promise<void> => SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath,
                  file))
              ])
              ToolsUtil.showToast(missingFileSum > 0 ? '删除了 ' + missingFileSum + ' 项文件' : '没有找到失效文件')
            }
          })
        }
      }
      .align(Alignment.Top)
      .borderRadius(16)
      .margin({ left: 16, right: 16 })
      .clip(true)
      .scrollBar(BarState.Off)
      .height('100%')
      .width('95%')
      .layoutWeight(1)
      .contentEndOffset(this.bottomSafeHeight)
    }
    .hideToolBar(true)
    .title('更多设置')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: this.topSafeHeight })
    .backgroundImage(this.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .backdropBlur(this.backgroundDropBlur)
  }
}