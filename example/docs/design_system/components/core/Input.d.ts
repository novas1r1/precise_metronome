/** Text/number input with tracked label and unit */
export interface InputProps {
  label?: string;
  hint?: string;
  unit?: string;
  error?: string;
  value?: string | number;
  placeholder?: string;
  type?: string;
  onChange?: (e: React.ChangeEvent<HTMLInputElement>) => void;
}
export function Input(props: InputProps): JSX.Element;
