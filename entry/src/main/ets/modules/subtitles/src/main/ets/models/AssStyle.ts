import { Alignment } from './Alignment';

export class AssStyle {
  name: string;
  fontName: string;
  fontSize: number;
  primaryColor?: string;
  secondaryColor?: string;
  outlineColor?: string;
  backColor?: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  strikeout: boolean;
  scaleX: number;
  scaleY: number;
  spacing: number;
  angle: number;
  borderStyle: number;
  outline: number;
  shadow: number;
  alignment: Alignment;
  marginLeft: number;
  marginRight: number;
  marginTop: number;
  marginBottom: number;
  encoding: number;
}