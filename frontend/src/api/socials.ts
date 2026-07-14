import request from '@/utils/request';

// ── Types ────────────────────────────────────────────────────────────────────

export type SocialPostStatus = 'pending' | 'ready' | 'posted' | 'failed' | 'skipped';
export type SocialSlot = 'feed' | 'reel' | 'carousel';
export type SocialChannelName = 'facebook' | 'instagram' | 'linkedin';

export interface MetaOption {
  id: string;
  name: string;
}

export interface MetaInstagramAccount {
  id: string;
  username: string | null;
  page_id: string;
  page_name: string | null;
}

export interface SocialRegion {
  id: number;
  name: string;
  timezone: string;
  post_hour: number;
  countries: string[];
  active: boolean;
  hashtags: string[];
  configured: boolean;
  instagram_available: boolean;
  linkedin_available: boolean;
  integration_id: number | null;
  integration_label: string | null;
  page_id: string | null;
  page_name: string | null;
  ig_business_account_id: string | null;
  ig_username: string | null;
  ig_page_id: string | null;
  ad_account_id: string | null;
  linkedin_integration_id: number | null;
  linkedin_integration_label: string | null;
  linkedin_org_id: string | null;
  linkedin_org_name: string | null;
  post_to_facebook: boolean;
  post_to_instagram: boolean;
  post_to_linkedin: boolean;
}

export interface SocialAlternative {
  id: number;
  headline: string | null;
  body: string | null;
  cta_label: string | null;
  cta_url: string | null;
  source: 'generated' | 'manual';
  feed_media_url: string | null;
  feed_content_type: string | null;
  reel_media_url: string | null;
  reel_content_type: string | null;
  carousel_media: { url: string; content_type: string | null }[];
}

export interface SocialPostSummary {
  id: number;
  date: string;
  status: SocialPostStatus;
  post_hour: number | null;
  effective_post_hour: number;
  alternatives_count: number;
  feed_alternative_id: number | null;
  reel_alternative_id: number | null;
  carousel_alternative_id: number | null;
  thumb_url: string | null;
  thumb_content_type: string | null;
  thumbs: { url: string; content_type: string | null }[];
  has_video: boolean;
  title: string | null;
  posted_channels: SocialChannelName[];
  past: boolean;
}

export interface SocialPostDetail {
  id: number;
  region: { id: number; name: string; timezone: string; post_hour: number; configured: boolean; instagram_available: boolean; linkedin_available: boolean };
  date: string;
  status: SocialPostStatus;
  past: boolean;
  postable_today: boolean;
  post_hour: number | null;
  effective_post_hour: number;
  feed_alternative_id: number | null;
  reel_alternative_id: number | null;
  carousel_alternative_id: number | null;
  publish_error: string | null;
  alternatives: SocialAlternative[];
}

export interface SocialCalendar {
  region: { id: number; name: string; timezone: string; post_hour: number; configured: boolean };
  month: string;
  today: string;
  posts: SocialPostSummary[];
}

export interface SocialDelivery {
  id: number;
  social_post_id: number;
  integration_id: number;
  account_name: string | null;
  slot: SocialSlot;
  channel: SocialChannelName;
  status: 'pending' | 'posted' | 'failed' | 'skipped';
  provider_post_id: string | null;
  error_message: string | null;
  posted_at: string | null;
  created_at: string | null;
}

export interface SocialRegionInput {
  name?: string;
  timezone?: string;
  post_hour?: number;
  countries?: string[];
  active?: boolean;
  hashtags?: string[];
  integration_id?: number | null;
  page_id?: string | null;
  page_name?: string | null;
  ig_business_account_id?: string | null;
  ig_username?: string | null;
  ig_page_id?: string | null;
  ad_account_id?: string | null;
  linkedin_integration_id?: number | null;
  linkedin_org_id?: string | null;
  linkedin_org_name?: string | null;
  post_to_facebook?: boolean;
  post_to_instagram?: boolean;
  post_to_linkedin?: boolean;
}

export interface SocialPostUpdate {
  feed_alternative_id?: number | null;
  reel_alternative_id?: number | null;
  carousel_alternative_id?: number | null;
  ready?: boolean;
  post_hour?: number | null;
}

export interface SocialAlternativeUpdate {
  headline?: string;
  body?: string;
  cta_label?: string;
  cta_url?: string;
}

// ── Regions + channels ───────────────────────────────────────────────────────

export const getSocialRegions = () =>
  request.get<SocialRegion[]>('/social_regions').then((r) => r.data);

export const getSocialRegion = (id: number) =>
  request.get<SocialRegion>(`/social_regions/${id}`).then((r) => r.data);

export const createSocialRegion = (data: SocialRegionInput) =>
  request.post<SocialRegion>('/social_regions', { social_region: data }).then((r) => r.data);

export const updateSocialRegion = (id: number, data: SocialRegionInput) =>
  request.patch<SocialRegion>(`/social_regions/${id}`, { social_region: data }).then((r) => r.data);

export const deleteSocialRegion = (id: number) =>
  request.delete(`/social_regions/${id}`).then((r) => r.data);

// ── Meta discovery (populates a region's target dropdowns) ───────────────────

export const getMetaPages = (integrationId: number) =>
  request.get<MetaOption[]>(`/integrations/${integrationId}/meta/pages`).then((r) => r.data);

export const getMetaAdAccounts = (integrationId: number) =>
  request.get<MetaOption[]>(`/integrations/${integrationId}/meta/ad_accounts`).then((r) => r.data);

export const getMetaInstagramAccounts = (integrationId: number) =>
  request
    .get<MetaInstagramAccount[]>(`/integrations/${integrationId}/meta/instagram_accounts`)
    .then((r) => r.data);

// ── LinkedIn OAuth + discovery ───────────────────────────────────────────────

export const getLinkedinOauthUrl = (integrationId: number) =>
  request.get<{ url: string }>(`/integrations/${integrationId}/linkedin/oauth_url`).then((r) => r.data.url);

export const getLinkedinOrganizations = (integrationId: number) =>
  request.get<MetaOption[]>(`/integrations/${integrationId}/linkedin/organizations`).then((r) => r.data);

// ── Calendar + posts ─────────────────────────────────────────────────────────

export const getSocialCalendar = (regionId: number, month: string) =>
  request
    .get<SocialCalendar>(`/social_regions/${regionId}/calendar`, { params: { month } })
    .then((r) => r.data);

export const createSocialPost = (regionId: number, date: string) =>
  request
    .post<SocialPostDetail>(`/social_regions/${regionId}/social_posts`, { date })
    .then((r) => r.data);

export const getSocialPost = (id: number) =>
  request.get<SocialPostDetail>(`/social_posts/${id}`).then((r) => r.data);

export const updateSocialPost = (id: number, data: SocialPostUpdate) =>
  request.patch<SocialPostDetail>(`/social_posts/${id}`, data).then((r) => r.data);

export const publishSocialPostNow = (id: number) =>
  request.post<SocialPostDetail>(`/social_posts/${id}/publish_now`).then((r) => r.data);

export const getSocialPostDeliveries = (id: number) =>
  request.get<SocialDelivery[]>(`/social_posts/${id}/deliveries`).then((r) => r.data);

export const uploadSocialAlternative = (postId: number, form: FormData) =>
  request.post<SocialPostDetail>(`/social_posts/${postId}/alternatives`, form).then((r) => r.data);

// ── Alternatives ─────────────────────────────────────────────────────────────

export const updateSocialAlternative = (id: number, data: SocialAlternativeUpdate) =>
  request.patch<SocialPostDetail>(`/social_alternatives/${id}`, data).then((r) => r.data);

export const deleteSocialAlternative = (id: number) =>
  request.delete<SocialPostDetail>(`/social_alternatives/${id}`).then((r) => r.data);

export const postSocialAlternativeNow = (id: number, slot: SocialSlot, channels?: SocialChannelName[]) =>
  request.post<SocialPostDetail>(`/social_alternatives/${id}/post_now`, { slot, channels }).then((r) => r.data);
