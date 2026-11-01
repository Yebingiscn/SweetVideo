import { taskpool } from '@kit.ArkTS'
import NameSortUtil from './NameSortUtil'
import { salmonLogger } from 'salmonlogger'

export class DirectorySortItem {
  name: string
  directory: boolean
  index: number

  constructor(name: string, directory: boolean, index: number) {
    this.name = name
    this.directory = directory
    this.index = index
  }
}

@Concurrent
function sortDirectoryTask(items: DirectorySortItem[]): number[] {
  const collator = NameSortUtil.createCollator()
  items.sort((left, right) => {
    if (left.directory !== right.directory) return left.directory ? -1 : 1
    return collator.compare(left.name, right.name) || left.index - right.index
  })
  return items.map(item => item.index)
}

/** Only names and flags cross the worker boundary, never credentials or URLs. */
export async function sortDirectoryIndices(items: DirectorySortItem[]): Promise<number[]> {
  if (items.length <= 1) return items.map(item => item.index)
  try {
    const indices = await taskpool.execute(new taskpool.Task(sortDirectoryTask, items),
      taskpool.Priority.HIGH) as number[]
    if (indices.length !== items.length || new Set(indices).size !== items.length ||
      indices.some(index => !Number.isInteger(index) || index < 0 || index >= items.length)) {
      throw new Error('Invalid directory sort result')
    }
    return indices
  } catch (_) {
    // Preserve server order on failure; never repeat expensive sorting on the UI thread.
    salmonLogger.addLog('DirectorySort', '后台目录排序失败，保留服务器顺序', true)
    return items.map(item => item.index)
  }
}
