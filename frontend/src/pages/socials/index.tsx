import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import toast from 'react-hot-toast';
import { CalendarDays, Plus, Trash2, Pencil } from 'lucide-react';
import { RootState } from '@/store';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';
import { getIntegrations, Integration } from '@/api/integrations';
import {
  getSocialRegions,
  createSocialRegion,
  updateSocialRegion,
  deleteSocialRegion,
  getMetaPages,
  getMetaAdAccounts,
  getMetaInstagramAccounts,
  getLinkedinOauthUrl,
  getLinkedinOrganizations,
  SocialRegion,
  SocialRegionInput,
  MetaOption,
  MetaInstagramAccount,
} from '@/api/socials';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import { SearchableSelect, SearchableSelectOption } from '@/components/ui/searchable-select';
import { CountryMultiSelect } from '@/components/ui/country-multi-select';
import { HashtagInput } from '@/components/ui/hashtag-input';
import { FacebookIcon, InstagramIcon, LinkedinIcon } from '@/components/ui/channel-icon';
import { useConfirm } from '@/components/ui/confirm-dialog';

// Full IANA timezone list (falls back to a small set on older engines).
const tzSupported = (Intl as { supportedValuesOf?: (key: string) => string[] }).supportedValuesOf;
const TIMEZONE_OPTIONS: SearchableSelectOption[] = (
  tzSupported
    ? tzSupported('timeZone')
    : ['UTC', 'Europe/Dublin', 'Europe/London', 'Europe/Amsterdam', 'Asia/Karachi', 'Asia/Ho_Chi_Minh', 'Asia/Dubai', 'America/New_York', 'America/Los_Angeles']
).map((tz) => ({ value: tz, label: tz }));

const HOURS = Array.from({ length: 24 }, (_, h) => h);

const emptyForm: SocialRegionInput = {
  name: '',
  timezone: 'UTC',
  post_hour: 9,
  countries: [],
  hashtags: [],
  active: true,
  integration_id: null,
  page_id: null,
  page_name: null,
  ig_business_account_id: null,
  ig_username: null,
  ig_page_id: null,
  ad_account_id: null,
  linkedin_integration_id: null,
  linkedin_org_id: null,
  linkedin_org_name: null,
  post_to_facebook: true,
  post_to_instagram: true,
  post_to_linkedin: true,
};

const metaLabel = (i: Integration) => (i.config?.label as string) || i.name || i.vendor;
// A LinkedIn credential is "connected" once it holds an access token (masked to
// the sentinel in the API, but its presence still signals a completed connect).
const linkedinConnected = (i?: Integration) => Boolean(i?.config?.access_token);

export function SocialsIndexPage() {
  const navigate = useNavigate();
  const activeEnvId = useActiveEnvironment();
  const user = useSelector((state: RootState) => state.auth.user);
  // Show the manage controls unless the user is an explicit member (an unknown/
  // stale role still shows them — the backend enforces admin either way).
  const isAdmin = user?.role !== 'member';

  const [regions, setRegions] = useState<SocialRegion[]>([]);
  const [metaAccounts, setMetaAccounts] = useState<Integration[]>([]);
  const [linkedinAccounts, setLinkedinAccounts] = useState<Integration[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<SocialRegion | null>(null);
  const [form, setForm] = useState<SocialRegionInput>(emptyForm);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [saving, setSaving] = useState(false);

  // Meta discovery for the target dropdowns.
  const [pages, setPages] = useState<MetaOption[]>([]);
  const [adAccounts, setAdAccounts] = useState<MetaOption[]>([]);
  const [igAccounts, setIgAccounts] = useState<MetaInstagramAccount[]>([]);
  const [loadingMeta, setLoadingMeta] = useState(false);

  // LinkedIn discovery for the organization dropdown.
  const [orgs, setOrgs] = useState<MetaOption[]>([]);
  const [loadingOrgs, setLoadingOrgs] = useState(false);
  const [connectingLinkedin, setConnectingLinkedin] = useState(false);
  const selectedLinkedin = linkedinAccounts.find((a) => a.id === form.linkedin_integration_id);
  const isLinkedinConnected = linkedinConnected(selectedLinkedin);

  const { confirm, ConfirmDialog } = useConfirm();

  useEffect(() => {
    load();
  }, [activeEnvId]);

  // Load the token's Pages, ad accounts, and Instagram accounts whenever a
  // credential is chosen. A Meta business can link several IG accounts (one per
  // Page), so the user picks one rather than it being auto-resolved.
  useEffect(() => {
    if (!dialogOpen || !form.integration_id) {
      setPages([]);
      setAdAccounts([]);
      setIgAccounts([]);
      return;
    }
    const integrationId = form.integration_id;
    let active = true;
    setLoadingMeta(true);
    Promise.all([
      getMetaPages(integrationId),
      getMetaAdAccounts(integrationId),
      getMetaInstagramAccounts(integrationId),
    ])
      .then(([p, a, igs]) => {
        if (!active) return;
        setPages(p);
        setAdAccounts(a);
        setIgAccounts(igs);
        // Fill the display names for a stored Page / IG account that lack one.
        setForm((f) => {
          let next = f;
          if (f.page_id && !f.page_name) {
            const match = p.find((pg) => pg.id === f.page_id);
            if (match) next = { ...next, page_name: match.name };
          }
          if (f.ig_business_account_id && !f.ig_username) {
            const ig = igs.find((i) => i.id === f.ig_business_account_id);
            if (ig) next = { ...next, ig_username: ig.username, ig_page_id: next.ig_page_id ?? ig.page_id };
          }
          return next;
        });
      })
      .catch(() => toast.error('Failed to load Pages for this account'))
      .finally(() => active && setLoadingMeta(false));
    return () => {
      active = false;
    };
  }, [dialogOpen, form.integration_id]);

  // Load the LinkedIn organizations a connected credential can post to.
  useEffect(() => {
    if (!dialogOpen || !form.linkedin_integration_id || !isLinkedinConnected) {
      setOrgs([]);
      return;
    }
    const integrationId = form.linkedin_integration_id;
    let active = true;
    setLoadingOrgs(true);
    getLinkedinOrganizations(integrationId)
      .then((list) => {
        if (!active) return;
        setOrgs(list);
        // Fill the display name for a stored org that has none yet.
        setForm((f) => {
          if (!f.linkedin_org_id || f.linkedin_org_name) return f;
          const match = list.find((o) => o.id === f.linkedin_org_id);
          return match ? { ...f, linkedin_org_name: match.name } : f;
        });
      })
      .catch(() => toast.error('Failed to load LinkedIn organizations'))
      .finally(() => active && setLoadingOrgs(false));
    return () => {
      active = false;
    };
  }, [dialogOpen, form.linkedin_integration_id, isLinkedinConnected]);

  // Surface the outcome of the LinkedIn OAuth round-trip (backend redirects back
  // here with ?connected / ?error once consent completes).
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get('connected') === 'linkedin') {
      toast.success('LinkedIn connected');
    } else if (params.get('error')) {
      toast.error('LinkedIn connection failed');
    }
    if (params.has('connected') || params.has('error')) {
      window.history.replaceState({}, '', window.location.pathname);
    }
  }, []);

  const load = async () => {
    setLoading(true);
    try {
      const [regionList, integrations] = await Promise.all([getSocialRegions(), getIntegrations()]);
      setRegions(regionList);
      setMetaAccounts(integrations.filter((i) => i.type === 'MetaSocialIntegration'));
      setLinkedinAccounts(integrations.filter((i) => i.type === 'LinkedinSocialIntegration'));
    } catch {
      toast.error('Failed to load regions');
    } finally {
      setLoading(false);
    }
  };

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm);
    setDialogOpen(true);
  };

  const openEdit = (region: SocialRegion) => {
    setEditing(region);
    setForm({
      name: region.name,
      timezone: region.timezone,
      post_hour: region.post_hour,
      countries: region.countries,
      hashtags: region.hashtags,
      active: region.active,
      integration_id: region.integration_id,
      page_id: region.page_id,
      page_name: region.page_name,
      ig_business_account_id: region.ig_business_account_id,
      ig_username: region.ig_username,
      ig_page_id: region.ig_page_id,
      ad_account_id: region.ad_account_id,
      linkedin_integration_id: region.linkedin_integration_id,
      linkedin_org_id: region.linkedin_org_id,
      linkedin_org_name: region.linkedin_org_name,
      post_to_facebook: region.post_to_facebook,
      post_to_instagram: region.post_to_instagram,
      post_to_linkedin: region.post_to_linkedin,
    });
    setDialogOpen(true);
  };

  // Pick a credential (token) — reset the target that depended on the old one.
  const selectToken = (value: string) => {
    setForm((f) => ({
      ...f,
      integration_id: value ? Number(value) : null,
      page_id: null,
      page_name: null,
      ig_business_account_id: null,
      ig_username: null,
      ig_page_id: null,
      ad_account_id: null,
    }));
  };

  // Pick the Facebook Page. The Instagram account is chosen independently, so
  // it is not touched here.
  const selectPage = (pageId: string) => {
    const page = pages.find((p) => p.id === pageId);
    setForm((f) => ({
      ...f,
      page_id: pageId,
      page_name: page?.name ?? f.page_name ?? null,
    }));
  };

  // Pick the Instagram account. It carries the Page whose token publishes to it.
  const selectIg = (igId: string) => {
    const ig = igAccounts.find((a) => a.id === igId);
    setForm((f) => ({
      ...f,
      ig_business_account_id: igId || null,
      ig_username: ig?.username ?? null,
      ig_page_id: ig?.page_id ?? null,
    }));
  };

  // Pick a LinkedIn credential — reset the org that depended on the old one.
  const selectLinkedinToken = (value: string) => {
    setForm((f) => ({
      ...f,
      linkedin_integration_id: value ? Number(value) : null,
      linkedin_org_id: null,
      linkedin_org_name: null,
    }));
  };

  const selectOrg = (orgId: string) => {
    const org = orgs.find((o) => o.id === orgId);
    setForm((f) => ({ ...f, linkedin_org_id: orgId, linkedin_org_name: org?.name ?? f.linkedin_org_name ?? null }));
  };

  // Kick off the LinkedIn OAuth consent. The backend callback redirects back to
  // this page, where the mount effect toasts the outcome.
  const connectLinkedin = async () => {
    if (!form.linkedin_integration_id) return;
    setConnectingLinkedin(true);
    try {
      const url = await getLinkedinOauthUrl(form.linkedin_integration_id);
      window.location.href = url;
    } catch (e) {
      toast.error(errorMessage(e, 'Failed to start LinkedIn connect'));
      setConnectingLinkedin(false);
    }
  };

  const save = async () => {
    if (!form.name?.trim()) {
      toast.error('Name is required');
      return;
    }
    setSaving(true);
    try {
      if (editing) {
        const updated = await updateSocialRegion(editing.id, form);
        setRegions((prev) => prev.map((r) => (r.id === updated.id ? updated : r)));
        setEditing(updated);
      } else {
        const created = await createSocialRegion(form);
        setRegions((prev) => [...prev, created]);
        setEditing(created);
      }
      toast.success('Saved');
      setDialogOpen(false);
    } catch (e) {
      toast.error(errorMessage(e, 'Failed to save region'));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (region: SocialRegion) => {
    const ok = await confirm({
      title: `Delete ${region.name}?`,
      description: 'This removes the region and its whole content calendar. This cannot be undone.',
      confirmLabel: 'Delete',
      variant: 'destructive',
    });
    if (!ok) return;
    try {
      await deleteSocialRegion(region.id);
      setRegions((prev) => prev.filter((r) => r.id !== region.id));
      toast.success('Region deleted');
    } catch {
      toast.error('Failed to delete region');
    }
  };

  const pageOptions: SearchableSelectOption[] = pages.map((p) => ({ value: p.id, label: p.name }));
  const adOptions: SearchableSelectOption[] = adAccounts.map((a) => ({
    value: a.id,
    label: `${a.name} (${a.id})`,
  }));
  const orgOptions: SearchableSelectOption[] = orgs.map((o) => ({ value: o.id, label: o.name }));
  const igOptions: SearchableSelectOption[] = [
    { value: '', label: 'None' },
    ...igAccounts.map((a) => ({
      value: a.id,
      label: a.page_name ? `${a.username ? `@${a.username}` : a.id} · ${a.page_name}` : a.username ? `@${a.username}` : a.id,
    })),
  ];

  return (
    <div className="p-6">
      <div className="mb-6 flex items-start justify-between">
        <div>
          <h1 className="page-heading">Socials</h1>
          <p className="page-subtitle">Per-region content calendars that auto-post to Facebook, Instagram &amp; LinkedIn.</p>
        </div>
        {isAdmin && (
          <Button onClick={openCreate}>
            <Plus className="mr-2 h-4 w-4" /> New region
          </Button>
        )}
      </div>

      {loading ? (
        <PageSkeleton variant="cards" cards={3} />
      ) : regions.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center text-muted-foreground">
            {isAdmin
              ? 'No regions yet. Create one, pick its Page, then open its calendar.'
              : 'No regions yet. Ask an account admin to set one up.'}
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {regions.map((region) => (
            <Card key={region.id}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0">
                <CardTitle className="text-base">{region.name}</CardTitle>
                {region.configured ? (
                  <Badge className="bg-green-100 text-green-700">Ready</Badge>
                ) : (
                  <Badge variant="outline">No target</Badge>
                )}
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="text-sm text-muted-foreground">
                  {region.timezone} · posts at {formatHour(region.post_hour)}
                </div>
                <div className="flex flex-wrap items-center gap-2">
                  {region.page_id ? (
                    <Badge variant="secondary" className="gap-1">
                      <FacebookIcon className="h-3 w-3" /> {region.page_name || region.page_id}
                    </Badge>
                  ) : (
                    <span className="text-xs text-muted-foreground">No Page selected</span>
                  )}
                  {region.ig_username && (
                    <Badge variant="secondary" className="gap-1">
                      <InstagramIcon className="h-3 w-3" /> @{region.ig_username}
                    </Badge>
                  )}
                  {region.linkedin_org_id && (
                    <Badge variant="secondary" className="gap-1">
                      <LinkedinIcon className="h-3 w-3" /> {region.linkedin_org_name || region.linkedin_org_id}
                    </Badge>
                  )}
                </div>
                <div className="flex gap-2 pt-1">
                  <Button size="sm" onClick={() => navigate(`/socials/${region.id}`)}>
                    <CalendarDays className="mr-2 h-4 w-4" /> Calendar
                  </Button>
                  {isAdmin && (
                    <>
                      <Button size="sm" variant="outline" onClick={() => openEdit(region)}>
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button size="sm" variant="outline" onClick={() => remove(region)}>
                        <Trash2 className="h-4 w-4 text-destructive" />
                      </Button>
                    </>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-h-[90vh] max-w-4xl overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{editing ? `Edit ${editing.name}` : 'New region'}</DialogTitle>
          </DialogHeader>
          <div className="grid gap-6 md:grid-cols-2">
            {/* Left column: region settings + publishing target */}
            <div className="space-y-4">
              <div>
                <Label>Name</Label>
                <Input
                  value={form.name ?? ''}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="e.g. Pakistan"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label>Timezone</Label>
                  <SearchableSelect
                    options={TIMEZONE_OPTIONS}
                    value={form.timezone}
                    onValueChange={(v) => setForm({ ...form, timezone: v })}
                    placeholder="Select timezone"
                  />
                </div>
                <div>
                  <Label>Default post time</Label>
                  <Select
                    value={String(form.post_hour ?? 9)}
                    onValueChange={(v) => setForm({ ...form, post_hour: Number(v) })}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {HOURS.map((h) => (
                        <SelectItem key={h} value={String(h)}>
                          {formatHour(h)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div>
                <Label className="mb-2 block">Target countries (for ad targeting)</Label>
                <CountryMultiSelect
                  value={form.countries ?? []}
                  onChange={(codes) => setForm({ ...form, countries: codes })}
                />
              </div>
              <div className="flex items-center gap-2">
                <Switch
                  checked={form.active ?? true}
                  onCheckedChange={(v) => setForm({ ...form, active: v })}
                />
                <Label>Active (included in the auto-posting sweep)</Label>
              </div>

              {/* Publishing target */}
              <div className="space-y-4 border-t pt-4">
                <div>
                  <Label className="mb-2 block">Meta account (credential)</Label>
                {metaAccounts.length === 0 ? (
                  <p className="text-sm text-muted-foreground">
                    No Meta accounts yet. Add one under Channels (Integrations) first.
                  </p>
                ) : (
                  <Select value={form.integration_id ? String(form.integration_id) : ''} onValueChange={selectToken}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select a Meta credential" />
                    </SelectTrigger>
                    <SelectContent>
                      {metaAccounts.map((acc) => (
                        <SelectItem key={acc.id} value={String(acc.id)}>
                          {metaLabel(acc)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </div>

              {form.integration_id && (
                <>
                  <div>
                    <Label className="mb-2 block">Facebook Page</Label>
                    <SearchableSelect
                      options={pageOptions}
                      value={form.page_id ?? undefined}
                      onValueChange={selectPage}
                      placeholder={loadingMeta ? 'Loading Pages…' : 'Select a Page'}
                    />
                  </div>

                  <div>
                    <Label className="mb-2 block">Instagram account</Label>
                    <SearchableSelect
                      options={igOptions}
                      value={form.ig_business_account_id ?? undefined}
                      onValueChange={selectIg}
                      placeholder={
                        loadingMeta
                          ? 'Loading Instagram accounts…'
                          : igAccounts.length
                            ? 'Select an Instagram account'
                            : 'No Instagram accounts linked'
                      }
                    />
                    <p className="mt-1 text-xs text-muted-foreground">
                      Every Instagram account linked to this Meta business. Publishing uses the Facebook Page that
                      account is connected to.
                    </p>
                  </div>

                  <div>
                    <Label className="mb-2 block">Ad account (optional)</Label>
                    <SearchableSelect
                      options={adOptions}
                      value={form.ad_account_id ?? undefined}
                      onValueChange={(v) => setForm({ ...form, ad_account_id: v })}
                      placeholder={loadingMeta ? 'Loading…' : 'None'}
                    />
                  </div>

                  <div className="space-y-2">
                    <Label className="block">Publish to</Label>
                    <label className="flex items-center gap-2 text-sm">
                      <Switch
                        checked={form.post_to_facebook ?? true}
                        onCheckedChange={(v) => setForm({ ...form, post_to_facebook: v })}
                      />
                      <FacebookIcon className="h-4 w-4" /> Facebook
                    </label>
                    <label className="flex items-center gap-2 text-sm">
                      <Switch
                        checked={form.post_to_instagram ?? true}
                        onCheckedChange={(v) => setForm({ ...form, post_to_instagram: v })}
                      />
                      <InstagramIcon className="h-4 w-4" /> Instagram
                    </label>
                  </div>
                </>
              )}
              </div>

              {/* LinkedIn publishing target */}
              <div className="space-y-4 border-t pt-4">
                <div>
                  <Label className="mb-2 flex items-center gap-2">
                    <LinkedinIcon className="h-4 w-4" /> LinkedIn account (credential)
                  </Label>
                  {linkedinAccounts.length === 0 ? (
                    <p className="text-sm text-muted-foreground">
                      No LinkedIn accounts yet. Add one under Channels (Integrations) first.
                    </p>
                  ) : (
                    <Select
                      value={form.linkedin_integration_id ? String(form.linkedin_integration_id) : ''}
                      onValueChange={selectLinkedinToken}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Select a LinkedIn credential" />
                      </SelectTrigger>
                      <SelectContent>
                        {linkedinAccounts.map((acc) => (
                          <SelectItem key={acc.id} value={String(acc.id)}>
                            {metaLabel(acc)}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                </div>

                {form.linkedin_integration_id && (
                  <>
                    {!isLinkedinConnected ? (
                      <div className="space-y-2">
                        <p className="text-sm text-muted-foreground">
                          This credential isn&apos;t connected yet. Authorize it with LinkedIn to publish.
                        </p>
                        <Button variant="outline" size="sm" onClick={connectLinkedin} disabled={connectingLinkedin}>
                          <LinkedinIcon className="mr-2 h-4 w-4" />
                          {connectingLinkedin ? 'Redirecting…' : 'Connect LinkedIn'}
                        </Button>
                      </div>
                    ) : (
                      <>
                        <div>
                          <Label className="mb-2 block">Organization page</Label>
                          <SearchableSelect
                            options={orgOptions}
                            value={form.linkedin_org_id ?? undefined}
                            onValueChange={selectOrg}
                            placeholder={loadingOrgs ? 'Loading organizations…' : 'Select an organization'}
                          />
                          <Button
                            type="button"
                            variant="link"
                            size="sm"
                            onClick={connectLinkedin}
                            className="mt-1 h-auto p-0 text-xs text-muted-foreground"
                          >
                            Reconnect
                          </Button>
                        </div>

                        <div className="space-y-2">
                          <Label className="block">Publish to</Label>
                          <label className="flex items-center gap-2 text-sm">
                            <Switch
                              checked={form.post_to_linkedin ?? true}
                              onCheckedChange={(v) => setForm({ ...form, post_to_linkedin: v })}
                            />
                            <LinkedinIcon className="h-4 w-4" /> LinkedIn
                          </label>
                        </div>
                      </>
                    )}
                  </>
                )}
              </div>
            </div>

            {/* Right column: hashtags */}
            <div>
              <Label className="mb-1 block">Hashtags</Label>
              <p className="mb-2 text-xs text-muted-foreground">
                A reference pool. When a creative is generated, the relevant ones are picked from here and written into
                its caption.
              </p>
              <HashtagInput
                value={form.hashtags ?? []}
                onChange={(tags) => setForm({ ...form, hashtags: tags })}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialogOpen(false)}>
              Close
            </Button>
            <Button onClick={save} disabled={saving}>
              {saving ? 'Saving…' : 'Save'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {ConfirmDialog}
    </div>
  );
}

function formatHour(h: number): string {
  return `${String(h).padStart(2, '0')}:00`;
}

function errorMessage(e: unknown, fallback: string): string {
  if (typeof e === 'object' && e && 'response' in e) {
    const resp = (e as { response?: { data?: { error?: string | string[] } } }).response;
    const err = resp?.data?.error;
    if (Array.isArray(err)) return err.join(', ');
    if (typeof err === 'string') return err;
  }
  return fallback;
}
