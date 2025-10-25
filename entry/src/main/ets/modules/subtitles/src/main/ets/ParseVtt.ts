//@ts-ignore
import * as lib from 'libsubtitles.so';
import { VttLine } from './models/VttLine';
import { VttStyle } from './models/VttStyle';
import { VttRegion } from './models/VttRegion';

export class ParseVtt {
  private readonly instance;

  constructor(path: string) {
    this.instance = new lib.ParseVtt(path);
  }

  init(): Promise<void> {
    return this.instance.init();
  }

  readLines(): Promise<VttLine[]> {
    return this.instance.readLines();
  }

  readRegions(): Promise<Array<VttRegion>> {
    return this.instance.readRegions();
  }

  readStyles(): Promise<Array<VttStyle>> {
    return this.instance.readStyles();
  }
}