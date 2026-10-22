import * as React from "react";
/**
 * Aaru logo: the Reed rosette mark (six interlaced reed capsules around a hexagonal core) with optional lowercase Geist wordmark.
 * @startingPoint section="Core" subtitle="Reed rosette mark + wordmark" viewport="700x200"
 */
export interface LogoProps {
  /** Mark height in px. Stroke weight auto-thickens at 24px and below. @default 28 */
  size?: number;
  /** lockup = mark + "aaru"; mark = rosette only. @default "lockup" */
  variant?: "lockup" | "mark";
  /** Single color only. @default "currentColor" (inherits; fg-1 by default) */
  color?: string;
  /** Each reed retracts into the core until hidden, then extends back out, one after another around the ring. Use for splash/loading only. Needs tokens/base.css (aaruReed keyframes). @default false */
  animated?: boolean;
  /** Seconds per full cycle. @default 3.2 */
  duration?: number;
  style?: React.CSSProperties;
}
export declare function Logo(props: LogoProps): JSX.Element;
