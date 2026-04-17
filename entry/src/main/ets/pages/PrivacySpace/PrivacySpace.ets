import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { VideoDataSource } from '../../utils/DataUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { VideoDetailDialog } from '../../component/Dialog/VideoDetailDialog'
import Preferences from '../../database/Preferences'
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import {
  ButtonFancyModifier,
  DefaultDialogShadow,
  MenuFancyModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import { FileProcessorUtil } from '../../utils/FileProcessorUtil'
import { PathUtils } from '../../utils/PathUtils'
import { EditPasswordDialog } from '../../component/Dialog/EditPasswordDialog'
import { SearchComponent } from '../../component/VideoItemComponent/SearchComponent'
import NavigationAddress, { PrivacySpaceParams } from '../../common/NavigationCommon'
import { EditMetadataDialog } from '../../component/Dialog/EditMetadataDialog'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { ImportProgressBuilder } from '../../component/VideoItemComponent/ImportProgressBuilder'
import VideoListItem from '../../component/VideoItemComponent/VideoListItemComponent'
import VideoCardItem from '../../component/VideoItemComponent/VideoCardItemComponent'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { ListDisplayMode } from '../../common/enum/DisplayMode'
import SubtitleUtil from '../../utils/SubtitleUtil'
import { PrivacyVideoRepository } from '../../repository/PrivacyVideoRepository'
import { PrivacyVideoEntity } from '../../entity/PrivacyVideoEntity'
import { SortUtil } from '../../utils/SortUtil'
import { Privacy, SafeHeight, Setting } from '../../utils/ObservedUtil'
import { SortComponent } from '../../component/VideoItemComponent/SortComponent'
import { DELAY_JUMP_TO_PLAYER, NO_BLUR_AMOUNT, PRIVACY_BACKGROUND_BLUR_AMOUNT } from '../../common/Constants'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoItemPreviewBuilder } from '../../component/VideoItemComponent/VideoItemPreviewBuilder'

@Component
export struct PrivacySpace { // 隐私空间页
  @State videoDataSource: VideoDataSource = new VideoDataSource([])
  @State video_meta_data_encryption: VideoMetadata[] = []
  @State list_line: number = 1

  // ORM 改造：隐私空间数据从 Preferences 键值存储迁移到 PrivacyVideoRepository
  // 注意：PrivacyVideoEntity 使用自增主键，uri 字段存储的是应用私有 sandbox 路径，
  //       去重/删除时应使用 originalUri（原始文件 URI）或按 id 操作，避免误删。

  // 转换 PrivacyVideoEntity 到 VideoMetadata，供 UI 层复用原有接口
  private toVideoMetadata(entity: PrivacyVideoEntity): VideoMetadata {
    return {
      uri: entity.uri,
      title: entity.title,
      date: entity.importedAt,
      size: [Number(entity.width) || 0, Number(entity.height) || 0],
      time: Number(entity.duration) || 0,
      last_play: Number(entity.lastPosition) || 0,
      format: entity.format,
      video_size: entity.fileSize,
      hdr_type: Number(entity.hdrType) || 0,
      start_time: Number(entity.startTime) || 0,
      end_time: Number(entity.endTime) || 0,
      external_subtitle_format: '',
      pointA: Number(entity.pointA) || 0,
      pointB: Number(entity.pointB) || 0
    }
  }

  /**
   * 获取当前排序图标（隐私空间）
   * @returns 通用排序图标 Resource
   */
  private getSortIconResource(): Resource {
    // 使用通用排序图标，不随排序类型变化
    return $r('sys.symbol.text_and_arrow_down')
  }

  /**
   * 获取当前排序方向（隐私空间）
   * @returns 'asc' 升序（从小到大）或 'desc' 降序（从大到小）
   */
  private getSortOrder(): 'asc' | 'desc' {
    return Preferences.getVideoSortOrder(PathUtils.appContext!, true)
  }

  // 从 ORM 加载隐私视频
  // 说明：ibest-orm 的 ORDER BY 对中文拼音支持不佳，因此 name 排序在 SQL 查询后
  //       通过 SortUtil.sortByPinyin 在应用层二次排序；time 排序同理做数字类型转换后重排。
  private async loadPrivacyVideos(): Promise<void> {
    const privacyRepo = PrivacyVideoRepository.getInstance()
    // 获取排序偏好和方向
    const sortType = Preferences.getVideoSortType(PathUtils.appContext!, true)
    const sortOrder = Preferences.getVideoSortOrder(PathUtils.appContext!, true)
    let entities = await privacyRepo.findAllOrdered(sortType, sortOrder)
    // name 排序需要在应用层处理中文拼音，time 排序确保数字正确排序
    if (sortType === 'name') {
      entities = this.sortEntitiesByPinyin(entities, sortOrder)
    } else if (sortType === 'time') {
      entities = this.sortEntitiesByDuration(entities, sortOrder)
    }
    this.video_meta_data_encryption = entities.map(e => this.toVideoMetadata(e))
    this.videoDataSource.updateData(this.video_meta_data_encryption)
  }

  /**
   * 按拼音排序隐私视频实体（支持中文自然排序）
   * 使用 SortUtil 通用排序工具
   * @param entities 视频实体数组
   * @param order 排序方向：'asc' 升序(A-Z)，'desc' 降序(Z-A)
   * @returns 排序后的实体数组
   */
  private sortEntitiesByPinyin(entities: PrivacyVideoEntity[], order: 'asc' | 'desc' = 'desc'): PrivacyVideoEntity[] {
    return SortUtil.sortByPinyin(entities, (e) => e.title, order)
  }

  /**
   * 按时长排序隐私视频实体
   * 使用 SortUtil 通用排序工具
   * @param entities 视频实体数组
   * @param order 排序方向：'asc' 升序(短→长)，'desc' 降序(长→短)
   * @returns 排序后的实体数组
   */
  private sortEntitiesByDuration(entities: PrivacyVideoEntity[], order: 'asc' | 'desc' = 'desc'): PrivacyVideoEntity[] {
    return SortUtil.sortByDuration(entities, (e) => e.duration, order)
  }

  // 保存隐私视频到 ORM
  private async savePrivacyVideo(video: VideoMetadata, originalUri?: string): Promise<void> {
    const privacyRepo = PrivacyVideoRepository.getInstance()
    const entity = new PrivacyVideoEntity()
    entity.uri = video.uri
    entity.title = video.title
    entity.originalUri = originalUri || video.uri
    entity.width = video.size[0] || 0
    entity.height = video.size[1] || 0
    entity.duration = video.time
    entity.lastPosition = video.last_play
    entity.format = video.format
    entity.fileSize = video.video_size
    entity.hdrType = video.hdr_type
    entity.startTime = video.start_time
    entity.endTime = video.end_time
    entity.pointA = video.pointA
    entity.pointB = video.pointB
    entity.importedAt = new Date().toISOString()
    entity.date = video.date || new Date().toISOString()
    await privacyRepo.save(entity)
  }
  @Consume('pathStack') pathStack: NavPathStack
  @State totalItems: number = 0
  @State processedItems: number = 0
  @State loading: boolean = false
  @State searchValue: string = ''
  editMetadataDialogController: CustomDialogController = new CustomDialogController({
    builder: EditMetadataDialog({
      confirm: async (title: string | undefined) => {
        if (!title?.trim()) {
          return
        }
        const editingVideo = DataSyncUtil.editingVideo!
        const targetIndex = SelectFileUtil.getItemIndex(this.video_meta_data_encryption, editingVideo)
        if (targetIndex === -1) {
          return
        }
        if (this.video_meta_data_encryption.some((v, index) => index !== targetIndex && v.title === title.trim())) {
          return // 这里直接用 some 来代替，隐私空间视频不多，没必要每次都 new 一个Set
        }
        // 更新 ORM
        const privacyRepo = PrivacyVideoRepository.getInstance()
        const entity = await privacyRepo.query().where({ uri: editingVideo.uri }).find()
        if (entity.length > 0) {
          entity[0].title = title.trim()
          await privacyRepo.save(entity[0])
        }
        // 更新本地数据
        this.video_meta_data_encryption[targetIndex].title = title.trim()
        this.videoDataSource.updateData(this.video_meta_data_encryption)
        this.searchValue = ''
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @State is_edit: boolean = false
  @State passwd: string = 'passwd'
  editPasswdDialogController: CustomDialogController = new CustomDialogController({
    builder: EditPasswordDialog({
      confirm: (passwd: string | undefined) => {
        if (!passwd || passwd.trim() == '') {
          return
        }
        this.passwd = passwd
        ToolsUtil.savePwd(PathUtils.appContext!, passwd)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.set_passwd_tip').id))
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @State delMultipleList: VideoMetadata[] = []
  @State isPresent: boolean = false
  searchController: SearchController = new SearchController()
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  private listScroller: Scroller = new Scroller()

  @Builder
  PrivacySpaceSettingBuilder() {
    Column() {
      SettingsClickItem({
        symbol: $r('sys.symbol.lock'),
        message: '重设密码',
        onPress: () => {
          this.isPresent = false
          this.passwd = Preferences.getPassword(PathUtils.appContext!)
          this.editPasswdDialogController.open()
        }
      })

      SettingsToggleItem({
        symbol: $r('sys.symbol.checkmark_shield'),
        message: '设置中显示隐私空间入口',
        enable: Setting.showSettingPageEntry,
        onChange: (checked: boolean) => {
          Setting.showSettingPageEntry = checked
          Preferences.saveShowSettingPageEntry(PathUtils.appContext!, Setting.showSettingPageEntry)
        }
      })

      SettingsToggleItem({
        symbol: $r('sys.symbol.arrow_up_left_and_arrow_down_right'),
        message: '首页双指捏合往外划开进入隐私空间',
        enable: Setting.allowGestureEntry,
        onChange: (checked: boolean) => {
          Setting.allowGestureEntry = checked
          Preferences.saveAllowGestureEntry(PathUtils.appContext!, Setting.allowGestureEntry)
        }
      })

      SettingsClickItem({
        symbol: $r('sys.symbol.staroflife_rectangle'),
        message: '异常数据列表',
        onPress: () => {
          this.isPresent = false
          this.pathStack.pushPathByName(NavigationAddress.PRIVACY_ERROR_LIST, true)
        }
      })

      Column({ space: 8 }) {
        Text('清理提示')
          .fontSize(20).fontWeight(FontWeight.Medium)
        Text('删除隐私空间的视频后，系统存储的占用情况可能不会立即刷新。建议重启手机，以查看准确的空间释放情况。')
          .fontSize(15)
      }
      .padding(15)
      .alignItems(HorizontalAlign.Start)
      .borderRadius(16)
      .width('100%')
      .backgroundColor($r('app.color.start_window_background_blur'))
      .margin({ top: 10 })
    }.width('100%').height('100%').padding({ left: 16, right: 16 })
  }

  @Builder
  NavigationMenus() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(35, 35))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindSheet($$this.isPresent, this.PrivacySpaceSettingBuilder, {
        detents: [SheetSize.FIT_CONTENT],
        height: SheetSize.MEDIUM,
        preferType: SheetType.CENTER,
        enableOutsideInteractive: false,
        dragBar: true,
        showClose: true,
        title: { title: '隐私空间设置' },
      })
      .onClick(() => {
        this.isPresent = !this.isPresent
      })
      .margin({ right: 10 })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(35, 35))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindMenu(this.SelectFileMenuBuilder)
      .margin({ right: 10 })

      this.SortButtonBuilder()
    }.margin({ right: 10, top: 10 })
  }

  @Builder
  SelectFileMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder')),
        content: $r('app.string.import_from_files')
      })
        .onClick(async () => {
          this.isPresent = false
          await this.toMetaData(await SelectFileUtil.selectFromFileManager())
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')),
        content: $r('app.string.import_from_album')
      })
        .onClick(async () => {
          this.isPresent = false
          await this.toMetaData(await SelectFileUtil.selectVideos())
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  /**
   * 排序按钮 Builder
   * 显示通用排序图标 + 升序指示器
   * 点击后弹出排序菜单，可切换排序类型和方向
   */
  @Builder
  SortButtonBuilder() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      // 使用 Stack 叠加图标和方向指示
      Stack({ alignContent: Alignment.BottomEnd }) {
        // 主图标：通用排序图标（不随排序类型变化）
        SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
          .attributeModifier(new SymbolGlyphFancyModifier(20, '', ''))
        // 排序方向指示器：仅升序时显示向上箭头，降序无指示（默认状态）
        if (this.getSortOrder() === 'asc') {
          SymbolGlyph($r('sys.symbol.arrow_up'))
            .attributeModifier(new SymbolGlyphFancyModifier(10, '', ''))
            .offset({ x: 6, y: 6 })
        }
      }
      .width(22)
      .height(22)
    }
    .backdropBlur(150)
    .attributeModifier(new ButtonFancyModifier(35, 35))
    .animation({ duration: 300, curve: Curve.Ease })
    .bindMenu(this.SortMenuBuilder)
  }

  @Builder
  SortMenuBuilder() {
    SortComponent({
      onSortByName: async () => {
        Preferences.saveVideoSortType(PathUtils.appContext!, 'name', true)
        await this.loadPrivacyVideos()
      },
      onSortByTime: async () => {
        Preferences.saveVideoSortType(PathUtils.appContext!, 'time', true)
        await this.loadPrivacyVideos()
      },
      onSortByDatetime: async () => {
        Preferences.saveVideoSortType(PathUtils.appContext!, 'datetime', true)
        await this.loadPrivacyVideos()
      }
    })
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.play_round_triangle')),
        content: VideoOperateUtil.getPlayerName(Setting.defaultPlayerEngine, true)
      })
        .onClick(() => {
          setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
            await this.clickItem(item, VideoOperateUtil.getPlayerNavigationAddress(Setting.defaultPlayerEngine, true))
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
        .onClick(() => {
          DataSyncUtil.editingVideo = item
          this.VideoDetailDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(async () => {
          await this.deleteItem(item!.uri, item!.date)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')),
        content: $r('app.string.rename')
      })
        .onClick(() => {
          DataSyncUtil.editingVideo = item
          this.editMetadataDialogController.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: '导出'
      })
        .onClick(async () => {
          await SelectFileUtil.exportFile(item!.uri, item!.title, item!.format, PathUtils.appContext!)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat_size_square')), content: '导入或删除字幕'
      })
        .onClick(async () => {
          await SubtitleUtil.importOrDeleteSubtitleProcess(item!)
          // 重新加载隐私视频数据
          await this.loadPrivacyVideos()
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder) {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~')
      return
    }
    this.loading = true
    this.totalItems = fileList.length
    this.processedItems = 0
    try {
      await FileProcessorUtil.processFilesConcurrently(
        fileList, PathUtils.appContext!, PathUtils.videoPath, PathUtils.coverPath, this.video_meta_data_encryption,
        (increment: number) => {
          this.processedItems += increment
        },
        fileFolder
      )
      // 重新加载隐私视频
      await this.loadPrivacyVideos()
      ToolsUtil.showToast(
        `${ToolsUtil.getStringResource($r('app.string.add_time_info').id)}${this.totalItems -
          FileFolderUtil.duplicateVideo}${FileFolderUtil.duplicateVideo > 0 ?
          '重复视频已经智能跳过，跳过视频数：' + FileFolderUtil.duplicateVideo : ''}`
      )
    } catch (error) {
      ToolsUtil.showToast('处理过程中发生意外错误:' + error)
    } finally {
      this.loading = false
    }
  }

  closePrivacyMode() {
    PrivacySpaceUtil.setPrivacyMode(false)
  }

  async aboutToAppear(): Promise<void> {
    await this.loadPrivacyVideos()
    PrivacySpaceUtil.setPrivacyMode(true)
  }

  async clickItem(item: VideoMetadata | undefined, choosePlayer: string) {
    if (this.searchValue) {
      setTimeout(() => {
        AppStorage.setOrCreate('searchValue', this.searchValue)
        this.searchValue = ''
      }, 500)
    }
    await SelectFileUtil.isFileExist(item?.uri!, true) ?
      ToolsUtil.routerWhere(this.pathStack, choosePlayer, item!,
        this.video_meta_data_encryption) :
      await this.deleteItem(item!.uri, item!.date)
  }

  async deleteItem(uri: string, date: string) {
    // ORM 改造：使用 uri 作为唯一标识删除，避免依赖可能重复或不稳定的 time/date 字段
    const privacyRepo = PrivacyVideoRepository.getInstance()
    const entities = await privacyRepo.query().where({ uri: uri }).find()
    if (entities.length > 0) {
      await privacyRepo.delete(entities[0])
      console.info(`[PrivacySpace] 删除隐私视频成功: ${uri}`)
    } else {
      console.warn(`[PrivacySpace] 未找到要删除的隐私视频: ${uri}`)
    }
    // 同步更新本地数据源，保证 UI 即时响应（即使 ORM 删除失败也不阻塞 UI 回退）
    const deleteIndex = this.video_meta_data_encryption.findIndex(i => i.date === date)
    if (deleteIndex !== -1) {
      this.videoDataSource.deleteData(deleteIndex)
      this.video_meta_data_encryption = this.video_meta_data_encryption.filter(i => i.date !== date)
    }
  }

  @Builder
  VideoItemBuilder(item: VideoMetadata) {
    VideoListItem({
      item: item,
      delMultipleList: this.delMultipleList
    }).backgroundColor($r('app.color.start_window_background')).reuseId(`VideoListItem#${item.uri}`).borderRadius(16)
  }

  build() {
    NavDestination() {
      Column() {
        if (this.video_meta_data_encryption.length == 0 && !this.loading) {
          Row() { //顶栏
            Column() {
              Text($r('app.string.nothing')).fontSize(25).fontWeight(FontWeight.Bold)
              Text($r('app.string.privacy_space_info'))
                .fontSize(15)
                .textAlign(TextAlign.Center)
                .fontWeight(FontWeight.Lighter)
                .margin({ top: 20 })
            }
          }.height('100%')
          .animation({ duration: 150, curve: Curve.Ease })
        }

        SearchComponent({
          controller: this.searchController,
          searchValue: this.searchValue,
          onChange: async () => {
            if (this.searchValue === '') {
              await this.loadPrivacyVideos()
            } else {
              const newVideoList = SelectFileUtil.getItemFromSearch(
                this.video_meta_data_encryption,
                this.searchValue,
              )
              this.videoDataSource.updateData(newVideoList)
            }
          },
          onEditChange: (isEditing: boolean) => {
            animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
              this.is_edit = isEditing
            })
          }
        }).padding({ left: 10, right: 10 })
        if (this.loading) {
          ImportProgressBuilder({ processedItems: this.processedItems, totalItems: this.totalItems })
        }
        List({ scroller: this.listScroller, space: 10 }) {
          LazyForEach(this.videoDataSource, (item: VideoMetadata) => {
            ListItem() {
              if (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY) {
                this.VideoItemBuilder(item)
              } else {
                VideoCardItem({
                  item: item,
                  delMultipleList: this.delMultipleList
                })
                  .width('95%')
                  .reuseId(`VideoCardItem#${item.uri}`)
                  .backgroundColor(Setting.backgroundImageSrc.length > 0 ?
                    $r('app.color.start_window_background_blur') :
                    $r('app.color.start_window_background'))
                  .borderRadius(16)
                  .height('auto')
              }
            }
            .width('100%')
            .height('auto')
            .onClick(async () => {
              await this.clickItem(item, VideoOperateUtil.getPlayerNavigationAddress(Setting.defaultPlayerEngine))
            })
            .bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress,
              {
                backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                preview: VideoItemPreviewBuilder(item),
                previewAnimationOptions: { scale: [1.0, 0.95], hoverScale: [1.0, 1.2] },
                layoutRegionMargin: {
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 4
                },
                hapticFeedbackMode: HapticFeedbackMode.ENABLED,
                mask: true
              })
            .bindContextMenu(this.MenuBuilder(item), ResponseType.RightClick,
              {
                backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                preview: VideoItemPreviewBuilder(item),
                previewAnimationOptions: { scale: [1.0, 0.95], hoverScale: [1.0, 1.2] },
                layoutRegionMargin: {
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 4
                },
                mask: true
              })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
            .swipeAction({
              end: this.itemEnd(item),
              edgeEffect: SwipeEdgeEffect.Spring
            })
          }, (item: VideoMetadata) => item.date + item.title + item.last_play + item.size.toString() + item.time)
        }
        .fadingEdge(true)
        .clip(false)
        .cachedCount(3)
        .lanes(this.list_line)
        .layoutWeight(1)
        .padding({ left: 10, right: 10 })
        .width('100%')
        .height('auto')
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
        .chainAnimation(true)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        const width = Number(newValue.width)
        const base = Math.floor(width / 500)
        this.list_line = Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY
          ? base + 1
          : base + 2
      })
    }
    .onWillDisappear(() => {
      this.closePrivacyMode()
    })
    .onShown(async () => {
      await this.loadPrivacyVideos()
      if (DataSyncUtil.lastPlayVideoIndex >= 0) {
        this.listScroller.scrollToIndex(DataSyncUtil.lastPlayVideoIndex)
        DataSyncUtil.lastPlayVideoIndex = -1
      }
      const value: string | undefined = AppStorage.get('searchValue')
      if (value) {
        this.searchValue = value
        AppStorage.set('searchValue', '')
      }
    })
    .title($r('app.string.privacy_space'))
    .menus(this.NavigationMenus)
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .backdropBlur(Setting.backgroundDropBlur)
    .onBackPressed(() => {
      if (this.searchValue.length > 0) {
        this.searchValue = ''
        return true
      } else {
        return false
      }
    })
    .blur(Privacy.isPrivacyBackground ? PRIVACY_BACKGROUND_BLUR_AMOUNT : NO_BLUR_AMOUNT)
    .onReady(() => {
      const privacySpaceParams = this.pathStack.getParamByName(NavigationAddress.PRIVACY_SPACE)[0] as PrivacySpaceParams
      if (privacySpaceParams?.needGotoSetting) {
        this.isPresent = true
      }
    })
  }

  @Builder
  itemEnd(item: VideoMetadata) {
    Row({ space: 10 }) {
      Stack().width(10)
      SymbolGlyph($r('sys.symbol.arrow_right_folder_circle'))
        .attributeModifier(new SymbolGlyphFancyModifier(28, 40, 40))
        .onClick(async () => {
          await SelectFileUtil.exportFile(item!.uri, item!.title, item!.format, PathUtils.appContext!)
        })
    }.padding({ left: 15, right: 15 }).justifyContent(FlexAlign.SpaceEvenly)
  }
}