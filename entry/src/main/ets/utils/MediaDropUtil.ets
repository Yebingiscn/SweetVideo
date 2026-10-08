import { unifiedDataChannel, uniformTypeDescriptor } from '@kit.ArkData'

export default class MediaDropUtil {
  static readonly allowedTypes: string[] = [uniformTypeDescriptor.UniformDataType.VIDEO,
    uniformTypeDescriptor.UniformDataType.AUDIO]

  static firstMediaUri(records: unifiedDataChannel.UnifiedRecord[]): string | undefined {
    for (const record of records) {
      try {
        const type = record.getType()
        if (!MediaDropUtil.allowedTypes.includes(type)) {
          const descriptor = uniformTypeDescriptor.getTypeDescriptor(type)
          if (!descriptor.belongsTo(uniformTypeDescriptor.UniformDataType.VIDEO) &&
            !descriptor.belongsTo(uniformTypeDescriptor.UniformDataType.AUDIO)) { continue }
        }
        // 类型通过检查后才读取文件 URI；封面图片的 uri 不能作为媒体入口。
        const file = record as unifiedDataChannel.File
        if (typeof file.uri === 'string' && file.uri.trim().length > 0) { return file.uri }
      } catch (_) {
        // 非法类型或损坏记录不影响后面的有效音视频条目。
        continue
      }
    }
    return undefined
  }
}
