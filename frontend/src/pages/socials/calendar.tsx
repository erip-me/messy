import { useCallback, useEffect, useState } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import toast from 'react-hot-toast';
import {
  addMonths,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  isSameDay,
  isSameMonth,
  parseISO,
  startOfMonth,
  startOfWeek,
  subMonths,
} from 'date-fns';
import { ChevronLeft, ChevronRight, ArrowLeft, Video } from 'lucide-react';
import {
  getSocialCalendar,
  SocialCalendar,
  SocialPostSummary,
} from '@/api/socials';
import { Button } from '@/components/ui/button';
import { FacebookIcon, InstagramIcon } from '@/components/ui/channel-icon';
import { statusStyle, isVideoType, formatHour } from './shared';

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

export function SocialsCalendarPage() {
  const { regionId } = useParams();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const id = Number(regionId);

  const [month, setMonth] = useState(() => {
    const m = searchParams.get('month');
    return m ? startOfMonth(parseISO(`${m}-01`)) : startOfMonth(new Date());
  });
  const [calendar, setCalendar] = useState<SocialCalendar | null>(null);
  const [loading, setLoading] = useState(true);

  const monthKey = format(month, 'yyyy-MM');

  const loadCalendar = useCallback(async () => {
    setLoading(true);
    try {
      setCalendar(await getSocialCalendar(id, monthKey));
    } catch {
      toast.error('Failed to load calendar');
    } finally {
      setLoading(false);
    }
  }, [id, monthKey]);

  useEffect(() => {
    loadCalendar();
  }, [loadCalendar]);

  const openDay = (date: Date) => navigate(`/socials/${id}/${format(date, 'yyyy-MM-dd')}`);

  const days = eachDayOfInterval({
    start: startOfWeek(startOfMonth(month), { weekStartsOn: 1 }),
    end: endOfWeek(endOfMonth(month), { weekStartsOn: 1 }),
  });

  const byDate = new Map<string, SocialPostSummary>();
  (calendar?.posts ?? []).forEach((p) => byDate.set(p.date, p));
  const today = calendar ? parseISO(calendar.today) : new Date();

  return (
    <div className="flex h-full flex-col p-6">
      <div className="mb-6 flex shrink-0 flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <Button variant="outline" size="sm" onClick={() => navigate('/socials')}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div className="min-w-0">
            <h1 className="page-heading truncate">{calendar?.region.name ?? 'Calendar'}</h1>
            <p className="page-subtitle">
              {calendar?.region.timezone} · default {formatHour(calendar?.region.post_hour ?? 9)}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={() => setMonth(subMonths(month, 1))}>
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <span className="flex-1 text-center font-medium sm:w-36 sm:flex-none">{format(month, 'MMMM yyyy')}</span>
          <Button variant="outline" size="sm" onClick={() => setMonth(addMonths(month, 1))}>
            <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {!calendar?.region.configured && (
        <div className="mb-4 shrink-0 rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
          This region has no linked, configured Meta account yet. Content won't post until one is linked.
        </div>
      )}

      {/* Mobile: agenda / schedule list — a grid of 7 tiny columns is unusable on a phone */}
      <div className="min-h-0 flex-1 space-y-px overflow-y-auto rounded-lg border bg-border md:hidden">
        {days
          .filter((day) => isSameMonth(day, month))
          .map((day) => {
            const key = format(day, 'yyyy-MM-dd');
            const summary = byDate.get(key);
            const isToday = isSameDay(day, today);
            return (
              <button
                key={key}
                onClick={() => openDay(day)}
                disabled={loading}
                className="flex w-full items-center gap-3 bg-background p-3 text-left transition-colors hover:bg-accent"
              >
                <div className="w-11 shrink-0 text-center">
                  <div className="text-[11px] uppercase text-muted-foreground">{format(day, 'EEE')}</div>
                  <div className={`text-lg leading-none ${isToday ? 'font-bold text-primary' : 'font-medium'}`}>
                    {format(day, 'd')}
                  </div>
                </div>
                {summary?.thumb_url ? (
                  isVideoType(summary.thumb_content_type) ? (
                    <video src={summary.thumb_url} className="h-12 w-12 shrink-0 rounded object-cover" muted preload="metadata" />
                  ) : (
                    <img src={summary.thumb_url} alt="" className="h-12 w-12 shrink-0 rounded object-cover" />
                  )
                ) : (
                  <div className="h-12 w-12 shrink-0 rounded bg-muted" />
                )}
                <div className="min-w-0 flex-1">
                  {summary?.title ? (
                    <p className="truncate text-sm font-medium text-foreground">{summary.title}</p>
                  ) : (
                    <p className="text-sm text-muted-foreground">{summary ? 'Untitled' : 'No post'}</p>
                  )}
                  {summary && (
                    <div className="mt-1 flex items-center gap-2">
                      <span className={`${statusStyle(summary.status)} px-1.5 py-0.5 text-[10px]`}>{summary.status}</span>
                      {summary.post_hour != null && (
                        <span className="text-[11px] text-muted-foreground">{formatHour(summary.effective_post_hour)}</span>
                      )}
                      {summary.has_video && <Video className="h-3.5 w-3.5 text-muted-foreground" />}
                      {summary.posted_channels.length > 0 && (
                        <span className="ml-auto flex items-center gap-1 text-muted-foreground">
                          {summary.posted_channels.includes('facebook') && <FacebookIcon className="h-4 w-4" />}
                          {summary.posted_channels.includes('instagram') && <InstagramIcon className="h-4 w-4" />}
                        </span>
                      )}
                    </div>
                  )}
                </div>
                <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground" />
              </button>
            );
          })}
      </div>

      {/* Desktop: full month grid */}
      <div
        className="hidden min-h-0 flex-1 grid-cols-7 gap-px overflow-hidden rounded-lg border bg-border md:grid"
        style={{ gridTemplateRows: `auto repeat(${days.length / 7}, minmax(96px, 1fr))` }}
      >
        {WEEKDAYS.map((d) => (
          <div key={d} className="bg-muted px-2 py-2 text-center text-xs font-medium text-muted-foreground">
            {d}
          </div>
        ))}
        {days.map((day) => {
          const key = format(day, 'yyyy-MM-dd');
          const summary = byDate.get(key);
          const inMonth = isSameMonth(day, month);
          const isToday = isSameDay(day, today);
          return (
            <button
              key={key}
              onClick={() => openDay(day)}
              disabled={loading}
              className={`flex min-h-[96px] flex-col gap-1 bg-background p-2 text-left transition-colors hover:bg-accent ${
                inMonth ? '' : 'opacity-40'
              }`}
            >
              <div className="flex items-center justify-between">
                <span className={`text-xs ${isToday ? 'font-bold text-primary' : 'text-muted-foreground'}`}>
                  {format(day, 'd')}
                </span>
                {summary?.has_video && <Video className="h-3 w-3 text-muted-foreground" />}
              </div>
              {summary?.status === 'pending' && summary.thumbs.length > 1 ? (
                <div className="grid grid-cols-3 gap-0.5">
                  {summary.thumbs.map((thumb, i) => (
                    <div key={i} className="relative overflow-hidden rounded">
                      {isVideoType(thumb.content_type) ? (
                        <video src={thumb.url} className="h-8 w-full object-cover" muted preload="metadata" />
                      ) : (
                        <img src={thumb.url} alt="" className="h-8 w-full object-cover" />
                      )}
                    </div>
                  ))}
                </div>
              ) : (
                summary?.thumb_url && (
                  <div className="relative overflow-hidden rounded">
                    {isVideoType(summary.thumb_content_type) ? (
                      <video src={summary.thumb_url} className="h-12 w-full object-cover" muted preload="metadata" />
                    ) : (
                      <img src={summary.thumb_url} alt="" className="h-12 w-full object-cover" />
                    )}
                  </div>
                )
              )}
              {summary?.title && (
                <p className="truncate text-[11px] font-medium leading-tight text-foreground">{summary.title}</p>
              )}
              {summary && (
                <div className="mt-auto flex items-center gap-1">
                  <span className={`${statusStyle(summary.status)} px-1.5 py-0.5 text-[10px]`}>
                    {summary.status}
                  </span>
                  {summary.post_hour != null && (
                    <span className="text-[10px] text-muted-foreground">{formatHour(summary.effective_post_hour)}</span>
                  )}
                  {summary.posted_channels.length > 0 && (
                    <span className="ml-auto flex items-center gap-1 text-muted-foreground" title="Posted to">
                      {summary.posted_channels.includes('facebook') && <FacebookIcon className="h-3.5 w-3.5" />}
                      {summary.posted_channels.includes('instagram') && <InstagramIcon className="h-3.5 w-3.5" />}
                    </span>
                  )}
                </div>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}
