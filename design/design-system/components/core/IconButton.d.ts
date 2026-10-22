import * as React from "react";
export interface IconButtonProps {
  /** Lucide icon name without prefix. */
  icon: string;
  /** Accessible label; also shown as native title. */
  label: string;
  /** sm 24px (IDE), md 32px (web), lg 44px (mobile). @default "md" */
  size?: "sm" | "md" | "lg";
  active?: boolean;
  disabled?: boolean;
  onClick?: (e: React.MouseEvent) => void;
  style?: React.CSSProperties;
}
export declare function IconButton(props: IconButtonProps): JSX.Element;
