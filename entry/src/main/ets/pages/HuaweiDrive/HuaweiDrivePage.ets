import HuaweiDriveConfig from '../../common/HuaweiDriveConfig'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import {
  HuaweiDriveAbout, HuaweiDriveFile, HuaweiDriveFolderPath
} from '../../interfaces/HuaweiDriveInterface'
import HuaweiDriveUtil, { HuaweiDriveError } from '../../utils/HuaweiDriveUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { LengthMetrics } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { salmonLogger } from 'salmonlogger'
import { webview } from '@kit.ArkWeb'
import { url } from '@kit.ArkTS'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

const TAG = 'HuaweiDrivePage'

@ComponentV2
export struct HuaweiDrivePage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local files: HuaweiDriveFile[] = []
  @Local about: HuaweiDriveAbout | undefined = undefined
  @Local folderPath: HuaweiDriveFolderPath[] = [{ id: 'root', name: ToolsUtil.getStringResource($r('app.string.huawei_drive').id) }]
  @Local loading: boolean = false
  @Local authorizing: boolean = false
  @Local restoringSession: boolean = false
  @Local showAuthWeb: boolean = false
  @Local errorMessage: string = ''
  @Local oauthState: string = ''
  private listScroller: Scroller = new Scroller()
  private webController: webview.WebviewController = new webview.WebviewController()

  aboutToAppear(): void {
    void this.initialize()
  }

  @Builder
  NavigationMenus() {
    Row({ space: 8 }) {
      if (HuaweiDriveUtil.isAuthorized()) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(22)
            .fontColor([$r('app.color.text_color')])
        }
        .width(36)
        .height(36)
        .backgroundColor($r('app.color.list_item_background'))
        .onClick(() => void this.loadCurrentFolder())

        Button($r('app.string.exit'))
          .height(36)
          .fontSize(13)
          .fontColor($r('app.color.text_color'))
          .backgroundColor($r('app.color.list_item_background'))
          .onClick(() => void this.logout())
      }
    }
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      Column() {
        if (this.showAuthWeb) {
          this.AuthWeb()
        } else if (this.restoringSession) {
          this.RestoringView()
        } else if (!HuaweiDriveUtil.isAuthorized()) {
          this.AuthorizationView()
        } else {
          this.DriveContent()
        }
      }.clip(false)
      .width('100%')
      .height('100%')
      .padding({ bottom: SafeHeight.bottomSafeHeight })
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      padding: { start: LengthMetrics.vp(5), end: LengthMetrics.vp(5) },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_background') },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_background_transparent') },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        }
      },
      content: {
        title: { mainTitle: $r('app.string.huawei_drive') },
        stackBuilder: (): void => this.NavigationMenus()
      }
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ?
      Setting.backgroundBlurImageSrc : Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .bindToScrollable([this.listScroller])
    .dynamicHideTitleBar({
      hideTitleArea: false,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP
    })
    .hideBackButton(false)
    .onBackPressed(() => {
      if (this.folderPath.length > 1 && !this.loading) {
        this.folderPath = this.folderPath.slice(0, -1)
        void this.loadCurrentFolder()
        return true
      }
      return false
    })
  }

  @Builder
  RestoringView() {
    Column({ space: 12 }) {
      LoadingProgress().width(42).height(42).color($r('app.color.main_color'))
      Text($r('app.string.restoring_huawei_login'))
        .fontSize(14)
        .fontColor($r('app.color.text_color'))
        .opacity(0.65)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  AuthWeb() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Web({
        src: HuaweiDriveConfig.buildAuthorizeUrl(this.oauthState),
        controller: this.webController
      })
        .onLoadIntercept((event: OnLoadInterceptEvent) => this.handleLoadIntercept(event))
        .width('100%')
        .height('100%')
      Button($r('app.string.cancel'))
        .height(36)
        .margin({ top: 12, right: 12 })
        .backgroundColor($r('app.color.list_item_background'))
        .fontColor($r('app.color.text_color'))
        .onClick(() => {
          this.showAuthWeb = false
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  AuthorizationView() {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.cloud'))
        .fontSize(52)
        .fontColor([$r('app.color.main_color')])
      Text($r('app.string.access_huawei_drive'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_color'))
      Text($r('app.string.huawei_permission_desc'))
        .fontSize(14)
        .fontColor($r('app.color.text_color'))
        .opacity(0.65)
        .textAlign(TextAlign.Center)
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(13)
          .fontColor('#E84040')
          .textAlign(TextAlign.Center)
      }
      Button(this.authorizing ? $r('app.string.authorizing') : $r('app.string.authorize_access'))
        .enabled(!this.authorizing)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.main_color'))
        .borderRadius(18)
        .onClick(() => {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.feature_in_development').id))
          return
          // this.startAuthorization()
        })
    }
    .padding(24)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  DriveContent() {
    Column() {
      if (this.about) {
        Row() {
          Column({ space: 3 }) {
            Text(this.about.user?.displayName || $r('app.string.huawei_cloud_space'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_color'))
            Text(this.quotaText())
              .fontSize(12)
              .fontColor($r('app.color.text_color'))
              .opacity(0.55)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .padding(14)
        .margin({ left: 16, right: 16, bottom: 10 })
        .width('auto')
        .borderRadius(16)
        .backgroundColor($r('app.color.list_item_background'))
      }

      Scroll() {
        Row({ space: 5 }) {
          Repeat<HuaweiDriveFolderPath>(this.folderPath)
            .each((item: RepeatItem<HuaweiDriveFolderPath>) => {
              Row({ space: 5 }) {
                Text(item.item.name)
                  .fontSize(13)
                  .fontColor(item.index === this.folderPath.length - 1 ?
                    $r('app.color.text_color') : $r('app.color.main_color'))
                  .maxLines(1)
                if (item.index < this.folderPath.length - 1) {
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(12)
                    .fontColor([$r('app.color.text_color')])
                    .opacity(0.45)
                }
              }
              .onClick(() => {
                if (item.index < this.folderPath.length - 1) {
                  this.folderPath = this.folderPath.slice(0, item.index + 1)
                  void this.loadCurrentFolder()
                }
              })
            })
            .key((item: HuaweiDriveFolderPath) => item.id)
        }
        .padding({ left: 18, right: 18, bottom: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      if (this.loading) {
        Column({ space: 10 }) {
          LoadingProgress().width(32).height(32).color($r('app.color.main_color'))
          Text($r('app.string.reading_cloud_drive'))
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .opacity(0.6)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage) {
        Column({ space: 12 }) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .opacity(0.7)
            .textAlign(TextAlign.Center)
          Button($r('app.string.retry')).onClick(() => void this.loadCurrentFolder())
        }
        .padding(24)
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.files.length === 0) {
        Column({ space: 8 }) {
          Text($r('app.string.no_playable_media_here'))
            .fontSize(17)
            .fontColor($r('app.color.text_color'))
          Text($r('app.string.other_files_hidden'))
            .fontSize(13)
            .fontColor($r('app.color.text_color'))
            .opacity(0.45)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ scroller: this.listScroller, space: 8 }) {
          Repeat<HuaweiDriveFile>(this.files)
            .each((item: RepeatItem<HuaweiDriveFile>) => {
              ListItem() {
                this.FileItem(item.item)
              }
            })
            .key((item: HuaweiDriveFile) => item.id)
            .virtualScroll()
        }
        .width('100%')
        .height('100%')
        .clip(false)
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  FileItem(file: HuaweiDriveFile) {
    Row({ space: 12 }) {
      SymbolGlyph(HuaweiDriveUtil.isFolder(file) ? $r('sys.symbol.folder') : $r('sys.symbol.play_round_triangle'))
        .fontSize(28)
        .fontColor([$r('app.color.main_color')])
        .width(44)
      Column({ space: 4 }) {
        Text(file.fileName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_color'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (!HuaweiDriveUtil.isFolder(file)) {
          Text(this.fileDescription(file))
            .fontSize(12)
            .fontColor($r('app.color.text_color'))
            .opacity(0.5)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (HuaweiDriveUtil.isFolder(file)) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(17)
          .fontColor([$r('app.color.text_color')])
          .opacity(0.45)
      }
    }
    .padding(14)
    .width('100%')
    .constraintSize({ minHeight: 72 })
    .borderRadius(14)
    .backgroundColor($r('app.color.list_item_background'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
    .onClick(() => {
      if (HuaweiDriveUtil.isFolder(file)) {
        this.folderPath = [...this.folderPath, { id: file.id, name: file.fileName }]
        void this.loadCurrentFolder()
      } else {
        void this.playOnline(file)
      }
    })
  }

  private async initialize(): Promise<void> {
    if (!HuaweiDriveConfig.isOAuthConfigured()) {
      return
    }
    if (HuaweiDriveUtil.isAuthorized()) {
      await this.loadCurrentFolder()
      return
    }
    if (!HuaweiDriveUtil.hasSavedSession()) {
      return
    }
    this.restoringSession = true
    this.errorMessage = ''
    try {
      if (await HuaweiDriveUtil.restoreAuthorization()) {
        await this.loadCurrentFolder()
      }
    } catch (error) {
      this.errorMessage = this.errorText(error)
    } finally {
      this.restoringSession = false
    }
  }

  private handleLoadIntercept(event: OnLoadInterceptEvent): boolean {
    const requestUrl = event.data.getRequestUrl()
    if (!requestUrl.startsWith(HuaweiDriveConfig.REDIRECT_URI)) {
      return false
    }
    this.showAuthWeb = false
    void this.handleOAuthCallback(requestUrl)
    return true
  }

  private async handleOAuthCallback(requestUrl: string): Promise<void> {
    const queryIndex = requestUrl.indexOf('?')
    const fragmentIndex = requestUrl.indexOf('#')
    const startIndex = queryIndex >= 0 ? queryIndex + 1 : fragmentIndex >= 0 ? fragmentIndex + 1 : -1
    if (startIndex < 0) {
      this.errorMessage = ToolsUtil.getStringResource($r('app.string.huawei_auth_missing_params').id)
      return
    }
    const params = new url.URLParams(requestUrl.substring(startIndex))
    const error = params.get('error')
    if (error) {
      this.errorMessage = params.get('error_description') ?? ToolsUtil.getStringResourceArgs($r('app.string.huawei_auth_failed').id, error)
      return
    }
    if (params.get('state') !== this.oauthState) {
      this.errorMessage = ToolsUtil.getStringResource($r('app.string.huawei_auth_state_failed').id)
      return
    }
    const code = params.get('code')
    if (!code) {
      this.errorMessage = ToolsUtil.getStringResource($r('app.string.huawei_auth_missing_code').id)
      return
    }
    this.authorizing = true
    this.errorMessage = ''
    try {
      await HuaweiDriveUtil.exchangeAuthorizationCode(code)
      await this.loadCurrentFolder()
    } catch (error) {
      this.errorMessage = this.errorText(error)
    } finally {
      this.authorizing = false
    }
  }

  private async logout(): Promise<void> {
    await HuaweiDriveUtil.logout()
    this.files = []
    this.about = undefined
    this.folderPath = [{ id: 'root', name: ToolsUtil.getStringResource($r('app.string.huawei_drive').id) }]
    this.errorMessage = ''
  }

  private async loadCurrentFolder(): Promise<void> {
    if (!HuaweiDriveUtil.isAuthorized()) {
      return
    }
    this.loading = true
    this.errorMessage = ''
    try {
      const currentFolder = this.folderPath[this.folderPath.length - 1]
      const result = await Promise.all([
        HuaweiDriveUtil.listFiles(currentFolder.id),
        this.about ? Promise.resolve(this.about) : HuaweiDriveUtil.getAbout()
      ])
      this.files = result[0].filter((file: HuaweiDriveFile) =>
      HuaweiDriveUtil.isFolder(file) || HuaweiDriveUtil.isPlayable(file))
      this.about = result[1]
    } catch (error) {
      this.errorMessage = this.errorText(error)
    } finally {
      this.loading = false
    }
  }

  private async playOnline(file: HuaweiDriveFile): Promise<void> {
    this.errorMessage = ''
    try {
      const headers = await HuaweiDriveUtil.getStreamHeaders()
      const uri = HuaweiDriveUtil.getStreamUrl(file)
      const metadata = this.toVideoMetadata(file, uri)
      metadata.network_http_headers = headers
      await ToolsUtil.routerWhere(this.pathStack, metadata, [metadata], false, true)
    } catch (error) {
      this.errorMessage = this.errorText(error)
      ToolsUtil.showToast(this.errorMessage)
    }
  }

  private toVideoMetadata(file: HuaweiDriveFile, uri: string): VideoMetadata {
    return VideoInfoUtil.buildNetworkVideoMetadata(uri, `huawei_drive_${file.id}`, file.fileName,
      file.size ? ToolsUtil.formatFileSize(file.size) : '',
      [file.videoMetadata?.width ?? 1, file.videoMetadata?.height ?? 1])
  }

  private quotaText(): string {
    const used = Number(this.about?.storageQuota?.usedSpace ?? 0)
    const total = Number(this.about?.storageQuota?.userCapacity ?? 0)
    if (total <= 0) {
      return ToolsUtil.getStringResource($r('app.string.cloud_capacity_unavailable').id)
    }
    return ToolsUtil.getStringResourceArgs2($r('app.string.cloud_used_of_total').id, ToolsUtil.formatFileSize(used), ToolsUtil.formatFileSize(total))
  }

  private fileDescription(file: HuaweiDriveFile): string {
    const sizeText = file.size ? ToolsUtil.formatFileSize(file.size) : ToolsUtil.getStringResource($r('app.string.unknown_size').id)
    const width = file.videoMetadata?.width ?? 0
    const height = file.videoMetadata?.height ?? 0
    const resolutionText = width > 0 && height > 0 ? ` · ${width}×${height}` : ''
    if (!file.editedTime) {
      return `${sizeText}${resolutionText}`
    }
    return `${sizeText}${resolutionText} · ${new Date(file.editedTime).toLocaleDateString()}`
  }

  private errorText(error: Object): string {
    const message = error instanceof Error ? error.message : String(error)
    if (error instanceof HuaweiDriveError && error.statusCode === 401) {
      HuaweiDriveUtil.clearAuthorization()
    }
    salmonLogger.addLog(TAG, `Huawei Drive error: ${message}`, true)
    return message || ToolsUtil.getStringResource($r('app.string.huawei_drive_failed').id)
  }
}
