import type { SupabaseClient } from '@supabase/supabase-js';
import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

const ASSET_BUCKET = 'avatars';

type Translation = {
  lang: string;
  name?: string;
  title?: string;
  subtitle?: string;
  description?: string;
  introduction?: string;
};

function publicAssetUrl(supabase: SupabaseClient, path: string | null, version: string | null) {
  if (!path) return null;
  if (/^https?:\/\//.test(path) || path.startsWith('/')) return path;

  const url = supabase.storage.from(ASSET_BUCKET).getPublicUrl(path).data.publicUrl;
  return version ? `${url}?v=${encodeURIComponent(version)}` : url;
}

function translation<T extends Translation>(items: T[] | null | undefined, lang: 'zh' | 'en') {
  return items?.find((item) => item.lang === lang) ?? null;
}

function one<T>(value: T | T[] | null | undefined) {
  return Array.isArray(value) ? (value[0] ?? null) : (value ?? null);
}

function initials(name: string) {
  return name.trim().slice(0, 1).toUpperCase() || 'F';
}

export const load: PageServerLoad = async ({ locals, params }) => {
  const supabase = locals.supabase;
  if (!supabase) error(404, 'Folio 不存在');

  const [folioResult, soulersResult] = await Promise.all([
    supabase
      .from('folios')
      .select(
        'id,souler_id,cover_image,featured,created_at,updated_at,folio_translations(lang,title,subtitle,description),folio_themes(sort_order,themes(id,key,themes_translations(lang,name))),soulers(id,wiki_id,avatar,updated_at,souler_profile(lang,name,introduction))'
      )
      .eq('id', params.id)
      .eq('is_public', true)
      .maybeSingle(),
    supabase
      .from('soulers')
      .select('id,wiki_id,avatar,updated_at,souler_profile(lang,name,introduction)')
      .eq('checked', true)
      .limit(6)
  ]);

  if (folioResult.error) error(500, folioResult.error.message);
  if (!folioResult.data) error(404, 'Folio 不存在');

  const folio = folioResult.data;
  const zh = translation(folio.folio_translations, 'zh');
  const en = translation(folio.folio_translations, 'en');
  const souler = one(folio.soulers);
  const soulerZh = translation(souler?.souler_profile, 'zh');
  const soulerEn = translation(souler?.souler_profile, 'en');
  const author = soulerZh?.name || soulerEn?.name || souler?.wiki_id || '未知作者';
  const authorIntro = soulerZh?.introduction || soulerEn?.introduction || '';
  const themes = (folio.folio_themes ?? [])
    .toSorted((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
    .map((item) => {
      const theme = one(item.themes);
      const themeZh = translation(theme?.themes_translations, 'zh');
      const themeEn = translation(theme?.themes_translations, 'en');
      return {
        id: theme?.id || theme?.key || '',
        name: themeZh?.name || themeEn?.name || theme?.key || ''
      };
    })
    .filter((theme) => theme.id && theme.name);

  const soulers = (soulersResult.data ?? []).map((s) => {
    const sZh = translation(s.souler_profile, 'zh');
    const sEn = translation(s.souler_profile, 'en');
    const name = sZh?.name || sEn?.name || s.wiki_id || '未命名人物';
    return {
      id: s.id,
      name,
      englishName: sEn?.name || '',
      intro: sZh?.introduction || sEn?.introduction || '',
      initials: initials(name),
      avatarUrl: publicAssetUrl(supabase, s.avatar, s.updated_at)
    };
  });

  return {
    folio: {
      id: folio.id,
      title: zh?.title || en?.title || '未命名 Folio',
      subtitle: zh?.subtitle || en?.subtitle || '',
      description: zh?.description || en?.description || '',
      coverUrl: publicAssetUrl(supabase, folio.cover_image, folio.updated_at),
      themes,
      author: {
        id: souler?.id || '',
        name: soulerZh?.name || '未知作者',
        englishName: soulerEn?.name || '',
        intro: authorIntro,
        initials: initials(soulerZh?.name || soulerEn?.name || 'F'),
        avatarUrl: publicAssetUrl(supabase, souler?.avatar ?? null, souler?.updated_at ?? null)
      }
    },
    soulers
  };
};
