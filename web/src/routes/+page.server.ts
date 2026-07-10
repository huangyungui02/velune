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

export const load: PageServerLoad = async ({ locals }) => {
  const supabase = locals.supabase;
  if (!supabase) {
    return {
      themes: [],
      folios: [],
      soulers: []
    };
  }

  const [themesResult, foliosResult, soulersResult] = await Promise.all([
    supabase.from('themes').select('id,key,themes_translations(lang,name)').order('key').limit(12),
    supabase
      .from('folios')
      .select(
        'id,souler_id,cover_image,featured,created_at,updated_at,folio_translations(lang,title,subtitle,description),folio_themes(sort_order,themes(id,key,themes_translations(lang,name))),soulers(id,wiki_id,avatar,updated_at,souler_profile(lang,name,introduction))'
      )
      .eq('is_public', true)
      .order('featured', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(10),
    supabase
      .from('soulers')
      .select(
        'id,wiki_id,avatar,updated_at,souler_profile(lang,name,introduction),souler_keyword(weight,keywords(word,language))'
      )
      .eq('checked', true)
      .order('updated_at', { ascending: false })
      .limit(12)
  ]);

  const queryError = themesResult.error ?? foliosResult.error ?? soulersResult.error;
  if (queryError) error(500, queryError.message);

  return {
    themes: (themesResult.data ?? []).map((theme) => {
      const zh = translation(theme.themes_translations, 'zh');
      const en = translation(theme.themes_translations, 'en');

      return {
        id: theme.id,
        key: theme.key,
        label: zh?.name || en?.name || theme.key
      };
    }),
    folios: (foliosResult.data ?? []).map((folio) => {
      const zh = translation(folio.folio_translations, 'zh');
      const en = translation(folio.folio_translations, 'en');
      const souler = one(folio.soulers);
      const soulerZh = translation(souler?.souler_profile, 'zh');
      const soulerEn = translation(souler?.souler_profile, 'en');
      const themes = (folio.folio_themes ?? [])
        .toSorted((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
        .map((item) => {
          const theme = one(item.themes);
          const themeZh = translation(theme?.themes_translations, 'zh');
          const themeEn = translation(theme?.themes_translations, 'en');
          return themeZh?.name || themeEn?.name || theme?.key || '';
        })
        .filter(Boolean);

      return {
        id: folio.id,
        title: zh?.title || en?.title || '未命名 Folio',
        subtitle: zh?.subtitle || en?.subtitle || '',
        description: zh?.description || en?.description || '',
        author: soulerZh?.name || soulerEn?.name || souler?.wiki_id || '未知作者',
        coverUrl: publicAssetUrl(supabase, folio.cover_image, folio.updated_at),
        tags: themes.slice(0, 3)
      };
    }),
    soulers: (soulersResult.data ?? []).map((souler) => {
      const zh = translation(souler.souler_profile, 'zh');
      const en = translation(souler.souler_profile, 'en');
      const name = zh?.name || en?.name || souler.wiki_id || '未命名人物';
      const keywords = (souler.souler_keyword ?? [])
        .toSorted((a, b) => (b.weight ?? 0) - (a.weight ?? 0))
        .map((item) => one(item.keywords))
        .filter((keyword) => keyword?.word)
        .toSorted((a, b) => {
          const aScore = a?.language === 'zh' ? 0 : 1;
          const bScore = b?.language === 'zh' ? 0 : 1;
          return aScore - bScore;
        })
        .map((keyword) => keyword?.word)
        .filter(Boolean)
        .slice(0, 4);

      return {
        id: souler.id,
        name,
        keywords,
        initials: initials(name),
        avatarUrl: publicAssetUrl(supabase, souler.avatar, souler.updated_at)
      };
    })
  };
};
