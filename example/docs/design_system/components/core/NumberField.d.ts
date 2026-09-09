/**
 * Stepper for BPM / bars / step values
 * @startingPoint section="Core" subtitle="Stepper for BPM / bars / step values" viewport="700x200"
 */
export interface NumberFieldProps {
  label?: string;
  value: number;
  onChange: (v: number) => void;
  min?: number;
  max?: number;
  step?: number;
  unit?: string;
  size?: 'md' | 'lg';
}
export function NumberField(props: NumberFieldProps): JSX.Element;
