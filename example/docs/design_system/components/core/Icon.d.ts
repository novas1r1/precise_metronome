/** Lucide-style stroke icon (subset) */
export interface IconProps {
  name: 'play' | 'pause' | 'plus' | 'minus' | 'chevron-down' | 'x' | 'settings' | 'trending-up' | 'repeat' | 'check' | 'volume' | 'info' | 'rotate-ccw';
  size?: number;
  stroke?: number;
}
export function Icon(props: IconProps): JSX.Element;
