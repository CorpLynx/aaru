import * as React from "react";
/**
 * Off-white primary, bordered secondary, ghost and danger buttons. Color is reserved for state, so primary is neutral.
 * @startingPoint section="Core" subtitle="Primary / secondary / ghost / danger" viewport="700x200"
 */
export interface ButtonProps {
  /** One primary per view. @default "secondary" */
  variant?: "primary" | "secondary" | "ghost" | "danger";
  /** sm = 28px IDE, md = 36px web, lg = 44px mobile. @default "md" */
  size?: "sm" | "md" | "lg";
  /** Lucide icon name without the "icon-" prefix, e.g. "plus". */
  icon?: string;
  iconRight?: string;
  disabled?: boolean;
  fullWidth?: boolean;
  type?: "button" | "submit";
  onClick?: (e: React.MouseEvent) => void;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}
export declare function Button(props: ButtonProps): JSX.Element;
