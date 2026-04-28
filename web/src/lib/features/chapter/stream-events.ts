import { normalizeOptions } from '$lib/features/chapter/assistant-content';

export type AssistantEvent =
	| {
			type: 'ready';
	  }
	| {
			type: 'delta';
			delta: string;
	  }
	| {
			type: 'options';
			options: string[];
	  }
	| {
			type: 'done';
			sessionId: string | null;
	  }
	| {
			type: 'error';
			message: string;
	  };

type StreamPayload = {
	type: 'ready' | 'delta' | 'options' | 'done' | 'error';
	sessionId?: string;
	delta?: string;
	options?: string[];
	message?: string;
};

function parseEventChunk(chunk: string): AssistantEvent | null {
	const dataLines = chunk
		.split('\n')
		.filter((line) => line.startsWith('data:'))
		.map((line) => line.slice(5).trim())
		.filter(Boolean);

	if (dataLines.length === 0) {
		return null;
	}

	let payload: StreamPayload;
	try {
		payload = JSON.parse(dataLines.join('\n')) as StreamPayload;
	} catch {
		return null;
	}

	switch (payload.type) {
		case 'delta':
			return { type: 'delta', delta: payload.delta ?? '' };
		case 'options':
			return { type: 'options', options: normalizeOptions(payload.options) };
		case 'done':
			return { type: 'done', sessionId: payload.sessionId?.trim() || null };
		case 'error':
			return { type: 'error', message: payload.message || '流式请求失败' };
		case 'ready':
			return { type: 'ready' };
		default:
			return null;
	}
}

export async function consumeAssistantStream(
	stream: ReadableStream<Uint8Array>,
	onEvent: (event: AssistantEvent) => void
) {
	const reader = stream.getReader();
	const decoder = new TextDecoder();
	let buffer = '';

	while (true) {
		const { value, done } = await reader.read();
		if (done) {
			break;
		}

		buffer += decoder.decode(value, { stream: true });
		const chunks = buffer.split('\n\n');
		buffer = chunks.pop() ?? '';

		for (const chunk of chunks) {
			const event = parseEventChunk(chunk);
			if (event) {
				onEvent(event);
			}
		}
	}

	if (buffer.trim()) {
		const event = parseEventChunk(buffer);
		if (event) {
			onEvent(event);
		}
	}
}
