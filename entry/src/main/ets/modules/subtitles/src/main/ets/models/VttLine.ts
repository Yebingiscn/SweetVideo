export class VttLine {
  identifier?: string;
  startTimestampMillis: number;
  endTimestampMillis: number;
  settings: Record<string, string | undefined | null>;
  text: string;
}