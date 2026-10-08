import WebDavAddress from './WebDavAddress'
import { WebDavEntry } from '../interfaces/WebDavInterface'
import ToolsUtil from './ToolsUtil.ets'

/** XML event consumer, kept separate so DAV response handling can be tested. */
export default class WebDavListing {
  entries: WebDavEntry[] = []
  private stack: string[] = []
  private text: string[] = []
  private href: string = ''
  private properties: Map<string, string> = new Map()
  private accepted: Map<string, string> = new Map()
  private status: string = ''
  private responseStatus: string = ''
  private seen: Set<string> = new Set()
  private multistatus: boolean = false

  private directoryUrl: string
  private folder: string

  constructor(directoryUrl: string, folder: string) {
    this.directoryUrl = directoryUrl
    this.folder = folder
  }

  start(name: string, namespace: string): void {
    const tag = namespace === 'DAV:' ? name.replace(/^.*:/, '') : ''
    this.stack.push(tag)
    this.text.push('')
    if (tag === 'multistatus' && this.stack.length === 1) this.multistatus = true
    if (tag === 'response') {
      this.href = ''; this.accepted.clear(); this.responseStatus = ''
    }
    if (tag === 'propstat') { this.properties.clear(); this.status = '' }
    if (tag === 'collection' && this.stack.includes('propstat')) this.properties.set('directory', 'true')
  }

  characters(value: string): void {
    if (this.text.length > 0) this.text[this.text.length - 1] += value
  }

  end(): void {
    const tag = this.stack.pop() ?? ''
    const value = (this.text.pop() ?? '').trim()
    if (tag === 'href' && this.stack[this.stack.length - 1] === 'response') this.href = value
    if (tag === 'status') {
      if (this.stack[this.stack.length - 1] === 'propstat') this.status = value
      else if (this.stack[this.stack.length - 1] === 'response') this.responseStatus = value
    }
    if (tag === 'getcontentlength' && this.stack.includes('propstat')) this.properties.set('size', value)
    if (tag === 'resourcetype' && this.stack.includes('propstat') && !this.properties.has('directory')) {
      this.properties.set('directory', 'false')
    }
    if (tag === 'propstat' && /^HTTP\/\S+ 2\d\d(?:\s|$)/.test(this.status)) {
      this.properties.forEach((v: string, k: string) => this.accepted.set(k, v))
    }
    if (tag !== 'response' || !this.multistatus || !this.accepted.has('directory') ||
      (this.responseStatus && !/^HTTP\/\S+ 2\d\d(?:\s|$)/.test(this.responseStatus))) return
    const path = WebDavAddress.child(this.href, this.directoryUrl, this.folder)
    if (!path || this.seen.has(path)) return
    this.seen.add(path)
    const size = Number(this.accepted.get('size') ?? '0')
    this.entries.push({ name: path.substring(path.lastIndexOf('/') + 1), path: path,
      directory: this.accepted.get('directory') === 'true', size: Number.isFinite(size) && size >= 0 ? size : 0 })
  }

  finish(): WebDavEntry[] {
    if (!this.multistatus || this.stack.length !== 0) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_invalid_directory_format').id))
    return this.entries.sort((a: WebDavEntry, b: WebDavEntry) => a.directory !== b.directory ?
      (a.directory ? -1 : 1) : a.name.localeCompare(b.name, 'zh-CN', { numeric: true }))
  }
}
