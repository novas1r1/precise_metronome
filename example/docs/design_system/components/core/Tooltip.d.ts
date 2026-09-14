/** Hover label */
export interface TooltipProps {
  label: string;
  side?: 'top' | 'bottom';
  children: React.ReactNode;
}
export function Tooltip(props: TooltipProps): JSX.Element;
