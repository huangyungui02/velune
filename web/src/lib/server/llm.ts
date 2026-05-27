import { env } from '$env/dynamic/private';

type ChatMessage = {
	role: 'system' | 'user' | 'assistant';
	content: string;
};

export type JsonSchema = {
	type: 'object';
	properties: Record<string, unknown>;
	required?: string[];
	additionalProperties?: boolean;
};

type ChatCompletionResponse = {
	choices?: {
		message?: {
			content?: unknown;
		};
	}[];
	error?: {
		message?: string;
	};
};

const DEFAULT_MODEL = 'qwen3.5-flash';
const DEFAULT_BASE_URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1';

function dashscopeApiKey() {
	const apiKey = env.DASHSCOPE_API_KEY?.trim();
	if (!apiKey) {
		throw new Error('Missing DASHSCOPE_API_KEY.');
	}

	return apiKey;
}

function dashscopeBaseUrl() {
	return (env.DASHSCOPE_BASE_URL || DEFAULT_BASE_URL).trim().replace(/\/+$/, '');
}

function modelExtraBody(model: string) {
	return model.trim().toLowerCase().startsWith('qwen') ? { enable_thinking: false } : {};
}

function textContent(content: unknown) {
	if (typeof content === 'string') {
		return content;
	}

	if (Array.isArray(content)) {
		return content
			.map((item) => {
				if (typeof item === 'string') {
					return item;
				}
				if (item && typeof item === 'object' && 'text' in item) {
					return typeof item.text === 'string' ? item.text : '';
				}
				return '';
			})
			.join('');
	}

	return '';
}

export async function completeJson<T>(
	messages: ChatMessage[],
	{
		model = DEFAULT_MODEL,
		schemaName,
		schema,
		temperature
	}: {
		model?: string;
		schemaName: string;
		schema: JsonSchema;
		temperature: number;
	}
): Promise<T> {
	const extraBody = modelExtraBody(model);
	const response = await fetch(`${dashscopeBaseUrl()}/chat/completions`, {
		method: 'POST',
		headers: {
			authorization: `Bearer ${dashscopeApiKey()}`,
			'content-type': 'application/json'
		},
		body: JSON.stringify({
			model,
			messages,
			temperature,
			...(Object.keys(extraBody).length > 0 ? { extra_body: extraBody } : {}),
			response_format: {
				type: 'json_schema',
				json_schema: {
					name: schemaName,
					strict: true,
					schema
				}
			}
		})
	});

	const payload = (await response.json().catch(() => null)) as ChatCompletionResponse | null;
	if (!response.ok) {
		throw new Error(payload?.error?.message || '大模型请求失败');
	}

	const content = textContent(payload?.choices?.[0]?.message?.content).trim();
	if (!content) {
		throw new Error('大模型返回为空');
	}

	return JSON.parse(content) as T;
}
