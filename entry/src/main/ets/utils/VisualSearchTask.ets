import { VisualSearchIndex } from './VisualSearchIndex'
import { VisualSearchResult } from './GlobalSearchModel'

@Concurrent
export async function visualSearchTask(paths: string[], manifestPath: string,
  query: string): Promise<VisualSearchResult> {
  return await VisualSearchIndex.run(paths, manifestPath, query)
}
