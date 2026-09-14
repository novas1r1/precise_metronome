/** Transient pill notification */
export interface ToastProps {
  tone?: 'neutral' | 'positive' | 'accent' | 'info';
  icon?: React.ReactNode;
  children: React.ReactNode;
}
export function Toast(props: ToastProps): JSX.Element;
