import { env } from '$env/dynamic/private';
import { error, json, type RequestHandler } from '@sveltejs/kit';

const actions = {
  start: 'start',
  messages: 'messages'
} as const;

export const POST: RequestHandler = async ({ locals, params, request }) => {
  if (!locals.user || !locals.supabase) {
    return json({ message: '请先登录后再开始体验。' }, { status: 401 });
  }

  const action = actions[params.action as keyof typeof actions];
  if (!action) error(404, '接口不存在');

  const agentUrl = env.AGENT_API_URL?.replace(/\/$/, '');
  if (!agentUrl) error(503, 'AGENT_API_URL 尚未配置。');

  const { data, error: sessionError } = await locals.supabase.auth.getSession();
  const accessToken = data.session?.access_token;
  if (sessionError || !accessToken) {
    return json({ message: '登录状态已失效，请重新登录。' }, { status: 401 });
  }

  let response: Response;
  try {
    response = await fetch(`${agentUrl}/v1/zh/folios/${params.id}/${action}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        ...(action === 'messages' ? { 'Content-Type': 'application/json' } : {})
      },
      body: action === 'messages' ? await request.text() : undefined
    });
  } catch {
    return json({ message: '体验服务暂时不可用，请稍后重试。' }, { status: 502 });
  }

  if (!response.ok || !response.body) {
    const body = (await response.json().catch(() => null)) as { detail?: string } | null;
    return json(
      { message: body?.detail ?? `体验请求失败（${response.status}）` },
      { status: response.status }
    );
  }

  return new Response(response.body, {
    status: response.status,
    headers: {
      'Cache-Control': 'no-cache, no-transform',
      'Content-Type': 'text/event-stream; charset=utf-8',
      'X-Accel-Buffering': 'no'
    }
  });
};
