import { Want } from '@kit.AbilityKit'
import { FormExtensionAbility, formBindingData, formInfo } from '@kit.FormKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { VideoFormBinding, VideoFormData } from './VideoFormData'

export default class VideoFormAbility extends FormExtensionAbility {
  private bindings: Map<string, VideoFormBinding> = new Map()

  onAddForm(want: Want): formBindingData.FormBindingData {
    const id = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string
    const dimension = Number(want.parameters?.[formInfo.FormParam.DIMENSION_KEY] ?? 2)
    const binding = new VideoFormBinding(this.context, dimension)
    this.bindings.get(id)?.close()
    this.bindings.set(id, binding)
    return binding.data
  }

  onUpdateForm(formId: string): void {
    VideoFormData.update(this.context, formId).catch(() => {
      hilog.warn(0, 'VideoForm', 'Unable to refresh card')
    })
  }

  onRemoveForm(formId: string): void {
    this.bindings.get(formId)?.close()
    this.bindings.delete(formId)
  }

  onSizeChanged(formId: string, newDimension: formInfo.FormDimension, newRect: formInfo.Rect): void {
    VideoFormData.update(this.context, formId, newDimension).catch(() => {
      hilog.warn(0, 'VideoForm', 'Unable to resize card')
    })
  }

  onStop(): void {
    this.bindings.forEach(binding => binding.close())
    this.bindings.clear()
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY
  }
}
