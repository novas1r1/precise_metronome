/** Range slider with glowing coral fill */
export interface SliderProps {
  value: number;
  min?: number;
  max?: number;
  step?: number;
  onChange: (v: number) => void;
  label?: string;
  format?: (v: number) => string;
}
export function Slider(props: SliderProps): JSX.Element;
