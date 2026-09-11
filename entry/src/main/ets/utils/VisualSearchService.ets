import { taskpool } from '@kit.ArkTS'
import { deviceInfo } from '@kit.BasicServicesKit'
import lazy { visualSearchTask } from './VisualSearchTask'
import { VisualSearchResult } from './GlobalSearchModel'

export class VisualSearchService {
  private static runner: taskpool.SequenceRunner = new taskpool.SequenceRunner(taskpool.Priority.LOW)

  static isSupported(): boolean {
    return deviceInfo.sdkApiVersion >= 26 &&
      ['phone', 'tablet', '2in1'].includes(deviceInfo.deviceType) &&
      canIUse('SystemCapability.AI.Vision.VisionBase')
  }

  static async search(paths: string[], manifestPath: string, query: string,
    onProgress: (completed: number, total: number) => void): Promise<VisualSearchResult> {
    if (!VisualSearchService.isSupported()) {
      throw new Error('当前设备不支持画面搜索')
    }
    const task = new taskpool.Task(visualSearchTask, paths, manifestPath, query)
    task.onReceiveData(onProgress)
    // One queue across page instances prevents overlapping init/insert/search/release.
    return await VisualSearchService.runner.execute(task) as VisualSearchResult
  }
}
