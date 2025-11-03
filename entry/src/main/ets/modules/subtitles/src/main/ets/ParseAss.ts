//@ts-ignore
import * as lib from 'libsubtitles.so';
import { AssEvent } from './models/AssEvent';
import { AssStyle } from './models/AssStyle';
import json from '@ohos.util.json';

export class ParseAss {
  private readonly instance;

  constructor(path: string) {
    this.instance = new lib.ParseAss(path);
  }

  init(): Promise<void> {
    return this.instance.init();
  }

  async readEvents(): Promise<Array<AssEvent>> {
    const item = await this.instance.readEvents()
    console.error('test' + json.stringify(item))
    return this.instance.readEvents();
  }

  readFonts(): Promise<Array<string>> {
    return this.instance.readFonts();
  }

  readGraphics(): Promise<Array<string>> {
    return this.instance.readGraphics();
  }

  readStyles(): Promise<Array<AssStyle>> {
    return this.instance.readStyles();
  }
}