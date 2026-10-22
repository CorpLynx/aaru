import * as React from "react";
/**
 * The Seal: Aaru's single zero-knowledge motif — Cipher lock glyph + mono label.
 * @startingPoint section="Security" subtitle="E2EE / Local compute / Key seal badges" viewport="700x220"
 */
export interface SealBadgeProps {
  /** e2ee = encrypted chat/doc, local = on-prem compute, key = key fingerprint. @default "e2ee" */
  variant?: "e2ee" | "local" | "key";
  /** Short fingerprint shown in key variant. */
  keyId?: string;
  /** @default "md" */
  size?: "sm" | "md";
  /** Bare 14px (or 11px sm) lock glyph — history rows, file rows. */
  glyphOnly?: boolean;
  /** Override label text. */
  label?: string;
  style?: React.CSSProperties;
}
export declare function SealBadge(props: SealBadgeProps): JSX.Element;
