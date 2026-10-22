import * as React from "react";
/**
 * Plan card for pricing and account screens.
 * @startingPoint section="Tiers" subtitle="Four-tier plan picker" viewport="1100x420"
 */
export interface TierCardProps {
  /** @default "chat" */
  tier?: "casual" | "chat" | "dev" | "sponsor";
  /** Overrides the default price label. */
  price?: string;
  features?: string[];
  current?: boolean;
  /** Sponsor only: 0–1 hardware-fund progress. */
  fundProgress?: number;
  /** Button label; hidden when absent and not current. */
  cta?: string;
  onSelect?: () => void;
  style?: React.CSSProperties;
}
export declare function TierCard(props: TierCardProps): JSX.Element;
