BEGIN;

INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    email_change_confirm_status,
    is_sso_user,
    is_anonymous
)
VALUES (
    '00000000-0000-0000-0000-000000000000',
    '99090000-9909-4000-9000-000000000001',
    'authenticated',
    'authenticated',
    'brucehuang9909@gmail.com',
    crypt('123456', gen_salt('bf')),
    NOW(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{}'::jsonb,
    NOW(),
    NOW(),
    '',
    '',
    '',
    '',
    0,
    FALSE,
    FALSE
)
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = EXCLUDED.email_confirmed_at,
    raw_app_meta_data = EXCLUDED.raw_app_meta_data,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = EXCLUDED.updated_at,
    is_sso_user = EXCLUDED.is_sso_user,
    is_anonymous = EXCLUDED.is_anonymous;

INSERT INTO auth.identities (
    id,
    provider_id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
)
VALUES (
    '99090000-9909-4000-9000-000000000002',
    '99090000-9909-4000-9000-000000000001',
    '99090000-9909-4000-9000-000000000001',
    jsonb_build_object(
        'sub', '99090000-9909-4000-9000-000000000001',
        'email', 'brucehuang9909@gmail.com',
        'email_verified', TRUE,
        'phone_verified', FALSE
    ),
    'email',
    NOW(),
    NOW(),
    NOW()
)
ON CONFLICT (provider_id, provider) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    identity_data = EXCLUDED.identity_data,
    updated_at = EXCLUDED.updated_at;

INSERT INTO public.user_roles (user_id, role)
VALUES ('99090000-9909-4000-9000-000000000001', 'admin')
ON CONFLICT (user_id, role) DO NOTHING;

INSERT INTO public.discover_sections (id, sort_order, is_active, created_at, updated_at)
VALUES ('91555a37-15f9-413f-80a0-cf2d7805c86a', 4, TRUE, '2026-04-26T01:42:02.472959+00:00', '2026-04-30T15:45:54.287728+00:00')
ON CONFLICT (id) DO UPDATE SET
    sort_order = EXCLUDED.sort_order,
    is_active = EXCLUDED.is_active,
    created_at = EXCLUDED.created_at,
    updated_at = EXCLUDED.updated_at;

INSERT INTO public.discover_section_profile (section_id, lang, title, subtitle)
VALUES
    ('91555a37-15f9-413f-80a0-cf2d7805c86a', 'zh', '存在与虚无', NULL),
    ('91555a37-15f9-413f-80a0-cf2d7805c86a', 'en', 'Being and Nothingness', NULL)
ON CONFLICT (section_id, lang) DO UPDATE SET
    title = EXCLUDED.title,
    subtitle = EXCLUDED.subtitle;

INSERT INTO public.soulers (id, wiki_id, avatar, checked, created_at, updated_at)
VALUES
    ('d91e3cb8-7a8e-48ff-aa48-112be199d580', 'Q34670', 'soulers/Q34670.png', TRUE, '2026-04-24T09:15:02.397253+00:00', '2026-04-24T09:15:51.063833+00:00'),
    ('3dfa0019-6de0-42d1-a01a-0853fd6d679b', 'Q905', 'soulers/Q905.png', TRUE, '2026-04-24T10:21:38.65411+00:00', '2026-04-24T10:28:34.706264+00:00'),
    ('f9c7c63f-0c0a-4287-b6a2-63040078c2de', 'Q9358', 'soulers/Q9358.png', TRUE, '2026-04-24T09:08:29.178824+00:00', '2026-04-24T09:11:01.908113+00:00'),
    ('a0ea4fec-1db5-48c3-8b3e-e4f0180dccda', 'Q48301', 'soulers/Q48301.png', TRUE, '2026-04-30T12:44:15.676664+00:00', '2026-04-30T12:47:22.711392+00:00'),
    ('bc6e92a2-2d0e-4313-a121-7ed9220d0bce', 'Q9364', 'soulers/Q9364.png', TRUE, '2026-04-28T08:47:45.380047+00:00', '2026-04-28T08:48:54.671669+00:00')
ON CONFLICT (id) DO UPDATE SET
    wiki_id = EXCLUDED.wiki_id,
    avatar = EXCLUDED.avatar,
    checked = EXCLUDED.checked,
    created_at = EXCLUDED.created_at,
    updated_at = EXCLUDED.updated_at;

INSERT INTO public.souler_profile (souler_id, lang, name, introduction)
VALUES
    ('d91e3cb8-7a8e-48ff-aa48-112be199d580', 'zh', '加缪', '阿尔贝·加缪是法国作家与荒诞哲学家，关注人在无意义世界中的清醒、反抗与尊严。'),
    ('d91e3cb8-7a8e-48ff-aa48-112be199d580', 'en', 'Albert Camus', 'Albert Camus was a French writer and philosopher of the absurd, concerned with lucidity, revolt, and human dignity.'),
    ('3dfa0019-6de0-42d1-a01a-0853fd6d679b', 'zh', '卡夫卡', '弗兰兹·卡夫卡以荒诞、官僚迷宫与存在焦虑书写现代人的异化处境。'),
    ('3dfa0019-6de0-42d1-a01a-0853fd6d679b', 'en', 'Franz Kafka', 'Franz Kafka wrote modern alienation through absurdity, opaque authority, and existential anxiety.'),
    ('f9c7c63f-0c0a-4287-b6a2-63040078c2de', 'zh', '尼采', '弗里德里希·尼采以虚无、权力意志、自我超越与价值重估撕开现代精神困境。'),
    ('f9c7c63f-0c0a-4287-b6a2-63040078c2de', 'en', 'Friedrich Nietzsche', 'Friedrich Nietzsche challenged inherited values through nihilism, will to power, self-overcoming, and revaluation.'),
    ('a0ea4fec-1db5-48c3-8b3e-e4f0180dccda', 'zh', '海德格尔', '马丁·海德格尔重新追问存在之意义，并反思技术时代中人的本真处境。'),
    ('a0ea4fec-1db5-48c3-8b3e-e4f0180dccda', 'en', 'Martin Heidegger', 'Martin Heidegger reopened the question of Being and examined authenticity in the technological age.'),
    ('bc6e92a2-2d0e-4313-a121-7ed9220d0bce', 'zh', '萨特', '让-保罗·萨特主张存在先于本质，强调自由、选择与无法逃避的责任。'),
    ('bc6e92a2-2d0e-4313-a121-7ed9220d0bce', 'en', 'Jean-Paul Sartre', 'Jean-Paul Sartre argued that existence precedes essence, placing freedom, choice, and responsibility at the center of life.')
ON CONFLICT (souler_id, lang) DO UPDATE SET
    name = EXCLUDED.name,
    introduction = EXCLUDED.introduction;

INSERT INTO public.souler_aliases (souler_id, alias)
VALUES
    ('d91e3cb8-7a8e-48ff-aa48-112be199d580', '加缪'),
    ('d91e3cb8-7a8e-48ff-aa48-112be199d580', '阿尔贝·加缪'),
    ('d91e3cb8-7a8e-48ff-aa48-112be199d580', 'Albert Camus'),
    ('3dfa0019-6de0-42d1-a01a-0853fd6d679b', '卡夫卡'),
    ('3dfa0019-6de0-42d1-a01a-0853fd6d679b', '弗兰兹·卡夫卡'),
    ('3dfa0019-6de0-42d1-a01a-0853fd6d679b', 'Franz Kafka'),
    ('f9c7c63f-0c0a-4287-b6a2-63040078c2de', '尼采'),
    ('f9c7c63f-0c0a-4287-b6a2-63040078c2de', '弗里德里希·尼采'),
    ('f9c7c63f-0c0a-4287-b6a2-63040078c2de', 'Friedrich Nietzsche'),
    ('a0ea4fec-1db5-48c3-8b3e-e4f0180dccda', '海德格尔'),
    ('a0ea4fec-1db5-48c3-8b3e-e4f0180dccda', '马丁·海德格尔'),
    ('a0ea4fec-1db5-48c3-8b3e-e4f0180dccda', 'Martin Heidegger'),
    ('bc6e92a2-2d0e-4313-a121-7ed9220d0bce', '萨特'),
    ('bc6e92a2-2d0e-4313-a121-7ed9220d0bce', '让-保罗·萨特'),
    ('bc6e92a2-2d0e-4313-a121-7ed9220d0bce', 'Jean-Paul Sartre')
ON CONFLICT (alias) DO NOTHING;

INSERT INTO public.chapters (souler_id, lang, seq, title, subtitle, task)
VALUES
    ('d91e3cb8-7a8e-48ff-aa48-112be199d580', 'zh', 1, '荒诞的清晨', '在无意义中保持清醒', '引导用户看见意义渴望与世界沉默之间的冲突，并练习清醒的反抗。'),
    ('d91e3cb8-7a8e-48ff-aa48-112be199d580', 'en', 1, 'The Absurd Morning', 'Remain lucid in a world without given meaning', 'Guide the user to face the conflict between the hunger for meaning and the silence of the world.'),
    ('3dfa0019-6de0-42d1-a01a-0853fd6d679b', 'zh', 1, '甲虫的清晨', '在荒诞的苏醒中确认异化', '用冷静、细密的语气让用户体验被生活排除在外的疏离感。'),
    ('3dfa0019-6de0-42d1-a01a-0853fd6d679b', 'en', 1, 'The Insect Morning', 'Wake into estrangement', 'Use calm detail to let the user feel the alienation of being excluded from ordinary life.'),
    ('f9c7c63f-0c0a-4287-b6a2-63040078c2de', 'zh', 1, '意义崩塌之时', '直面无意义的深渊', '连续追问用户为什么某个价值重要，直到旧有答案开始松动。'),
    ('f9c7c63f-0c0a-4287-b6a2-63040078c2de', 'en', 1, 'When Meaning Collapses', 'Face the abyss of meaninglessness', 'Question why the user values what they value until inherited answers begin to loosen.'),
    ('a0ea4fec-1db5-48c3-8b3e-e4f0180dccda', 'zh', 1, '存在之问', '重新听见被遗忘的问题', '引导用户把注意力从事物转向存在本身，辨认日常沉沦。'),
    ('a0ea4fec-1db5-48c3-8b3e-e4f0180dccda', 'en', 1, 'The Question of Being', 'Hear the forgotten question again', 'Shift the user from things to Being itself, and reveal everyday fallenness.'),
    ('bc6e92a2-2d0e-4313-a121-7ed9220d0bce', 'zh', 1, '自由的重量', '承认选择无法被推卸', '要求用户面对自己的选择，并承担自由带来的责任。'),
    ('bc6e92a2-2d0e-4313-a121-7ed9220d0bce', 'en', 1, 'The Weight of Freedom', 'Admit that choice cannot be outsourced', 'Ask the user to face their choices and accept the responsibility of freedom.')
ON CONFLICT (souler_id, lang, seq) DO UPDATE SET
    title = EXCLUDED.title,
    subtitle = EXCLUDED.subtitle,
    task = EXCLUDED.task;

INSERT INTO public.discover_section_items (section_id, souler_id, sort_order, created_at, updated_at)
VALUES
    ('91555a37-15f9-413f-80a0-cf2d7805c86a', 'd91e3cb8-7a8e-48ff-aa48-112be199d580', 0, '2026-04-26T01:43:12.290318+00:00', '2026-04-30T16:04:09.526664+00:00'),
    ('91555a37-15f9-413f-80a0-cf2d7805c86a', 'f9c7c63f-0c0a-4287-b6a2-63040078c2de', 1, '2026-04-26T01:42:38.351589+00:00', '2026-04-30T16:04:09.526664+00:00'),
    ('91555a37-15f9-413f-80a0-cf2d7805c86a', 'bc6e92a2-2d0e-4313-a121-7ed9220d0bce', 2, '2026-04-30T15:46:26.686689+00:00', '2026-04-30T16:04:09.526664+00:00'),
    ('91555a37-15f9-413f-80a0-cf2d7805c86a', '3dfa0019-6de0-42d1-a01a-0853fd6d679b', 3, '2026-04-26T01:43:39.172611+00:00', '2026-04-30T16:04:09.526664+00:00'),
    ('91555a37-15f9-413f-80a0-cf2d7805c86a', 'a0ea4fec-1db5-48c3-8b3e-e4f0180dccda', 4, '2026-04-30T15:46:39.192209+00:00', '2026-04-30T16:04:09.526664+00:00')
ON CONFLICT (section_id, souler_id) DO UPDATE SET
    sort_order = EXCLUDED.sort_order,
    created_at = EXCLUDED.created_at,
    updated_at = EXCLUDED.updated_at;

COMMIT;
