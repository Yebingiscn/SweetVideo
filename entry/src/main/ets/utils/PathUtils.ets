import { common } from '@kit.AbilityKit'
import { fileUri } from '@kit.CoreFileKit'

export class PathUtils {
  private static context: common.UIAbilityContext | null = null
  private static uriPrefixCache: string = ''

  static get sandboxPath(): string {
    return this.context?.filesDir ?? ''
  }

  static get coverPath(): string {
    return `${this.sandboxPath}/`
  }

  static get videoPath(): string {
    return `${this.sandboxPath}/video/`
  }

  static get photoPath(): string {
    return `${this.sandboxPath}/photo/`
  }

  static get subtitlePath(): string {
    return `${this.sandboxPath}/subtitle/`
  }

  static get tempPath(): string {
    return this.context?.tempDir ?? ''
  }

  static get appContext(): common.UIAbilityContext | null {
    return PathUtils.context
  }

  static init(context: common.UIAbilityContext) {
    PathUtils.context = context
  }

  static getUriPrefix(): string {
    if (!PathUtils.uriPrefixCache && PathUtils.sandboxPath) {
      const fullUri = fileUri.getUriFromPath(PathUtils.sandboxPath)
      const match = fullUri.match(/^(file:\/\/[^/]+\/)/)
      if (match) {
        PathUtils.uriPrefixCache = match[1]
      }
    }
    return PathUtils.uriPrefixCache
  }

  static pathToUri(path: string): string {
    const prefix = PathUtils.getUriPrefix()
    if (prefix && path.startsWith('/')) {
      return `${prefix}${path.substring(1)}`
    }
    return fileUri.getUriFromPath(path)
  }

  static videoUri(date: string): string {
    return PathUtils.pathToUri(`${PathUtils.videoPath}${date}`)
  }

  static coverUri(date: string): string {
    return PathUtils.pathToUri(`${PathUtils.coverPath}${date}`)
  }
}