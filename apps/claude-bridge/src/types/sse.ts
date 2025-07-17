export interface SSEEvent {
	type: string;
	data: string | object;
	id?: string;
	retry?: number;
}

export interface ParsedSSEEvent {
	type: string;
	data: unknown;
	[key: string]: unknown;
}

export interface SSEData {
	type?: string;
	data?: unknown;
	[key: string]: unknown;
}

export interface ToolCall {
	id: string;
	type: string;
	function: {
		name: string;
		arguments: string;
	};
}

export interface AnthropicMessage {
	role: string;
	content?: string;
	tool_calls?: ToolCall[];
	tool_call_id?: string;
	tool_result_id?: string;
}

export interface PendingRequest {
	url: string;
	method: string;
	headers: Record<string, string>;
	body: unknown;
	abortSignal?: AbortSignal;
	timestamp: number;
}

export interface ParsedResponse {
	timestamp: number;
	status_code: number;
	headers: Record<string, string>;
	body?: unknown;
	body_raw?: string;
}

export interface ErrorWithCode extends Error {
	code?: string | number;
	status?: number;
	cause?: unknown;
}
