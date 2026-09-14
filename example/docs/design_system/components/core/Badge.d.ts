/** Status pill (mono by default) */
export interface BadgeProps {
  tone?: 'neutral' | 'accent' | 'positive' | 'warning' | 'info';
  mono?: boolean;
  dot?: boolean;
  children: React.ReactNode;
}
export function Badge(props: BadgeProps): JSX.Element;
