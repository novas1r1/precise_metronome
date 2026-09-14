/** Toggle with optional label and description */
export interface SwitchProps {
  checked: boolean;
  onChange: (v: boolean) => void;
  label?: string;
  description?: string;
  disabled?: boolean;
}
export function Switch(props: SwitchProps): JSX.Element;
