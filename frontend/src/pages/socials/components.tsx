import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type Dispatch,
  type SetStateAction,
} from 'react';
import toast from 'react-hot-toast';
import { ChevronLeft, ChevronRight, Video, Trash2, Send, Play } from 'lucide-react';
import {
  uploadSocialAlternative,
  getSocialPostDeliveries,
  SocialPostDetail,
  SocialAlternative,
  SocialDelivery,
  SocialSlot,
  SocialChannelName,
} from '@/api/socials';
import { createAuthenticatedConsumer } from '@/utils/cable';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Checkbox } from '@/components/ui/checkbox';
import { FacebookIcon, InstagramIcon } from '@/components/ui/channel-icon';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { isVideoType, isVideoAlt, errorMessage, statusStyle } from './shared';

// ── Alternative card ─────────────────────────────────────────────────────────

export function AlternativeCard({
  alt,
  isFeed,
  isReel,
  isCarousel,
  busy,
  instagramAvailable,
  onToggleSlot,
  onSaveCopy,
  onDelete,
  onPostNow,
}: {
  alt: SocialAlternative;
  isFeed: boolean;
  isReel: boolean;
  isCarousel: boolean;
  busy: boolean;
  instagramAvailable: boolean;
  onToggleSlot: (slot: SocialSlot) => void;
  onSaveCopy: (data: { headline: string; body: string; cta_label: string; cta_url: string }) => void;
  onDelete: () => void;
  onPostNow: (slots: SocialSlot[], channels: SocialChannelName[]) => void;
}) {
  const [headline, setHeadline] = useState(alt.headline ?? '');
  const [body, setBody] = useState(alt.body ?? '');
  const [ctaLabel, setCtaLabel] = useState(alt.cta_label ?? '');
  const [ctaUrl, setCtaUrl] = useState(alt.cta_url ?? '');

  const saveCopy = () => onSaveCopy({ headline, body, cta_label: ctaLabel, cta_url: ctaUrl });

  return (
    <div className="space-y-3 rounded-lg border p-3">
      <div className="grid grid-cols-3 gap-3">
        <MediaThumb url={alt.feed_media_url} type={alt.feed_content_type} label="Feed 4:5" heightClass="h-80" mediaKey={`${alt.id}-feed`} />
        <MediaThumb url={alt.reel_media_url} type={alt.reel_content_type} label="Reel 9:16" heightClass="h-80" mediaKey={`${alt.id}-reel`} />
        <CarouselStrip altId={alt.id} media={alt.carousel_media} heightClass="h-80" />
      </div>

      <div className="flex flex-wrap gap-4 text-sm">
        <label className={`flex items-center gap-2 ${alt.feed_media_url ? '' : 'opacity-50'}`}>
          <Checkbox checked={isFeed} onCheckedChange={() => onToggleSlot('feed')} disabled={busy || !alt.feed_media_url} /> Use as feed
        </label>
        <label className={`flex items-center gap-2 ${alt.reel_media_url ? '' : 'opacity-50'}`}>
          <Checkbox checked={isReel} onCheckedChange={() => onToggleSlot('reel')} disabled={busy || !alt.reel_media_url} /> Use as reel
        </label>
        <label className={`flex items-center gap-2 ${alt.carousel_media.length >= 2 ? '' : 'opacity-50'}`}>
          <Checkbox
            checked={isCarousel}
            onCheckedChange={() => onToggleSlot('carousel')}
            disabled={busy || alt.carousel_media.length < 2}
          />{' '}
          Use as carousel
        </label>
      </div>

      <div className="space-y-1">
        <Label className="text-xs">Headline</Label>
        <Input value={headline} onChange={(e) => setHeadline(e.target.value)} onBlur={saveCopy} placeholder="Headline" />
      </div>
      <div className="space-y-1">
        <Label className="text-xs">Body</Label>
        <Textarea value={body} onChange={(e) => setBody(e.target.value)} onBlur={saveCopy} placeholder="Body" rows={3} />
      </div>
      <div className="grid grid-cols-2 gap-2">
        <div className="space-y-1">
          <Label className="text-xs">CTA label</Label>
          <Input value={ctaLabel} onChange={(e) => setCtaLabel(e.target.value)} onBlur={saveCopy} placeholder="CTA label" />
        </div>
        <div className="space-y-1">
          <Label className="text-xs">CTA URL</Label>
          <Input value={ctaUrl} onChange={(e) => setCtaUrl(e.target.value)} onBlur={saveCopy} placeholder="CTA URL" />
        </div>
      </div>

      <div className="flex items-center justify-between">
        <PostNowButton alt={alt} instagramAvailable={instagramAvailable} busy={busy} onPostNow={onPostNow} />
        <Button size="sm" variant="ghost" onClick={onDelete} disabled={busy}>
          <Trash2 className="h-4 w-4 text-destructive" />
        </Button>
      </div>
    </div>
  );
}

// ── Post now (manual publish) ────────────────────────────────────────────────
// A self-contained "Post now" button + dialog, usable on any day (pending,
// ready, posted, or past) so a creative can always be published manually.
// Renders nothing when the creative has no media to post.
export function PostNowButton({
  alt,
  instagramAvailable,
  busy,
  onPostNow,
}: {
  alt: SocialAlternative;
  instagramAvailable: boolean;
  busy: boolean;
  onPostNow: (slots: SocialSlot[], channels: SocialChannelName[]) => void;
}) {
  const feedAvailable = Boolean(alt.feed_media_url);
  const reelAvailable = Boolean(alt.reel_media_url);
  const carouselAvailable = alt.carousel_media.length >= 2;
  const [postOpen, setPostOpen] = useState(false);
  const [postFeed, setPostFeed] = useState(false);
  const [postReel, setPostReel] = useState(false);
  const [postCarousel, setPostCarousel] = useState(false);
  const [postFacebook, setPostFacebook] = useState(true);
  const [postInstagram, setPostInstagram] = useState(false);

  if (!feedAvailable && !reelAvailable && !carouselAvailable) return <span />;

  const openPost = () => {
    setPostFeed(feedAvailable);
    setPostReel(reelAvailable);
    setPostCarousel(carouselAvailable);
    setPostFacebook(true);
    setPostInstagram(instagramAvailable);
    setPostOpen(true);
  };

  const confirmPost = () => {
    const slots: SocialSlot[] = [];
    if (postFeed) slots.push('feed');
    if (postReel) slots.push('reel');
    if (postCarousel) slots.push('carousel');
    const channels: SocialChannelName[] = [];
    if (postFacebook) channels.push('facebook');
    if (postInstagram) channels.push('instagram');
    if (slots.length === 0 || channels.length === 0) return;
    onPostNow(slots, channels);
    setPostOpen(false);
  };

  return (
    <>
      <Button size="sm" variant="secondary" onClick={openPost} disabled={busy}>
        <Send className="mr-1 h-3 w-3" /> Post now
      </Button>

      <Dialog open={postOpen} onOpenChange={setPostOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Post now</DialogTitle>
            <DialogDescription>
              This publishes this creative immediately to the linked social account. Choose which formats and channels
              to post.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">Formats</p>
              <label className="flex items-center gap-2 text-sm">
                <Checkbox
                  checked={postFeed}
                  disabled={!feedAvailable}
                  onCheckedChange={(v) => setPostFeed(Boolean(v))}
                />
                Feed (4:5){!feedAvailable && <span className="text-xs text-muted-foreground">(no media)</span>}
              </label>
              <label className="flex items-center gap-2 text-sm">
                <Checkbox
                  checked={postReel}
                  disabled={!reelAvailable}
                  onCheckedChange={(v) => setPostReel(Boolean(v))}
                />
                Reel (9:16){!reelAvailable && <span className="text-xs text-muted-foreground">(no media)</span>}
              </label>
              <label className="flex items-center gap-2 text-sm">
                <Checkbox
                  checked={postCarousel}
                  disabled={!carouselAvailable}
                  onCheckedChange={(v) => setPostCarousel(Boolean(v))}
                />
                Carousel{!carouselAvailable && <span className="text-xs text-muted-foreground">(needs 2+ images)</span>}
              </label>
            </div>
            <div className="space-y-2">
              <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">Channels</p>
              <label className="flex items-center gap-2 text-sm">
                <Checkbox checked={postFacebook} onCheckedChange={(v) => setPostFacebook(Boolean(v))} />
                <FacebookIcon className="h-4 w-4" /> Facebook
              </label>
              <label className="flex items-center gap-2 text-sm">
                <Checkbox
                  checked={postInstagram}
                  disabled={!instagramAvailable}
                  onCheckedChange={(v) => setPostInstagram(Boolean(v))}
                />
                <InstagramIcon className="h-4 w-4" /> Instagram
                {!instagramAvailable && <span className="text-xs text-muted-foreground">(not linked)</span>}
              </label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPostOpen(false)}>
              Cancel
            </Button>
            <Button
              onClick={confirmPost}
              disabled={busy || (!postFeed && !postReel && !postCarousel) || (!postFacebook && !postInstagram)}
            >
              <Send className="mr-1 h-3 w-3" /> Post now
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

// ── Shared lightbox (arrow-key navigable) ────────────────────────────────────

export type LightboxItem = { key: string; url: string; type: string | null; label: string };

// Opening a thumbnail hands its key to the page-level lightbox.
export const LightboxContext = createContext<((key: string) => void) | null>(null);

// Every creative's media (feed then reel) as one ordered, arrow-navigable set.
export function collectLightboxItems(alternatives: SocialAlternative[]): LightboxItem[] {
  const items: LightboxItem[] = [];
  alternatives.forEach((alt, i) => {
    const name = alt.headline?.trim() || `Creative ${i + 1}`;
    if (alt.feed_media_url)
      items.push({ key: `${alt.id}-feed`, url: alt.feed_media_url, type: alt.feed_content_type, label: `${name} (Feed)` });
    if (alt.reel_media_url)
      items.push({ key: `${alt.id}-reel`, url: alt.reel_media_url, type: alt.reel_content_type, label: `${name} (Reel)` });
    alt.carousel_media.forEach((m, j) =>
      items.push({ key: `${alt.id}-carousel-${j}`, url: m.url, type: m.content_type, label: `${name} (Slide ${j + 1})` }),
    );
  });
  return items;
}

// A compact strip of a creative's carousel slides; each opens in the lightbox.
export function CarouselStrip({
  altId,
  media,
  heightClass = 'h-80',
}: {
  altId: number;
  media: { url: string; content_type: string | null }[];
  heightClass?: string;
}) {
  const openLightbox = useContext(LightboxContext);
  return (
    <div>
      <div className="mb-1 text-[10px] uppercase text-muted-foreground">Carousel ({media.length})</div>
      {media.length === 0 ? (
        <div className={`flex ${heightClass} items-center justify-center rounded bg-muted text-xs text-muted-foreground`}>
          —
        </div>
      ) : (
        <div className={`grid ${heightClass} grid-cols-2 content-start gap-1 overflow-y-auto rounded bg-muted p-1`}>
          {media.map((m, i) => (
            <button
              key={i}
              type="button"
              onClick={() => openLightbox?.(`${altId}-carousel-${i}`)}
              className="group relative overflow-hidden rounded"
            >
              {isVideoType(m.content_type) ? (
                <video src={m.url} className="h-20 w-full object-cover" muted preload="metadata" />
              ) : (
                <img src={m.url} alt={`Slide ${i + 1}`} className="h-20 w-full object-cover transition group-hover:opacity-90" />
              )}
              <span className="absolute bottom-0 right-0 rounded-tl bg-black/50 px-1 text-[9px] text-white">{i + 1}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

export function Lightbox({
  items,
  index,
  setIndex,
}: {
  items: LightboxItem[];
  index: number | null;
  setIndex: Dispatch<SetStateAction<number | null>>;
}) {
  const open = index != null;
  const move = useCallback(
    (delta: number) =>
      setIndex((cur) => (cur == null || items.length === 0 ? cur : (cur + delta + items.length) % items.length)),
    [items.length, setIndex],
  );

  // Left/right arrows step through the images while the lightbox is open.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight') {
        e.preventDefault();
        move(1);
      } else if (e.key === 'ArrowLeft') {
        e.preventDefault();
        move(-1);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, move]);

  const item = index == null ? null : items[index];
  const isVideo = isVideoType(item?.type ?? null);

  return (
    <Dialog open={open} onOpenChange={(v) => !v && setIndex(null)}>
      <DialogContent className="max-w-3xl">
        <DialogHeader className="sr-only">
          <DialogTitle>{item?.label ?? 'Preview'}</DialogTitle>
        </DialogHeader>
        {item && (
          <div className="space-y-3">
            {isVideo ? (
              <video src={item.url} controls autoPlay className="max-h-[80vh] w-full rounded" />
            ) : (
              <img src={item.url} alt={item.label} className="max-h-[80vh] w-full rounded object-contain" />
            )}
            <div className="flex items-center justify-between gap-2">
              <span className="truncate text-sm text-muted-foreground">
                {item.label}
                {items.length > 1 && ` · ${index! + 1} / ${items.length}`}
              </span>
              {items.length > 1 && (
                <div className="flex gap-2">
                  <Button variant="outline" size="sm" onClick={() => move(-1)}>
                    <ChevronLeft className="h-4 w-4" />
                  </Button>
                  <Button variant="outline" size="sm" onClick={() => move(1)}>
                    <ChevronRight className="h-4 w-4" />
                  </Button>
                </div>
              )}
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}

// A media preview thumbnail that opens the shared lightbox at its own item.
export function MediaThumb({
  url,
  type,
  label,
  mediaKey,
  heightClass = 'h-28',
}: {
  url: string | null;
  type: string | null;
  label: string;
  mediaKey: string;
  heightClass?: string;
}) {
  const openLightbox = useContext(LightboxContext);
  const isVideo = isVideoType(type);

  return (
    <div>
      <div className="mb-1 text-[10px] uppercase text-muted-foreground">{label}</div>
      {!url ? (
        <div className={`flex ${heightClass} items-center justify-center rounded bg-muted text-xs text-muted-foreground`}>
          —
        </div>
      ) : (
        <button
          type="button"
          onClick={() => openLightbox?.(mediaKey)}
          className={`group relative flex ${heightClass} w-full items-center justify-center overflow-hidden rounded bg-muted`}
        >
          {isVideo ? (
            <>
              <video src={url} className="h-full w-full object-contain" muted preload="metadata" />
              <span className="absolute inset-0 flex items-center justify-center">
                <span className="rounded-full bg-black/50 p-2 text-white transition group-hover:bg-black/70">
                  <Play className="h-5 w-5" />
                </span>
              </span>
            </>
          ) : (
            <img src={url} alt={label} className="h-full w-full object-contain transition group-hover:opacity-90" />
          )}
        </button>
      )}
    </div>
  );
}

// Compact, read-only preview of a creative shown on decided (non-pending) days.
export function CreativePreview({
  alt,
  isFeed,
  isReel,
  isCarousel,
  busy,
  instagramAvailable,
  onPostNow,
}: {
  alt: SocialAlternative;
  isFeed: boolean;
  isReel: boolean;
  isCarousel: boolean;
  busy: boolean;
  instagramAvailable: boolean;
  onPostNow: (slots: SocialSlot[], channels: SocialChannelName[]) => void;
}) {
  return (
    <div className="space-y-2 rounded-lg border p-2">
      <div className="grid grid-cols-2 gap-2">
        <MediaThumb url={alt.feed_media_url} type={alt.feed_content_type} label="Feed" heightClass="h-44" mediaKey={`${alt.id}-feed`} />
        <MediaThumb url={alt.reel_media_url} type={alt.reel_content_type} label="Reel" heightClass="h-44" mediaKey={`${alt.id}-reel`} />
      </div>
      {alt.carousel_media.length > 0 && <CarouselStrip altId={alt.id} media={alt.carousel_media} heightClass="h-24" />}
      <div className="space-y-1">
        <div className="flex items-center gap-2">
          {isVideoAlt(alt) && <Video className="h-3 w-3 shrink-0 text-muted-foreground" />}
          <span className="truncate text-sm font-medium">{alt.headline?.trim() || 'Untitled'}</span>
        </div>
        {alt.body?.trim() && (
          <p className="whitespace-pre-line text-xs text-muted-foreground">{alt.body}</p>
        )}
        {(alt.cta_label?.trim() || alt.cta_url?.trim()) && (
          <p className="truncate text-xs text-muted-foreground">
            {alt.cta_label?.trim() && <span className="font-medium text-foreground">{alt.cta_label}</span>}
            {alt.cta_label?.trim() && alt.cta_url?.trim() && ' · '}
            {alt.cta_url?.trim()}
          </p>
        )}
      </div>
      <div className="flex items-center justify-between gap-2">
        <div className="flex gap-1">
          {isFeed && <span className="status-badge status-active text-[10px]">Feed</span>}
          {isReel && <span className="status-badge status-active text-[10px]">Reel</span>}
          {isCarousel && <span className="status-badge status-active text-[10px]">Carousel</span>}
        </div>
        <PostNowButton alt={alt} instagramAvailable={instagramAvailable} busy={busy} onPostNow={onPostNow} />
      </div>
    </div>
  );
}

// ── New creative (popup) ─────────────────────────────────────────────────────

export function NewCreativeDialog({
  postId,
  open,
  onOpenChange,
  onUploaded,
}: {
  postId: number;
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onUploaded: (p: SocialPostDetail) => void;
}) {
  const [headline, setHeadline] = useState('');
  const feedRef = useRef<HTMLInputElement>(null);
  const reelRef = useRef<HTMLInputElement>(null);
  const carouselRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);

  const submit = async () => {
    const feed = feedRef.current?.files?.[0];
    const reel = reelRef.current?.files?.[0];
    let carousel = Array.from(carouselRef.current?.files ?? []);
    if (!feed && !reel && carousel.length === 0) {
      toast.error('Add a feed, reel, or carousel file');
      return;
    }
    if (carousel.length > 10) {
      toast('Carousels are capped at 10 images, using the first 10.');
      carousel = carousel.slice(0, 10);
    }
    const fd = new FormData();
    fd.append('headline', headline);
    if (feed) fd.append('feed_media', feed);
    if (reel) fd.append('reel_media', reel);
    carousel.forEach((f) => fd.append('carousel_media[]', f));
    setUploading(true);
    try {
      onUploaded(await uploadSocialAlternative(postId, fd));
      toast.success('Uploaded');
      onOpenChange(false);
      setHeadline('');
    } catch (e) {
      toast.error(errorMessage(e, 'Upload failed'));
    } finally {
      setUploading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New creative</DialogTitle>
        </DialogHeader>
        <div className="space-y-3">
          <div className="space-y-1">
            <Label className="text-xs">Headline (optional)</Label>
            <Input value={headline} onChange={(e) => setHeadline(e.target.value)} placeholder="Headline (optional)" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <Label className="text-xs">Feed (4:5) image/video</Label>
              <Input ref={feedRef} type="file" accept="image/*,video/*" />
            </div>
            <div className="space-y-1">
              <Label className="text-xs">Reel (9:16) image/video</Label>
              <Input ref={reelRef} type="file" accept="image/*,video/*" />
            </div>
          </div>
          <div className="space-y-1">
            <Label className="text-xs">Carousel images (2-10, select multiple)</Label>
            <Input ref={carouselRef} type="file" accept="image/*" multiple />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button onClick={submit} disabled={uploading}>
            {uploading ? 'Uploading…' : 'Add creative'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ── Posting log (live) ───────────────────────────────────────────────────────

export function PostingLog({ postId, regionId }: { postId: number; regionId: number }) {
  const [rows, setRows] = useState<SocialDelivery[]>([]);

  useEffect(() => {
    getSocialPostDeliveries(postId).then(setRows).catch(() => undefined);

    const cable = createAuthenticatedConsumer();
    if (!cable) return;
    const sub = cable.subscriptions.create(
      { channel: 'SocialRegionChannel', region_id: regionId },
      {
        received(data) {
          if (data.type !== 'delivery_update' || !data.delivery) return;
          const d: SocialDelivery = data.delivery;
          if (d.social_post_id !== postId) return;
          setRows((prev) => {
            const exists = prev.some((r) => r.id === d.id);
            return exists ? prev.map((r) => (r.id === d.id ? { ...r, ...d } : r)) : [d, ...prev];
          });
        },
      },
    );
    return () => {
      sub.unsubscribe();
      cable.disconnect();
    };
  }, [postId, regionId]);

  if (rows.length === 0) {
    return <p className="py-6 text-center text-sm text-muted-foreground">Nothing posted for this day yet.</p>;
  }

  return (
    <div className="divide-y">
      {rows.map((d) => (
        <div key={d.id} className="flex items-center justify-between py-2 text-sm">
          <div>
            <span className="font-medium">{d.account_name ?? `#${d.integration_id}`}</span>
            <span className="text-muted-foreground"> · {d.channel} · {d.slot}</span>
            {d.error_message && <div className="text-xs text-red-600">{d.error_message}</div>}
          </div>
          <div className="flex items-center gap-2">
            {d.provider_post_id && <span className="text-xs text-muted-foreground">{d.provider_post_id}</span>}
            <span className={statusStyle(d.status)}>{d.status}</span>
          </div>
        </div>
      ))}
    </div>
  );
}
