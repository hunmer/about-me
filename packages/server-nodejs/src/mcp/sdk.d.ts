/**
 * @modelcontextprotocol/sdk 的类型声明
 *
 * SDK 未提供 main/types 字段（仅 exports 子路径导出），
 * 本项目的 moduleResolution: node 无法解析，故在此声明用到的最小 API 面。
 * 运行时通过 CommonJS 子路径 require 加载 SDK 的 dist/cjs 构建。
 */

declare module '@modelcontextprotocol/sdk/server/index.js' {
  export class Server {
    constructor(
      serverInfo: { name: string; version: string },
      options: { capabilities: { tools?: Record<string, unknown> } },
    );
    setRequestHandler(
      schema: unknown,
      handler: (request: any, extra: any) => Promise<any>,
    ): void;
    connect(transport: unknown): Promise<void>;
    close(): Promise<void>;
  }
}

declare module '@modelcontextprotocol/sdk/server/streamableHttp.js' {
  export class StreamableHTTPServerTransport {
    constructor(options: { sessionIdGenerator?: (() => string) | undefined });
    handleRequest(req: any, res: any, body?: unknown): Promise<void>;
    close(): Promise<void>;
  }
}

declare module '@modelcontextprotocol/sdk/types.js' {
  export const ListToolsRequestSchema: object;
  export const CallToolRequestSchema: object;
}
