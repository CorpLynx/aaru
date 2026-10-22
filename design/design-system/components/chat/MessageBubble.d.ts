export interface MessageBubbleProps {
  /** user = shielded bubble, right-aligned; assistant = unboxed prose. @default "user" */
  role?: "user" | "assistant";
  children?: React.ReactNode;
  /** Adds the 1px Cipher ring ("shielded bubble"). @default true */
  sealed?: boolean;
  /** Shows "sealed · 14:02" under the bubble. */
  time?: string;
  /** Adjusts type size and radius. @default "web" */
  platform?: "web" | "ide" | "mobile";
  style?: React.CSSProperties;
}
export declare function MessageBubble(props: MessageBubbleProps): JSX.Element;
