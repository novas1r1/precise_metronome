/**
 * Glass panel with optional title row
 * @startingPoint section="Core" subtitle="Glass panel with optional title row" viewport="700x200"
 */
export interface CardProps {
  title?: string;
  action?: React.ReactNode;
  solid?: boolean;
  padding?: number | string;
  glow?: boolean;
  children?: React.ReactNode;
}
export function Card(props: CardProps): JSX.Element;
