/** Grid of beat/subdivision slots; tap to toggle accents */
export interface AccentGridProps {
  beats?: number;
  subdiv?: number;
  accents?: number[];
  onChange: (accents: number[]) => void;
  label?: string;
  current?: number | null;
}
export function AccentGrid(props: AccentGridProps): JSX.Element;
