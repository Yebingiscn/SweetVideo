import { CommonModifier } from '@kit.ArkUI';

export class ShadowModifier extends CommonModifier {
  constructor() {
    super()
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    instance.shadow({ radius: 26, color: $r('app.color.shadow_color') }).backgroundColor('rgba(0, 0, 0, 0.05)')
  }
}

export class ImageFancyModifier implements AttributeModifier<ImageAttribute> {
  private borderRadius: number;
  private width: number | string;
  private height: number | string;

  constructor(borderRadius: number, width: number | string, height: number | string) {
    this.borderRadius = borderRadius;
    this.width = width;
    this.height = height;
  }

  applyNormalAttribute(attr: ImageAttribute): void {
    attr
      .alt($r("app.media.sweet_video_alt"))
      .backgroundImageSize(ImageSize.Cover)
      .borderRadius(this.borderRadius)
      .width(this.width)
      .height(this.height)
      .interpolation(ImageInterpolation.Low);
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
      .height(this.height);
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