import * as React from "react";
/**
 * Membership tier badge. Hierarchy escalates in hue, fill and glyph: Casual (dashed) < Chat (outline) < Dev (tint) < Founders (tint + double ring).
 * @startingPoint section="Tiers" subtitle="Casual / Chat / Dev / Founders badges" viewport="700x200"
 */
export interface TierBadgeProps {
  /** @default "chat" */
  tier?: "casual" | "chat" | "dev" | "sponsor";
  /** @default "md" */
  size?: "sm" | "md";
  /** Mono text-only label for IDE footers (DEV, FOUNDERS). */
  compact?: boolean;
  style?: React.CSSProperties;
}
export declare const TIERS: Record<string, { label: string; icon: string; c: string; b: string; bg: string; ring: string | null; price: string }>;
export declare function TierBadge(props: TierBadgeProps): JSX.Element;
