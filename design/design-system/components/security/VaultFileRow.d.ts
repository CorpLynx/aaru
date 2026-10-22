export interface VaultFileRowProps {
  name: string;
  /** e.g. "2.4 MB · 312 chunks indexed". Hidden while encrypting and in dense mode. */
  meta?: string;
  /** Neutral white progress while encrypting; Cipher only once stored + indexed. @default "sealed" */
  status?: "encrypting" | "sealed" | "error";
  /** 0–1, used while encrypting. */
  progress?: number;
  /** Signal-blue outline = document is in this chat's RAG context. */
  inContext?: boolean;
  /** @default "doc" */
  kind?: "doc" | "code";
  dense?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
}
export declare function VaultFileRow(props: VaultFileRowProps): JSX.Element;
