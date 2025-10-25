//@ts-ignore
import lib from 'libsubtitles.so';
import { SrtLine } from './models/SrtLine';

export class ParseSrt {
  private readonly instance;

  constructor(path: string) {
    this.instance = new lib.ParseSrt(path);
  }

  init(): Promise<void> {
    return this.instance.init();
  }

  async readLines(): Promise<SrtLine[]> {
    return this.instance.readLines();
  }
}