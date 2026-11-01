import { taskpool, util, xml } from '@kit.ArkTS'
import { WebDavEntry } from '../interfaces/WebDavInterface'
import WebDavListing from './WebDavListing'
import NameSortUtil from './NameSortUtil'

/** HTTP and credentials stay with the request owner; only response data enters this task. */
@Concurrent
export function parseWebDavDirectory(text: string, url: string, folder: string): WebDavEntry[] {
  if (/<!DOCTYPE|<!ENTITY/i.test(text)) throw new Error('Unsupported XML declaration')
  const listing = new WebDavListing(url, folder)
  const bytes = new util.TextEncoder().encodeInto(text)
  new xml.XmlPullParser(bytes.buffer as ArrayBuffer, 'UTF-8').parseXml({
    supportDoctype: false,
    ignoreNameSpace: false,
    tokenValueCallbackFunction: (event: xml.EventType, info: xml.ParseInfo): boolean => {
      if (taskpool.Task.isCanceled()) throw new Error('Cancelled')
      if (event === xml.EventType.START_TAG) listing.start(info.getName(), info.getNamespace())
      else if (event === xml.EventType.END_TAG) listing.end()
      else if (event === xml.EventType.TEXT || event === xml.EventType.CDSECT ||
        event === xml.EventType.ENTITY_REFERENCE || event === xml.EventType.WHITESPACE) listing.characters(info.getText())
      return true
    }
  })
  if (taskpool.Task.isCanceled()) throw new Error('Cancelled')
  const entries = listing.finish()
  const collator = NameSortUtil.createCollator()
  entries.sort((left, right) => {
    if (taskpool.Task.isCanceled()) throw new Error('Cancelled')
    if (left.directory !== right.directory) return left.directory ? -1 : 1
    return collator.compare(left.name, right.name)
  })
  return entries
}
