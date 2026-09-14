/** Segmented control with sliding thumb */
export interface SegmentedProps {
  options: { value: string | number; label: React.ReactNode; icon?: React.ReactNode }[];
  value: string | number;
  onChange: (v: string | number) => void;
  size?: 'sm' | 'md';
  label?: string;
}
export function Segmented(props: SegmentedProps): JSX.Element;
