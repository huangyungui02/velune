import { env } from '$env/dynamic/private';
import { error, fail, redirect } from '@sveltejs/kit';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { Actions, PageServerLoad } from './$types';

const LANGUAGES = ['zh', 'en'] as const;
const ASSET_BUCKET = 'avatars';
const MAX_IMAGE_SIZE = 5 * 1024 * 1024;

function text(data: FormData, key: string) {
  return String(data.get(key) ?? '').trim();
}

function optional(data: FormData, key: string) {
  return text(data, key) || null;
}

function checked(data: FormData, key: string) {
  return data.get(key) === 'on';
}

async function requireAdmin(locals: App.Locals) {
  if (!locals.user) redirect(303, '/login?redirectTo=/admin');
  if (!locals.supabase) error(503, 'Supabase 尚未配置。');

  const { data, error: rpcError } = await locals.supabase.rpc('is_admin');
  if (rpcError) error(500, rpcError.message);
  if (!data) error(403, '你没有后台管理权限。');

  return locals.supabase;
}

function databaseFailure(action: string, message: string) {
  return fail(400, { action, message });
}

function image(data: FormData, key: string) {
  const value = data.get(key);
  return value instanceof File && value.size > 0 ? value : null;
}

function publicAssetUrl(supabase: SupabaseClient, path: string | null, version: string) {
  if (!path) return null;
  if (/^https?:\/\//.test(path) || path.startsWith('/')) return path;
  const url = supabase.storage.from(ASSET_BUCKET).getPublicUrl(path).data.publicUrl;
  return `${url}?v=${encodeURIComponent(version)}`;
}

async function uploadImage(
  supabase: SupabaseClient,
  file: File | null,
  path: string,
  action: string
) {
  if (!file) return null;
  if (file.type !== 'image/png') {
    return databaseFailure(action, '图片必须为 PNG 格式。');
  }
  if (file.size > MAX_IMAGE_SIZE) {
    return databaseFailure(action, '图片不能超过 5 MB。');
  }

  const { error: uploadError } = await supabase.storage.from(ASSET_BUCKET).upload(path, file, {
    cacheControl: '3600',
    contentType: 'image/png',
    upsert: true
  });
  return uploadError ? databaseFailure(action, uploadError.message) : null;
}

async function saveTranslations(
  supabase: SupabaseClient,
  table: 'themes_translations' | 'souler_profile' | 'folio_translations',
  ownerKey: 'theme_id' | 'souler_id' | 'folio_id',
  ownerId: string,
  data: FormData,
  fields: readonly string[]
) {
  const rows = LANGUAGES.map((lang) => {
    const suffix = lang === 'zh' ? 'zh' : 'en';
    return {
      [ownerKey]: ownerId,
      lang,
      ...Object.fromEntries(fields.map((field) => [field, text(data, `${field}_${suffix}`)]))
    };
  });

  return supabase.from(table).upsert(rows, { onConflict: `${ownerKey},lang` });
}

async function saveSoulerAliases(supabase: SupabaseClient, soulerId: string, aliasesText: string) {
  const aliases = aliasesText
    .split('\n')
    .map((alias) => alias.trim())
    .filter(Boolean);
  const { error: clearError } = await supabase
    .from('souler_aliases')
    .delete()
    .eq('souler_id', soulerId);
  if (clearError) return clearError;

  if (!aliases.length) return null;
  const { error: insertError } = await supabase
    .from('souler_aliases')
    .insert(aliases.map((alias) => ({ souler_id: soulerId, alias })));
  return insertError;
}

async function agentError(response: Response) {
  const body = (await response.json().catch(() => null)) as {
    detail?: string;
    error?: string;
  } | null;
  return body?.detail ?? body?.error ?? `Agent 请求失败（${response.status}）`;
}

export const load: PageServerLoad = async ({ locals }) => {
  const supabase = await requireAdmin(locals);
  const [themesResult, soulersResult, foliosResult] = await Promise.all([
    supabase.from('themes').select('id,key,created_at,themes_translations(lang,name)').order('key'),
    supabase
      .from('soulers')
      .select(
        'id,wiki_id,checked,avatar,created_at,updated_at,souler_profile(lang,name,introduction),souler_aliases(alias)'
      )
      .order('updated_at', { ascending: false }),
    supabase
      .from('folios')
      .select(
        'id,souler_id,cover_image,featured,is_public,created_at,updated_at,folio_translations(lang,title,subtitle,description),folio_themes(theme_id,sort_order),folio_prompts(id,content,version,is_active)'
      )
      .order('updated_at', { ascending: false })
  ]);

  const queryError = themesResult.error ?? soulersResult.error ?? foliosResult.error;
  if (queryError) error(500, queryError.message);

  return {
    themes: themesResult.data ?? [],
    soulers: (soulersResult.data ?? []).map((souler) => ({
      ...souler,
      avatar_url: publicAssetUrl(supabase, souler.avatar, souler.updated_at)
    })),
    folios: (foliosResult.data ?? []).map((folio) => ({
      ...folio,
      cover_image_url: publicAssetUrl(supabase, folio.cover_image, folio.updated_at)
    }))
  };
};

export const actions: Actions = {
  saveTheme: async ({ locals, request }) => {
    const supabase = await requireAdmin(locals);
    const data = await request.formData();
    const id = text(data, 'id');
    const key = text(data, 'key');
    const nameZh = text(data, 'name_zh');
    const nameEn = text(data, 'name_en');

    if (!key || !nameZh || !nameEn) {
      return databaseFailure('saveTheme', 'Key、中文名和英文名均不能为空。');
    }

    const themeResult = id
      ? await supabase.from('themes').update({ key }).eq('id', id).select('id').single()
      : await supabase.from('themes').insert({ key }).select('id').single();
    if (themeResult.error) return databaseFailure('saveTheme', themeResult.error.message);

    const translations = await saveTranslations(
      supabase,
      'themes_translations',
      'theme_id',
      themeResult.data.id,
      data,
      ['name']
    );
    if (translations.error) {
      return databaseFailure('saveTheme', translations.error.message);
    }

    return { action: 'saveTheme', success: true, message: '主题已保存。' };
  },

  deleteTheme: async ({ locals, request }) => {
    const supabase = await requireAdmin(locals);
    const id = text(await request.formData(), 'id');
    const { error: deleteError } = await supabase.from('themes').delete().eq('id', id);
    if (deleteError) return databaseFailure('deleteTheme', deleteError.message);
    return { action: 'deleteTheme', success: true, message: '主题已删除。' };
  },

  createSouler: async ({ locals, request, fetch }) => {
    const supabase = await requireAdmin(locals);
    const data = await request.formData();
    const name = text(data, 'name');
    const lang = text(data, 'lang');

    if (!name || !LANGUAGES.includes(lang as (typeof LANGUAGES)[number])) {
      return databaseFailure('createSouler', '请输入人物名并选择语言。');
    }

    const agentUrl = env.AGENT_API_URL?.replace(/\/$/, '');
    if (!agentUrl) {
      return databaseFailure('createSouler', 'AGENT_API_URL 尚未配置。');
    }

    const {
      data: { session }
    } = await supabase.auth.getSession();
    if (!session) return databaseFailure('createSouler', '登录状态已失效，请重新登录。');

    const response = await fetch(`${agentUrl}/v1/${lang === 'zh' ? 'zh' : 'en'}/soulers/resolve`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${session.access_token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ name })
    });
    if (!response.ok) return databaseFailure('createSouler', await agentError(response));

    const result = (await response.json()) as { status?: string };
    const message =
      result.status === 'existing'
        ? `${name} 已存在，无需重复创建。`
        : `${name} 已提交，Agent 将在后台完善人物资料。`;
    return { action: 'createSouler', success: true, message };
  },

  saveSoulerBase: async ({ locals, request }) => {
    const supabase = await requireAdmin(locals);
    const data = await request.formData();
    const id = text(data, 'id');
    if (!id) return databaseFailure('saveSoulerBase', '缺少 Souler ID。');

    const wikiId = optional(data, 'wiki_id');
    const avatar = image(data, 'avatar_file');
    if (avatar && !wikiId) {
      return databaseFailure('saveSoulerBase', '上传头像前必须填写 Wiki ID。');
    }
    if (avatar && wikiId && !/^[A-Za-z0-9_-]+$/.test(wikiId)) {
      return databaseFailure('saveSoulerBase', 'Wiki ID 只能包含字母、数字、下划线和连字符。');
    }

    const avatarPath = wikiId ? `soulers/${wikiId}.png` : null;
    const uploadFailure = avatar
      ? await uploadImage(supabase, avatar, avatarPath!, 'saveSoulerBase')
      : null;
    if (uploadFailure) return uploadFailure;

    const { error: updateError } = await supabase
      .from('soulers')
      .update({
        wiki_id: wikiId,
        ...(avatarPath && avatar ? { avatar: avatarPath } : {}),
        checked: checked(data, 'checked')
      })
      .eq('id', id);
    if (updateError) return databaseFailure('saveSoulerBase', updateError.message);

    const aliasesError = await saveSoulerAliases(supabase, id, text(data, 'aliases'));
    if (aliasesError) return databaseFailure('saveSoulerBase', aliasesError.message);

    return { action: 'saveSoulerBase', success: true, message: '人物基础资料已保存。' };
  },

  saveSoulerProfile: async ({ locals, request }) => {
    const supabase = await requireAdmin(locals);
    const data = await request.formData();
    const soulerId = text(data, 'id');
    const lang = text(data, 'lang');
    const name = text(data, 'name');
    if (!soulerId || !LANGUAGES.includes(lang as (typeof LANGUAGES)[number]) || !name) {
      return databaseFailure('saveSoulerProfile', '人物、语言和姓名均不能为空。');
    }

    const { error: profileError } = await supabase.from('souler_profile').upsert(
      {
        souler_id: soulerId,
        lang,
        name,
        introduction: optional(data, 'introduction')
      },
      { onConflict: 'souler_id,lang' }
    );
    if (profileError) return databaseFailure('saveSoulerProfile', profileError.message);

    return {
      action: 'saveSoulerProfile',
      success: true,
      message: `${lang === 'zh' ? '中文' : '英文'}资料已保存。`
    };
  },

  deleteSouler: async ({ locals, request }) => {
    const supabase = await requireAdmin(locals);
    const id = text(await request.formData(), 'id');
    const { error: deleteError } = await supabase.from('soulers').delete().eq('id', id);
    if (deleteError) return databaseFailure('deleteSouler', deleteError.message);
    return { action: 'deleteSouler', success: true, message: 'Souler 已删除。' };
  },

  saveFolio: async ({ locals, request }) => {
    const supabase = await requireAdmin(locals);
    const data = await request.formData();
    const id = text(data, 'id');
    const soulerId = text(data, 'souler_id');
    const titleZh = text(data, 'title_zh');
    const titleEn = text(data, 'title_en');

    if (!soulerId || !titleZh || !titleEn) {
      return databaseFailure('saveFolio', 'Souler、中文标题和英文标题均不能为空。');
    }

    const values = {
      souler_id: soulerId,
      featured: checked(data, 'featured'),
      is_public: checked(data, 'is_public')
    };
    const folioResult = id
      ? await supabase.from('folios').update(values).eq('id', id).select('id').single()
      : await supabase.from('folios').insert(values).select('id').single();
    if (folioResult.error) return databaseFailure('saveFolio', folioResult.error.message);

    const folioId = folioResult.data.id;
    const cover = image(data, 'cover_file');
    const coverPath = `folios/${folioId}.png`;
    const uploadFailure = await uploadImage(supabase, cover, coverPath, 'saveFolio');
    if (uploadFailure) return uploadFailure;
    if (cover) {
      const { error: coverError } = await supabase
        .from('folios')
        .update({ cover_image: coverPath })
        .eq('id', folioId);
      if (coverError) return databaseFailure('saveFolio', coverError.message);
    }

    const translations = await saveTranslations(
      supabase,
      'folio_translations',
      'folio_id',
      folioId,
      data,
      ['title', 'subtitle', 'description']
    );
    if (translations.error) return databaseFailure('saveFolio', translations.error.message);

    const { error: clearThemesError } = await supabase
      .from('folio_themes')
      .delete()
      .eq('folio_id', folioId);
    if (clearThemesError) return databaseFailure('saveFolio', clearThemesError.message);

    const themeIds = data.getAll('theme_ids').map(String);
    if (themeIds.length) {
      const { error: themesError } = await supabase.from('folio_themes').insert(
        themeIds.map((themeId, sortOrder) => ({
          folio_id: folioId,
          theme_id: themeId,
          sort_order: sortOrder
        }))
      );
      if (themesError) return databaseFailure('saveFolio', themesError.message);
    }

    const prompt = text(data, 'prompt');
    const promptId = text(data, 'prompt_id');
    if (prompt) {
      await supabase.from('folio_prompts').update({ is_active: false }).eq('folio_id', folioId);
      const promptResult = promptId
        ? await supabase
            .from('folio_prompts')
            .update({ content: prompt, is_active: true })
            .eq('id', promptId)
        : await supabase.from('folio_prompts').insert({
            folio_id: folioId,
            content: prompt,
            version: 1,
            is_active: true
          });
      if (promptResult.error) return databaseFailure('saveFolio', promptResult.error.message);
    }

    return { action: 'saveFolio', success: true, message: 'Folio 已保存。' };
  },

  deleteFolio: async ({ locals, request }) => {
    const supabase = await requireAdmin(locals);
    const id = text(await request.formData(), 'id');
    const { error: deleteError } = await supabase.from('folios').delete().eq('id', id);
    if (deleteError) return databaseFailure('deleteFolio', deleteError.message);
    return { action: 'deleteFolio', success: true, message: 'Folio 已删除。' };
  }
};
