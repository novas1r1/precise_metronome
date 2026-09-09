/** Modal or bottom sheet */
export interface DialogProps {
  open: boolean;
  onClose: () => void;
  title?: string;
  footer?: React.ReactNode;
  sheet?: boolean;
  children?: React.ReactNode;
}
export function Dialog(props: DialogProps): JSX.Element;
