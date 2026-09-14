/** Round icon-only button */
export interface IconButtonProps {
  size?: 'sm' | 'md' | 'lg';
  variant?: 'secondary' | 'ghost';
  label: string;
  active?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  children: React.ReactNode;
}
export function IconButton(props: IconButtonProps): JSX.Element;
