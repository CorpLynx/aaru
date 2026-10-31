export interface AmbientStatusProps {
  /** @default true */
  generating?: boolean;
  /** tok/s → Steady (<15), Fast (15–40), Instant (>40). */
  speed?: number;
  /** onboard → "Onboard engine", boost → "Boost engine". @default "boost" */
  engine?: "onboard" | "boost" | null;
  /** @default "Writing" */
  verb?: string;
  /** Show the raw number instead of the word. */
  showSpeed?: boolean;
  /** px. @default 13 */
  size?: number;
  style?: React.CSSProperties;
}
export declare function AmbientStatus(props: AmbientStatusProps): JSX.Element;
