import { FileFolder } from '../interfaces/FileFolderInterface'

// 纯数据操作：不删除条目或媒体，不依赖界面和数据库。
export default class FolderHierarchy {
  static createId(folders: FileFolder[]): string {
    const used = new Set(folders.map(folder => folder.date))
    let candidate = Date.now()
    while (used.has(candidate.toString())) {
      candidate++
    }
    return candidate.toString()
  }

  static repair(source: FileFolder[]): FileFolder[] {
    const folders: FileFolder[] = source.map((folder): FileFolder => ({
      name: folder.name, date: folder.date, parent_date: folder.parent_date ?? null,
      video_list: folder.video_list
    }))
    const counts = new Map<string, number>()
    folders.forEach(folder => counts.set(folder.date, (counts.get(folder.date) ?? 0) + 1))
    const used = new Set(folders.map(folder => folder.date))
    const seen = new Set<string>()
    let nextId = Date.now()
    for (const folder of folders) {
      const originalId = folder.date
      if (!originalId || seen.has(originalId)) {
        while (used.has(nextId.toString())) { nextId++ }
        folder.date = nextId.toString()
        used.add(folder.date)
        nextId++
      }
      seen.add(originalId)
      // 重复 ID 的父归属无法可靠推断，移回根目录交由用户整理。
      if (!folder.parent_date || !counts.has(folder.parent_date) ||
        (counts.get(folder.parent_date) ?? 0) > 1 || folder.parent_date === folder.date) {
        folder.parent_date = null
      }
    }
    const byId = new Map<string, FileFolder>()
    folders.forEach(folder => byId.set(folder.date, folder))
    const completed = new Set<string>()
    for (const folder of folders) {
      const path = new Set<string>()
      let current: FileFolder | undefined = folder
      while (current && !completed.has(current.date)) {
        if (path.has(current.date)) {
          current.parent_date = null
          break
        }
        path.add(current.date)
        current = current.parent_date ? byId.get(current.parent_date) : undefined
      }
      path.forEach(id => completed.add(id))
    }
    const home = folders.find(folder => folder.name === '首页')
    if (home) { home.parent_date = null }
    return folders
  }

  static descendants(folders: FileFolder[], folderDate: string): Set<string> {
    const children = new Map<string, string[]>()
    folders.forEach(folder => {
      if (folder.parent_date !== null) {
        if (!children.has(folder.parent_date)) { children.set(folder.parent_date, []) }
        children.get(folder.parent_date)!.push(folder.date)
      }
    })
    const visited = new Set<string>()
    const stack: string[] = [folderDate]
    while (stack.length > 0) {
      const id = stack.pop()!
      if (visited.has(id)) { continue }
      visited.add(id)
      stack.push(...(children.get(id) ?? []))
    }
    return visited
  }

  static flatten(folders: FileFolder[], expanded?: Set<string>): FileFolder[] {
    const children = new Map<string | null, FileFolder[]>()
    for (const folder of folders) {
      const parent = folder.parent_date ?? null
      if (!children.has(parent)) { children.set(parent, []) }
      children.get(parent)!.push(folder)
    }
    const result: FileFolder[] = []
    const visited = new Set<FileFolder>()
    const walk = (roots: FileFolder[]): void => {
      const stack = roots.slice().reverse()
      while (stack.length > 0) {
        const folder = stack.pop()!
        if (visited.has(folder)) { continue }
        visited.add(folder)
        result.push(folder)
        if (!expanded || expanded.has(folder.date)) {
          const items = children.get(folder.date) ?? []
          for (let i = items.length - 1; i >= 0; i--) { stack.push(items[i]) }
        }
      }
    }
    walk(children.get(null) ?? [])
    // 完整列表保留异常孤立条目；折叠视图不能把隐藏的子目录补回。
    if (!expanded) { folders.forEach(folder => { if (!visited.has(folder)) { walk([folder]) } }) }
    return result
  }
}
