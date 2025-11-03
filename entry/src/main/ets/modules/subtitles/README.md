# subtitles

## 简介

[subtitles]，是一个 OpenHarmony/HarmonyOS 字幕文件解析库，基于 rsubs-lib 开发，支持使用 API12 以上。

## 下载安装

```shell
ohpm install @dove/subtitles
```

## 接口和使用

### 转换ass字幕文件
```typescript
export declare class ParseAss {
  constructor(path: string)
  init(): Promise<void> //必须先执行初始化进行解析
  readEvents(): Promise<Array<AssEvent>>
  readFonts(): Promise<Array<string>>
  readGraphics(): Promise<Array<string>>
  readStyles(): Promise<Array<AssStyle>>
}
```

### 转换srt字幕文件

```typescript
export declare class ParseSrt {
  constructor(path: string)
  init(): Promise<void> //必须先执行初始化进行解析
  readLines(): Promise<Array<SrtLine>>
}
```

### 转换vtt字幕文件

```typescript
export declare class ParseVtt {
  constructor(path: string)
  init(): Promise<void> //必须先执行初始化进行解析
  readLines(): Promise<Array<VttLine>>
  readRegions(): Promise<Array<VttRegion>>
  readStyles(): Promise<Array<VttStyle>>
}
```