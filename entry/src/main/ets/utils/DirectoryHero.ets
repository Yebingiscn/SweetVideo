import { FileFolder } from '../interfaces/FileFolderInterface'

export interface DirectoryRect {
  x: number
  y: number
  width: number
  height: number
}

// 只保留过渡中的封面、标题和数量信息，不复制整页或虚拟列表。
@ObservedV2
export default class DirectoryHero {
  folder: FileFolder
  @Trace contentHidden: boolean = true
  @Trace coverX: number
  @Trace coverY: number
  @Trace coverWidth: number
  @Trace coverHeight: number
  readonly coverBaseWidth: number
  readonly coverBaseHeight: number
  @Trace transformCover: boolean = false
  @Trace coverScaleX: number = 1
  @Trace coverScaleY: number = 1
  @Trace titleX: number
  @Trace titleY: number
  @Trace titleWidth: number
  readonly titleFontSize: number = 22
  @Trace titleScale: number
  @Trace titleMaxLines: number
  childFolderCount: number
  @Trace infoX: number
  @Trace infoY: number
  @Trace infoWidth: number
  readonly infoFontSize: number = 13
  @Trace infoScale: number
  readonly infoBaseWidth: number
  private sourceInfoSingleLine: boolean
  @Trace transformInfo: boolean = false

  constructor(folder: FileFolder, cover: DirectoryRect, title: DirectoryRect, fontSize: number,
    info: DirectoryRect, infoFontSize: number, childFolderCount: number, titleMaxLines: number) {
    this.folder = folder
    this.coverX = cover.x
    this.coverY = cover.y
    this.coverWidth = cover.width
    this.coverHeight = cover.height
    this.coverBaseWidth = cover.width
    this.coverBaseHeight = cover.height
    this.titleX = title.x
    this.titleY = title.y
    // 固定字形排版，只缩放绘制结果，避免动画中的字号和宽度变化触发临界换行。
    this.titleScale = fontSize / this.titleFontSize
    this.titleWidth = title.width / this.titleScale
    this.titleMaxLines = titleMaxLines
    this.childFolderCount = childFolderCount
    this.infoX = info.x
    this.infoY = info.y
    this.infoScale = infoFontSize / this.infoFontSize
    this.infoWidth = info.width / this.infoScale
    this.infoBaseWidth = this.infoWidth
    this.sourceInfoSingleLine = info.height < infoFontSize * 1.8
  }

  prepareMove(cover: DirectoryRect, info: DirectoryRect, infoFontSize: number): void {
    // 同比例封面用固定画布缩放；不同比例保留原来的裁剪，避免把宽封面拉成方形。
    this.transformCover = Math.abs(cover.width / cover.height - this.coverBaseWidth / this.coverBaseHeight) < 0.01
    this.transformInfo = this.sourceInfoSingleLine && info.height < infoFontSize * 1.8
  }

  moveTo(cover: DirectoryRect, title: DirectoryRect, fontSize: number,
    info: DirectoryRect, infoFontSize: number, titleMaxLines: number): void {
    this.coverX = cover.x
    this.coverY = cover.y
    this.coverWidth = cover.width
    this.coverHeight = cover.height
    this.coverScaleX = cover.width / this.coverBaseWidth
    this.coverScaleY = cover.height / this.coverBaseHeight
    this.titleX = title.x
    this.titleY = title.y
    this.titleScale = fontSize / this.titleFontSize
    this.titleWidth = title.width / this.titleScale
    this.titleMaxLines = titleMaxLines
    this.infoX = info.x
    this.infoY = info.y
    this.infoScale = infoFontSize / this.infoFontSize
    this.infoWidth = info.width / this.infoScale
  }
}
