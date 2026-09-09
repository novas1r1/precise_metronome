/** Dropdown select on glass */
export interface SelectProps {
  label?: string;
  value: string | number;
  options: { value: string | number; label: string }[];
  onChange: (v: string | number) => void;
  valueStyle?: React.CSSProperties;
}
export function Select(props: SelectProps): JSX.Element;
