import { useCallback, useEffect, useRef, useState } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import toast from 'react-hot-toast';
import { addDays, format, parseISO } from 'date-fns';
import { ChevronLeft, ChevronRight, ArrowLeft, Video, Send, Plus, CheckCircle2 } from 'lucide-react';
import {
  createSocialPost,
  updateSocialPost,
  publishSocialPostNow,
  updateSocialAlternative,
  deleteSocialAlternative,
  postSocialAlternativeNow,
  SocialPostDetail,
  SocialAlternative,
  SocialSlot,
  SocialChannelName,
} from '@/api/socials';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { statusStyle, isVideoAlt, formatHour, errorMessage } from './shared';
import {
  LightboxContext,
  collectLightboxItems,
  Lightbox,
  AlternativeCard,
  CreativePreview,
  NewCreativeDialog,
  PostingLog,
} from './components';

export function SocialsPostPage() {
  const { regionId, date } = useParams();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const id = Number(regionId);

  const { confirm, ConfirmDialog } = useConfirm();
  const [post, setPost] = useState<SocialPostDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [activeAltId, setActiveAltId] = useState('');
  const [newOpen, setNewOpen] = useState(false);
  const [lightboxIndex, setLightboxIndex] = useState<number | null>(null);

  // Latest ?creative=<key> deeplink value, read by the loader below without
  // adding searchParams to its deps (which would refetch the post on every URL
  // change, including our own writes).
  const creativeParamRef = useRef<string | null>(null);
  creativeParamRef.current = searchParams.get('creative');

  const lightboxItems = post ? collectLightboxItems(post.alternatives) : [];

  const openLightbox = useCallback(
    (key: string) => {
      const i = lightboxItems.findIndex((it) => it.key === key);
      if (i >= 0) setLightboxIndex(i);
    },
    [lightboxItems],
  );

  // Mirror the open creative into the URL (?creative=<key>) so any lightbox view
  // is a shareable deeplink. Skipped while loading so an incoming deeplink isn't
  // wiped before the day's creatives are in; once loaded it also cleans up a
  // stale param that no longer matches a creative.
  const currentKey = lightboxIndex == null ? null : lightboxItems[lightboxIndex]?.key ?? null;
  useEffect(() => {
    if (loading) return;
    setSearchParams(
      (prev) => {
        const next = new URLSearchParams(prev);
        if (currentKey) next.set('creative', currentKey);
        else next.delete('creative');
        return next;
      },
      { replace: true },
    );
  }, [currentKey, loading, setSearchParams]);

  // Step to the previous/next calendar day, keeping the same region.
  const goToDay = useCallback(
    (delta: number) => {
      if (!date) return;
      navigate(`/socials/${id}/${format(addDays(parseISO(String(date)), delta), 'yyyy-MM-dd')}`);
    },
    [date, id, navigate],
  );

  // Load (find-or-create) the day's post. If the URL carries a ?creative=<key>
  // deeplink, reopen that creative in the lightbox once the day has loaded.
  useEffect(() => {
    let active = true;
    const deeplinkKey = creativeParamRef.current;
    setLoading(true);
    setLightboxIndex(null);
    createSocialPost(id, String(date))
      .then((p) => {
        if (!active) return;
        setPost(p);
        const items = collectLightboxItems(p.alternatives);
        const i = deeplinkKey ? items.findIndex((it) => it.key === deeplinkKey) : -1;
        setLightboxIndex(i >= 0 ? i : null);
      })
      .catch(() => toast.error('Failed to load day'))
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [id, date]);

  // Close the lightbox if its target disappears (e.g. a creative was deleted).
  useEffect(() => {
    if (lightboxIndex != null && lightboxIndex >= lightboxItems.length) setLightboxIndex(null);
  }, [lightboxIndex, lightboxItems.length]);

  // While the lightbox is open, keep the selected creative tab matched to the
  // image on screen, so paging through media also switches the underlying tab.
  useEffect(() => {
    if (lightboxIndex == null) return;
    const item = lightboxItems[lightboxIndex];
    if (item) setActiveAltId(item.key.split('-')[0]);
  }, [lightboxIndex, lightboxItems]);

  // Left/right arrows page between days — but only when the lightbox is closed
  // (it owns the arrows while open) and focus isn't in a text field.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (lightboxIndex != null) return;
      if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      const el = document.activeElement as HTMLElement | null;
      const tag = el?.tagName;
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || el?.isContentEditable) return;
      e.preventDefault();
      goToDay(e.key === 'ArrowRight' ? 1 : -1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [lightboxIndex, goToDay]);

  // Keep the selected creative tab valid as alternatives are added/removed.
  useEffect(() => {
    if (!post) return;
    const ids = post.alternatives.map((a) => String(a.id));
    setActiveAltId((cur) => (ids.includes(cur) ? cur : ids[0] ?? ''));
  }, [post]);

  const onChange = (p: SocialPostDetail) => setPost(p);
  const goBack = () => navigate(`/socials/${id}?month=${String(date).slice(0, 7)}`);

  if (loading || !post) {
    return (
      <div className="p-6">
        <PageSkeleton variant="cards" cards={2} />
      </div>
    );
  }

  const run = async (fn: () => Promise<SocialPostDetail>, ok?: string) => {
    setBusy(true);
    try {
      onChange(await fn());
      if (ok) toast.success(ok);
    } catch (e) {
      toast.error(errorMessage(e, 'Something went wrong'));
    } finally {
      setBusy(false);
    }
  };

  const toggleSlot = (alt: SocialAlternative, slot: SocialSlot) => {
    const field =
      slot === 'feed' ? 'feed_alternative_id' : slot === 'reel' ? 'reel_alternative_id' : 'carousel_alternative_id';
    const current = post[field];
    const value = current === alt.id ? null : alt.id;
    run(() => updateSocialPost(post.id, { [field]: value }));
  };

  const setHour = (value: string) => {
    run(() => updateSocialPost(post.id, { post_hour: value === 'default' ? null : Number(value) }));
  };

  const markReady = (ready: boolean) => run(() => updateSocialPost(post.id, { ready }), ready ? 'Marked ready' : 'Unmarked');
  const publishNow = () => run(() => publishSocialPostNow(post.id), 'Publishing now');

  // Manually publish a single creative — available on any day/status.
  const postNow = (alt: SocialAlternative, slots: SocialSlot[], channels: SocialChannelName[]) =>
    run(async () => {
      let latest = post;
      for (const slot of slots) latest = await postSocialAlternativeNow(alt.id, slot, channels);
      return latest;
    }, 'Posting now');

  const removeAlt = async (alt: SocialAlternative) => {
    const ok = await confirm({
      title: 'Delete this variant?',
      description: 'Its images/videos are removed too.',
      confirmLabel: 'Delete',
      variant: 'destructive',
    });
    if (ok) run(() => deleteSocialAlternative(alt.id), 'Deleted');
  };

  const hasSelection =
    post.feed_alternative_id != null || post.reel_alternative_id != null || post.carousel_alternative_id != null;

  return (
    <LightboxContext.Provider value={openLightbox}>
    <div className="p-6">
      <div className="mb-6 flex items-center gap-3">
        <Button variant="outline" size="sm" onClick={goBack}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div className="flex-1">
          <h1 className="page-heading flex items-center gap-3">
            {format(parseISO(post.date), 'EEEE, MMM d, yyyy')}
            <span className={statusStyle(post.status)}>{post.status}</span>
          </h1>
          <p className="page-subtitle">{post.region.name}</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={() => goToDay(-1)}>
            <ChevronLeft className="h-4 w-4" /> Prev day
          </Button>
          <Button variant="outline" size="sm" onClick={() => goToDay(1)}>
            Next day <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
      </div>

      <div className="mx-auto max-w-6xl space-y-4">
        {post.publish_error && (
          <div className="rounded-md border border-red-200 bg-red-50 p-2 text-sm text-red-700">{post.publish_error}</div>
        )}

        <Tabs defaultValue="content">
          <TabsList>
            <TabsTrigger value="content">Content</TabsTrigger>
            <TabsTrigger value="log">Posting log</TabsTrigger>
          </TabsList>

          <TabsContent value="content" className="space-y-4">
            {/* Controls */}
            <div className="flex flex-wrap items-center gap-3 rounded-md border p-3">
              <div className="flex items-center gap-2">
                <Label className="text-xs">Post time</Label>
                <Select value={post.post_hour == null ? 'default' : String(post.post_hour)} onValueChange={setHour}>
                  <SelectTrigger className="h-8 w-40">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="default">Region default ({formatHour(post.region.post_hour)})</SelectItem>
                    {Array.from({ length: 24 }, (_, h) => (
                      <SelectItem key={h} value={String(h)}>
                        {formatHour(h)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="ml-auto flex gap-2">
                {post.status === 'ready' ? (
                  <Button size="sm" variant="outline" onClick={() => markReady(false)} disabled={busy}>
                    Unmark ready
                  </Button>
                ) : (
                  <Button size="sm" onClick={() => markReady(true)} disabled={busy || post.past || !hasSelection}>
                    <CheckCircle2 className="mr-2 h-4 w-4" /> Mark ready
                  </Button>
                )}
                {post.postable_today && hasSelection && (
                  <Button size="sm" variant="outline" onClick={publishNow} disabled={busy}>
                    <Send className="mr-2 h-4 w-4" /> Publish now
                  </Button>
                )}
              </div>
            </div>

            {post.past && post.status !== 'posted' && (
              <p className="text-xs text-muted-foreground">This day is in the past, so it can't be marked ready or scheduled.</p>
            )}

            {post.alternatives.length === 0 ? (
              <div className="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">
                No creatives yet.{' '}
                <Button variant="link" size="sm" className="h-auto p-0" onClick={() => setNewOpen(true)} disabled={busy}>
                  Add one
                </Button>
              </div>
            ) : post.status !== 'pending' ? (
              // Decided day: a compact read-only gallery of the creatives.
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {post.alternatives.map((alt) => (
                  <CreativePreview
                    key={alt.id}
                    alt={alt}
                    isFeed={post.feed_alternative_id === alt.id}
                    isReel={post.reel_alternative_id === alt.id}
                    isCarousel={post.carousel_alternative_id === alt.id}
                    busy={busy}
                    instagramAvailable={post.region.instagram_available}
                    onPostNow={(slots, channels) => postNow(alt, slots, channels)}
                  />
                ))}
              </div>
            ) : (
              <Tabs value={activeAltId} onValueChange={setActiveAltId}>
                <div className="flex flex-wrap items-center gap-2">
                  <TabsList>
                    {post.alternatives.map((alt, i) => (
                      <TabsTrigger key={alt.id} value={String(alt.id)} className="max-w-[11rem]">
                        {isVideoAlt(alt) && <Video className="mr-1 h-3 w-3 shrink-0" />}
                        <span className="truncate">{alt.headline?.trim() || `Creative ${i + 1}`}</span>
                      </TabsTrigger>
                    ))}
                  </TabsList>
                  <Button variant="ghost" size="sm" onClick={() => setNewOpen(true)} disabled={busy}>
                    <Plus className="mr-1 h-4 w-4" /> New creative
                  </Button>
                </div>
                {post.alternatives.map((alt) => (
                  <TabsContent key={alt.id} value={String(alt.id)} className="pt-4">
                    <AlternativeCard
                      alt={alt}
                      isFeed={post.feed_alternative_id === alt.id}
                      isReel={post.reel_alternative_id === alt.id}
                      isCarousel={post.carousel_alternative_id === alt.id}
                      busy={busy}
                      instagramAvailable={post.region.instagram_available}
                      onToggleSlot={(slot) => toggleSlot(alt, slot)}
                      onSaveCopy={(data) => run(() => updateSocialAlternative(alt.id, data))}
                      onDelete={() => removeAlt(alt)}
                      onPostNow={(slots, channels) => postNow(alt, slots, channels)}
                    />
                  </TabsContent>
                ))}
              </Tabs>
            )}

            <NewCreativeDialog
              postId={post.id}
              open={newOpen}
              onOpenChange={setNewOpen}
              onUploaded={(updated) => {
                onChange(updated);
                const last = updated.alternatives[updated.alternatives.length - 1];
                if (last) setActiveAltId(String(last.id));
              }}
            />
          </TabsContent>

          <TabsContent value="log">
            <PostingLog postId={post.id} regionId={id} />
          </TabsContent>
        </Tabs>
        {ConfirmDialog}
      </div>

      <Lightbox items={lightboxItems} index={lightboxIndex} setIndex={setLightboxIndex} />
    </div>
    </LightboxContext.Provider>
  );
}
