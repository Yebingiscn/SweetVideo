import NavigationAddress from '../../common/NavigationCommon';
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem';
import Preferences from '../../database/Preferences';
import { PathUtils } from '../../utils/PathUtils';
import SelectFileUtil from '../../utils/SelectFileUtil';
import SubtitleUtil from '../../utils/SubtitleUtil';
import ToolsUtil from '../../utils/ToolsUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import { commentManager } from '@kit.AppGalleryKit';
import { salmonLogger } from 'salmonlogger';
import { SafeHeight, Setting } from '../../utils/ObservedUtil';
import { Want } from '@kit.AbilityKit';
import PreferencesUtil from '../../database/PreferencesUtil';

@Component
export struct MoreSettingPage {
  @Consume('pathStack') pathStack: NavPathStack

  build() {
    NavDestination() {
      List() {
        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.doc_plaintext'),
            message: '流心运行日志',
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
              PreferencesUtil.delPreferencesValue(PathUtils.appContext!, 'sweet_video', 'circle_play')
              PreferencesUtil.delPreferencesValue(PathUtils.appContext!, 'sweet_video', 'is_list_display')
              const coverFromSandbox = await fs.listFile(PathUtils.coverPath)?.catch(() => {
                console.error('get cover fail')
              });
              const isNumericStart = (filename: string): boolean => /^\d/.test(filename);
              const coverFromSandboxArray = Array.isArray(coverFromSandbox)
                ? coverFromSandbox.filter(file => isNumericStart(file)) : [];
              const subtitleFromSandbox = await fs.listFile(PathUtils.subtitlePath)?.catch(() => {
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
              salmonLogger.addLog(this.pathStack.getAllPathName()[0],
                `检测到失效封面文件数：${missingCoverFiles.length}，内容：${missingCoverFiles.toString()}`, false)
              const missingSubtitleFiles = subtitleFromSandboxArray.filter(file => !existingItemsSet.has(file));
              salmonLogger.addLog(this.pathStack.getAllPathName()[0],
                `检测到失效字幕文件数：${missingSubtitleFiles.length}，内容：${missingSubtitleFiles.toString()}`, false)
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

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.hand_thumbsup'),
            message: '从夯到拉锐评下流心',
            onPress: async () => {
              try {
                commentManager.showCommentDialog(PathUtils.appContext!).then(() => {
                  salmonLogger.addLog(this.pathStack.getAllPathName()[0], '成功展示评论弹窗', false)
                })?.catch((error: BusinessError<Object>) => {
                  salmonLogger.addLog(this.pathStack.getAllPathName()[0],
                    `展示评论弹窗错误, Code: ${error.code}, message: ${error.message}`, true)
                  const want: Want = {
                    action: 'ohos.want.action.appdetail',
                    // bundleName为需要拉起写评论页的应用包名，action隐式指定为write-review，表示进入详情页后，下一步将拉起写评论页。
                    uri: `store://appgallery.huawei.com/app/detail?id=${PathUtils.appContext!.abilityInfo.bundleName}&action=write-review`
                  };
                  PathUtils.appContext!.startAbility(want)
                    .then(() => {
                      salmonLogger.addLog(this.pathStack.getAllPathName()[0], '成功打开应用市场评论页', false)
                    })
                  ?.catch((error: BusinessError) => {
                    ToolsUtil.showToast('打开应用市场失败，原因是：' + error)
                    salmonLogger.addLog(this.pathStack.getAllPathName()[0], '打开应用市场评论页失败，原因是：' + error,
                      true)
                  });
                });
              } catch (error) {
                salmonLogger.addLog(this.pathStack.getAllPathName()[0],
                  `展示评论弹窗错误, Code: ${error.code}, message: ${error.message}`,
                  true)
              }
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
      .contentEndOffset(SafeHeight.bottomSafeHeight)
    }
    .hideToolBar(true)
    .title('更多设置')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .backdropBlur(Setting.backgroundDropBlur)
  }
}