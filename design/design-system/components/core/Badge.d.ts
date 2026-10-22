import * as React from "react";
export interface BadgeProps {
  /** Semantic tone. cipher = encrypted/local only; ember = live compute only. @default "neutral" */
  tone?: "neutral" | "cipher" | "ember" | "signal" | "caution" | "fault";
  icon?: string;
  /** Mono uppercase-style system label. */
  mono?: boolean;
  /** sm 20px, md 24px. @default "md" */
  size?: "sm" | "md";
  style?: React.CSSProperties;
  children?: React.ReactNode;
}
export declare function Badge(props: BadgeProps): JSX.Element;
