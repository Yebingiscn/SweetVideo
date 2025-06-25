export interface VttSubtitleItem {
  start: string;
  end: string;
  text: string;
}

export interface SrtSubtitleItem {
  id: number; // 序号
  start: string; // 开始时间
  end: string; // 结束时间
  text: string; // 字幕文本
}

export interface AssSubtitleItem {
  layer: number; // 图层
  start: string; // 开始时间
  end: string; // 结束时间
  style: string; // 样式名
  text: string; // 文本
}