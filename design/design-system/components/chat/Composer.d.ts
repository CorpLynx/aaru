import * as React from "react";
/**
 * Chat input with attach, Vault, model picker, E2EE seal and send/stop. Ember scan line sweeps the top edge while generating.
 * @startingPoint section="Chat" subtitle="Chat composer — idle / generating, web/IDE/mobile" viewport="760x420"
 */
export interface ComposerProps {
  value?: string;
  onChange?: (value: string) => void;
  /** Enter sends (Shift+Enter newline). */
  onSend?: (value: string) => void;
  /** Esc stops while generating. */
  onStop?: () => void;
  generating?: boolean;
  /** tok/s shown while generating. */
  speed?: number;
  /** @default "Qwen3 235B" */
  model?: string;
  /** When set, shows a Signal "N docs" chip instead of the Vault button. */
  docsCount?: number;
  placeholder?: string;
  /** web 12px radius / ide 8px dense / mobile 24px pill with 44px targets. @default "web" */
  density?: "web" | "ide" | "mobile";
  style?: React.CSSProperties;
}
export declare function Composer(props: ComposerProps): JSX.Element;
