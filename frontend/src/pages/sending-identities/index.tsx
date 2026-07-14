import React, { useState, useEffect } from 'react';
import { Plus, Trash2, Pencil, AtSign } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import { useConfirm } from '@/components/ui/confirm-dialog';
import toast from 'react-hot-toast';
import {
  getSendingIdentities, createSendingIdentity, updateSendingIdentity, deleteSendingIdentity, SendingIdentity,
} from '@/api/sending-identities';
import { getIntegrations } from '@/api/integrations';

export function SendingIdentitiesPage() {
  const [identities, setIdentities] = useState<SendingIdentity[]>([]);
  const [defaults, setDefaults] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<SendingIdentity | null>(null);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ from_name: '', from_email: '' });
  const [saving, setSaving] = useState(false);
  const { confirm, ConfirmDialog } = useConfirm();

  useEffect(() => { load(); }, []);

  const load = async () => {
    setLoading(true);
    try {
      const [list, integrations] = await Promise.all([getSendingIdentities(), getIntegrations().catch(() => [])]);
      setIdentities(list);
      const froms = integrations
        .filter(i => i.kind === 'email' && i.active)
        .map(i => i.config?.from_email || i.config?.from || i.config?.source)
        .filter((f): f is string => Boolean(f));
      setDefaults([...new Set(froms)]);
    } catch { toast.error('Failed to load sending identities'); }
    finally { setLoading(false); }
  };

  const openNew = () => { setEditing(null); setForm({ from_name: '', from_email: '' }); setOpen(true); };
  const openEdit = (i: SendingIdentity) => { setEditing(i); setForm({ from_name: i.from_name || '', from_email: i.from_email }); setOpen(true); };

  const save = async () => {
    if (!form.from_email.trim()) { toast.error('From email is required'); return; }
    setSaving(true);
    try {
      const payload = { from_name: form.from_name.trim() || undefined, from_email: form.from_email.trim() };
      if (editing) await updateSendingIdentity(editing.id, payload);
      else await createSendingIdentity(payload);
      setOpen(false);
      await load();
      toast.success(editing ? 'Identity updated' : 'Identity created');
    } catch (e: any) {
      toast.error(e.response?.data?.errors?.[0] || 'Failed to save identity');
    } finally {
      setSaving(false);
    }
  };

  const remove = async (i: SendingIdentity) => {
    const ok = await confirm({ title: 'Delete identity', description: `Delete ${i.from_email}?`, confirmLabel: 'Delete', variant: 'destructive' });
    if (!ok) return;
    try { await deleteSendingIdentity(i.id); setIdentities(list => list.filter(x => x.id !== i.id)); toast.success('Identity deleted'); }
    catch (e: any) { toast.error(e.response?.data?.error || 'Failed to delete'); }
  };

  return (
    <div className="p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div>
          <h1 className="page-heading">Identities</h1>
          <p className="page-subtitle">From addresses your campaigns, drips and messages can send as. When none is selected, your email channel's configured from address is used.</p>
        </div>
        <Button onClick={openNew}><Plus className="h-4 w-4 mr-2" />New identity</Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2"><AtSign className="h-5 w-5" />Identities <Badge variant="outline">{identities.length}</Badge></CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {loading ? (
            <PageSkeleton columns={2} rows={4} actions={1} />
          ) : identities.length === 0 && defaults.length === 0 ? (
            <div className="text-center py-16">
              <AtSign className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <h3 className="text-lg font-medium mb-2">No sending identities</h3>
              <p className="text-muted-foreground text-sm mb-4">Add a from-address (it must belong to a domain verified in your email provider).</p>
              <Button onClick={openNew}><Plus className="h-4 w-4 mr-2" />New identity</Button>
            </div>
          ) : (
            <>
            {/* Mobile: stacked cards */}
            <div className="md:hidden divide-y divide-border">
              {defaults.map(email => (
                <div key={`default-${email}`} className="p-4 flex flex-col gap-2 bg-muted/30">
                  <div className="flex items-center gap-2">
                    <Badge variant="secondary">Default</Badge>
                    <span className="text-xs text-muted-foreground">Channel from address</span>
                  </div>
                  <span className="font-mono text-sm text-muted-foreground truncate">{email}</span>
                </div>
              ))}
              {identities.map(i => (
                <button
                  key={i.id}
                  onClick={() => openEdit(i)}
                  className="w-full text-left p-4 flex flex-col gap-2 hover:bg-muted/50 transition-colors"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-medium truncate">{i.from_name || '—'}</span>
                    <div className="flex items-center gap-1 shrink-0" onClick={e => e.stopPropagation()}>
                      <Button variant="ghost" size="sm" onClick={() => openEdit(i)}><Pencil className="h-4 w-4" /></Button>
                      <Button variant="ghost" size="sm" className="text-destructive hover:text-destructive" onClick={() => remove(i)}><Trash2 className="h-4 w-4" /></Button>
                    </div>
                  </div>
                  <span className="font-mono text-sm text-muted-foreground truncate">{i.from_email}</span>
                </button>
              ))}
            </div>

            {/* Desktop: table */}
            <Table className="hidden md:table">
              <TableHeader>
                <TableRow>
                  <TableHead>From name</TableHead>
                  <TableHead>From email</TableHead>
                  <TableHead className="w-24"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {defaults.map(email => (
                  <TableRow key={`default-${email}`} className="bg-muted/30">
                    <TableCell className="text-muted-foreground">
                      <Badge variant="secondary">Default</Badge>
                    </TableCell>
                    <TableCell className="font-mono text-sm text-muted-foreground">{email}</TableCell>
                    <TableCell className="text-xs text-muted-foreground">Channel from address</TableCell>
                  </TableRow>
                ))}
                {identities.map(i => (
                  <TableRow key={i.id} className="cursor-pointer hover:bg-muted/50" onClick={() => openEdit(i)}>
                    <TableCell className="font-medium">{i.from_name || <span className="text-muted-foreground">—</span>}</TableCell>
                    <TableCell className="font-mono text-sm">{i.from_email}</TableCell>
                    <TableCell onClick={e => e.stopPropagation()}>
                      <div className="flex items-center gap-1">
                        <Button variant="ghost" size="sm" onClick={() => openEdit(i)}><Pencil className="h-4 w-4" /></Button>
                        <Button variant="ghost" size="sm" className="text-destructive hover:text-destructive" onClick={() => remove(i)}><Trash2 className="h-4 w-4" /></Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            </>
          )}
        </CardContent>
      </Card>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader><DialogTitle>{editing ? 'Edit identity' : 'New sending identity'}</DialogTitle></DialogHeader>
          <div className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="from_name">From name <span className="text-muted-foreground text-xs">(optional)</span></Label>
              <Input id="from_name" placeholder="Peter from Acme" value={form.from_name} onChange={e => setForm(f => ({ ...f, from_name: e.target.value }))} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="from_email">From email</Label>
              <Input id="from_email" placeholder="peter@acme.com" value={form.from_email} onChange={e => setForm(f => ({ ...f, from_email: e.target.value }))} />
              <p className="text-xs text-muted-foreground">Must be on a domain verified in your email provider (e.g. SES).</p>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
            <Button onClick={save} disabled={saving}>{saving ? 'Saving…' : 'Save'}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {ConfirmDialog}
    </div>
  );
}
