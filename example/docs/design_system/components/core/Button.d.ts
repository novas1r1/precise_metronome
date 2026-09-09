/**
 * Primary action button — pill, glass or ghost
 * @startingPoint section="Core" subtitle="Primary action button — pill, glass or ghost" viewport="700x200"
 */
export interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg' | 'xl';
  icon?: React.ReactNode;
  glow?: boolean;
  fullWidth?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  children?: React.ReactNode;
}
export function Button(props: ButtonProps): JSX.Element;
