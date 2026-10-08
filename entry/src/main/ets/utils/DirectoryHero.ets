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
  @Trace infoFontSize: number

  constructor(folder: FileFolder, cover: DirectoryRect, title: DirectoryRect, fontSize: number,
    info: DirectoryRect, infoFontSize: number, childFolderCount: number, titleMaxLines: number) {
    this.folder = folder
    this.coverX = cover.x
    this.coverY = cover.y
    this.coverWidth = cover.width
    this.coverHeight = cover.height
    this.titleX = title.x
    this.titleY = title.y
    // 固定字形排版，只缩放绘制结果，避免动画中的字号和宽度变化触发临界换行。
    this.titleScale = fontSize / this.titleFontSize
    this.titleWidth = title.width / this.titleScale
    this.titleMaxLines = titleMaxLines
    this.childFolderCount = childFolderCount
    this.infoX = info.x
    this.infoY = info.y
    this.infoWidth = info.width
    this.infoFontSize = infoFontSize
  }

  moveTo(cover: DirectoryRect, title: DirectoryRect, fontSize: number,
    info: DirectoryRect, infoFontSize: number, titleMaxLines: number): void {
    this.coverX = cover.x
    this.coverY = cover.y
    this.coverWidth = cover.width
    this.coverHeight = cover.height
    this.titleX = title.x
    this.titleY = title.y
    this.titleScale = fontSize / this.titleFontSize
    this.titleWidth = title.width / this.titleScale
    this.titleMaxLines = titleMaxLines
    this.infoX = info.x
    this.infoY = info.y
    this.infoWidth = info.width
    this.infoFontSize = infoFontSize
  }
}
