import { CommonModifier, uiMaterial } from '@kit.ArkUI';
import { ShadowFancy } from '../interfaces/ShadowFancyInterface';
import { hdsEffect } from '@kit.UIDesignKit';
import { deviceInfo, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit';
import { MaterialCapability } from './MaterialCapability';

export class SettingsItemModifier extends CommonModifier {
  constructor() {
    super()
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    instance.backgroundColor($r('app.color.start_window_background_blur'))
      .borderRadius(16)
      .padding({
        right: 15,
        left: 15,
        top: 10,
        bottom: 10
      })
      .margin({ top: 5, bottom: 5 })
  }
}

export class SettingsTitleModifier implements AttributeModifier<TextAttribute> {
  applyNormalAttribute(instance: TextAttribute): void {
    instance.fontSize(17)
      .fontWeight(FontWeight.Medium)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.MARQUEE })
  }
}

export class ShadowModifier extends CommonModifier {
  constructor() {
    super()
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    instance.shadow({ radius: 26, color: $r('app.color.shadow_color') })
      .backgroundColor($r('app.color.start_window_background_blur'))
      .backdropBlur(150)
  }
}

export class ImageFancyModifier implements AttributeModifier<ImageAttribute> {
  private borderRadius: Length | BorderRadiuses | LocalizedBorderRadiuses;
  private width: number | string;
  private height: number | string;

  constructor(borderRadius: Length | BorderRadiuses | LocalizedBorderRadiuses, width: number | string,
    height: number | string) {
    this.borderRadius = borderRadius;
    this.width = width;
    this.height = height;
  }

  applyNormalAttribute(attr: ImageAttribute): void {
    attr
      .alt($r("app.media.sweet_video_alt"))
      .backgroundImageSize(ImageSize.Auto)
      .borderRadius(this.borderRadius)
      .width(this.width)
      .height(this.height)
      .interpolation(ImageInterpolation.Medium)// 用于重采样后的抗锯齿
      .draggable(false)// 禁止长按手势拖动
      .autoResize(true) // 重采样，可减少内存占用
      .opacity(0.98)
      .dynamicRangeMode(DynamicRangeMode.HIGH)
      .contentTransition(ContentTransitionEffect.OPACITY)
  }
}

export class SymbolGlyphFancyModifier implements AttributeModifier<SymbolGlyphAttribute> {
  private fontSize: number;
  private width: number | string;
  private height: number | string;

  constructor(fontSize: number, width: number | string, height: number | string) {
    this.fontSize = fontSize;
    this.width = width;
    this.height = height;
  }

  applyNormalAttribute(attr: SymbolGlyphAttribute): void {
    attr
      .fontSize(this.fontSize)
      .fontColor([$r('app.color.text_color')])
      .width(this.width)
      .height(this.height)
      .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
      .effectStrategy(SymbolEffectStrategy.SCALE)
  }
}

export class ButtonFancyModifier implements AttributeModifier<ButtonAttribute> {
  private width: number | string;
  private height: number | string;

  constructor(width: number | string, height: number | string) {
    this.width = width;
    this.height = height;
  }

  applyNormalAttribute(attr: ButtonAttribute): void {
    attr
      .borderRadius(16)
      .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
      .width(this.width)
      .height(this.height)
      .backgroundColor($r('app.color.start_window_background_blur'))
  }
}

export class MenuFancyModifier extends CommonModifier {
  constructor() {
    super()
  }

  applyNormalAttribute(instance: MenuAttribute): void {
    instance.font({ size: 15, weight: FontWeight.Normal })
  }
}

export const DefaultDialogShadow: ShadowFancy = {
  radius: 26,
  color: $r('app.color.shadow_color'),
  offsetX: 0,
  offsetY: 0
}

@ObservedV2
export class HdsGL {
  @Trace static lightIntensity: number = 10;
  @SuppressWarnings(
    { rules: [SuppressWarningsType.SYSCAP] }) @Trace static illuminatedType: hdsEffect.PointLightIlluminatedType[] =
    [hdsEffect.PointLightIlluminatedType.NONE, hdsEffect.PointLightIlluminatedType.BORDER,
      hdsEffect.PointLightIlluminatedType.CONTENT, hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
      hdsEffect.PointLightIlluminatedType.DEFAULT_FEATHERING_BORDER];
  @SuppressWarnings(
    { rules: [SuppressWarningsType.SYSCAP] }) @Trace static sourceTypes: hdsEffect.PointLightSourceType[] =
    [hdsEffect.PointLightSourceType.NONE, hdsEffect.PointLightSourceType.SOFT, hdsEffect.PointLightSourceType.BRIGHT]
}

export class LightMaterialModifier implements AttributeModifier<CommonAttribute> {
  applyNormalAttribute(instance: CommonAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (MaterialCapability.arkUISupported && MaterialCapability.hdsSupported) {
        instance.systemMaterial(new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THIN,
          applyShadow: true,
          interactive: true,
          lightEffect: {},
        }))
      } else {
        instance.backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
      }
    } else {
      instance.backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
    }
  }
}
