/**
 * Glass dial with expanding beat rings and bar dots
 * @startingPoint section="Core" subtitle="Glass dial with expanding beat rings and bar dots" viewport="700x200"
 */
export interface BeatRingProps {
  beat?: number | null;
  beatsPerBar?: number;
  accent?: boolean;
  size?: number;
  direction?: 'up' | 'down';
  children?: React.ReactNode;
}
export function BeatRing(props: BeatRingProps): JSX.Element;
