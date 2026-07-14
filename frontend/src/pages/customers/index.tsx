import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { usePageParam } from '@/hooks/usePageParam';
import { Upload, Download, Users, Trash2, Search, ChevronLeft, ChevronRight, UploadCloud, CheckCircle, XCircle, AlertTriangle, ArrowLeft, Tag, Copy, Check } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Progress } from '@/components/ui/progress';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { format } from 'date-fns';
import {
  Customer, getCustomers, deleteCustomer, exportCustomers,
  uploadCsv, validateCsv, startImport, getImportStatus,
  ValidationResponse, CsvImport
} from '@/api/customers';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';
import { useDebouncedValue } from '@/hooks/useDebouncedValue';
import { copyToClipboard } from '@/utils/clipboard';
import { getInitials } from '@/utils/initials';
import { deriveDefaultMapping, toEffectiveMapping } from '@/utils/csv-mapping';

function CustomerDetailPanel({ customer, onClose, onDelete }: { customer: Customer | null; onClose: () => void; onDelete: (id: number, email: string) => void }) {
  const [copied, setCopied] = useState(false);
  const [attrsOpen, setAttrsOpen] = useState(true);

  const copyEmail = () => {
    if (!customer) return;
    copyToClipboard(customer.email);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  const fullName = [customer?.first_name, customer?.last_name].filter(Boolean).join(' ');
  const initials = getInitials(customer?.first_name, customer?.last_name, customer?.email);
  const customAttrs = Object.entries(customer?.custom_attributes || {});

  return (
    <Dialog open={!!customer} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Contact Details</DialogTitle>
        </DialogHeader>

        {customer && (
          <div className="space-y-4 overflow-y-auto max-h-[75vh] pr-1">

            {/* Avatar + name */}
            <div className="flex items-center gap-4">
              <Avatar className="w-14 h-14 shrink-0">
                <AvatarFallback className="bg-primary/10 text-primary text-xl font-bold">{initials}</AvatarFallback>
              </Avatar>
              <div>
                <p className="text-lg font-semibold leading-tight">{fullName || <span className="text-muted-foreground italic text-base">No name</span>}</p>
                <p className="text-sm text-muted-foreground">Contact #{customer.id}</p>
              </div>
            </div>

            <div className="h-px bg-border" />

            {/* Core fields as a simple grid */}
            <div className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-3 text-sm">
              <span className="text-muted-foreground font-medium">Email</span>
              <div className="flex items-center gap-2 min-w-0">
                <span className="font-mono truncate">{customer.email}</span>
                <button onClick={copyEmail} className="text-muted-foreground hover:text-foreground transition-colors shrink-0">
                  {copied ? <Check className="h-3.5 w-3.5 text-green-500" /> : <Copy className="h-3.5 w-3.5" />}
                </button>
              </div>

              {customer.first_name && <>
                <span className="text-muted-foreground font-medium">First name</span>
                <span>{customer.first_name}</span>
              </>}

              {customer.last_name && <>
                <span className="text-muted-foreground font-medium">Last name</span>
                <span>{customer.last_name}</span>
              </>}

              <span className="text-muted-foreground font-medium">Added</span>
              <span>{format(new Date(customer.created_at), 'MMM d, yyyy · h:mm a')}</span>
            </div>

            <div className="h-px bg-border" />

            {/* Custom attributes — collapsible header, always expanded by default */}
            <div>
              <button
                className="flex items-center justify-between w-full text-left group"
                onClick={() => setAttrsOpen(o => !o)}
              >
                <div className="flex items-center gap-2">
                  <Tag className="h-4 w-4 text-muted-foreground" />
                  <span className="text-sm font-medium">Custom Attributes</span>
                  <Badge variant="secondary" className="text-xs">{customAttrs.length}</Badge>
                </div>
                <ChevronRight className={`h-4 w-4 text-muted-foreground transition-transform ${attrsOpen ? 'rotate-90' : ''}`} />
              </button>

              {attrsOpen && (
                <div className="mt-3">
                  {customAttrs.length > 0 ? (
                    <div className="space-y-1.5">
                      {customAttrs.map(([key, value]) => (
                        <div key={key} className="flex items-center justify-between gap-4 rounded-lg border bg-muted/30 px-3 py-2">
                          <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wide shrink-0">{key}</span>
                          <span className="text-sm font-mono text-right break-all">{value || '—'}</span>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-sm text-muted-foreground italic pl-6">No custom attributes</p>
                  )}
                </div>
              )}
            </div>

            <div className="h-px bg-border" />

            {/* Actions */}
            <div className="flex justify-between items-center pb-1">
              <Button
                variant="ghost"
                size="sm"
                className="text-destructive hover:text-destructive hover:bg-destructive/10"
                onClick={() => { onDelete(customer.id, customer.email); onClose(); }}
              >
                <Trash2 className="h-4 w-4 mr-2" />
                Delete Customer
              </Button>
              <Button variant="outline" size="sm" onClick={onClose}>Close</Button>
            </div>

          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}

type WizardStep = 'upload' | 'mapping' | 'validate' | 'processing';

const SYSTEM_FIELDS = [
  { value: 'skip', label: 'Skip this column' },
  { value: 'email', label: 'Email *' },
  { value: 'first_name', label: 'First Name' },
  { value: 'last_name', label: 'Last Name' },
  { value: 'custom', label: 'Custom Attribute…' },
];

const STEPS: { key: WizardStep; label: string }[] = [
  { key: 'upload', label: 'Upload' },
  { key: 'mapping', label: 'Map Fields' },
  { key: 'validate', label: 'Validate' },
  { key: 'processing', label: 'Import' },
];

function StepIndicator({ current }: { current: WizardStep }) {
  const idx = STEPS.findIndex(s => s.key === current);
  return (
    <div className="flex items-center gap-2 mb-6">
      {STEPS.map((step, i) => (
        <React.Fragment key={step.key}>
          <div className={`flex items-center gap-2 text-sm font-medium ${i <= idx ? 'text-primary' : 'text-muted-foreground'}`}>
            <div className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold border-2 ${
              i < idx ? 'bg-primary border-primary text-white' :
              i === idx ? 'border-primary text-primary' :
              'border-muted-foreground/30 text-muted-foreground'
            }`}>
              {i < idx ? '✓' : i + 1}
            </div>
            <span className="hidden sm:inline">{step.label}</span>
          </div>
          {i < STEPS.length - 1 && (
            <div className={`flex-1 h-px ${i < idx ? 'bg-primary' : 'bg-muted-foreground/20'}`} />
          )}
        </React.Fragment>
      ))}
    </div>
  );
}

function ImportWizard({ open, onClose, onComplete }: { open: boolean; onClose: () => void; onComplete: () => void }) {
  const [step, setStep] = useState<WizardStep>('upload');
  const [uploading, setUploading] = useState(false);
  const [importId, setImportId] = useState<number | null>(null);
  const [headers, setHeaders] = useState<string[]>([]);
  const [previewRows, setPreviewRows] = useState<Record<string, string>[]>([]);
  const [totalRows, setTotalRows] = useState(0);
  const [fieldMapping, setFieldMapping] = useState<Record<string, string>>({});
  const [customNames, setCustomNames] = useState<Record<string, string>>({});
  const [dedupStrategy, setDedupStrategy] = useState<'skip' | 'update'>('skip');
  const [validating, setValidating] = useState(false);
  const [validation, setValidation] = useState<ValidationResponse | null>(null);
  const [importData, setImportData] = useState<CsvImport | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const pollRef = useRef<NodeJS.Timeout | null>(null);

  const reset = () => {
    setStep('upload');
    setUploading(false);
    setImportId(null);
    setHeaders([]);
    setPreviewRows([]);
    setTotalRows(0);
    setFieldMapping({});
    setCustomNames({});
    setDedupStrategy('skip');
    setValidating(false);
    setValidation(null);
    setImportData(null);
    if (pollRef.current) clearInterval(pollRef.current);
  };

  const handleClose = () => { reset(); onClose(); };

  const handleFile = async (file: File) => {
    if (!file.name.endsWith('.csv')) { toast.error('Please upload a CSV file'); return; }
    if (file.size > 10 * 1024 * 1024) { toast.error('File too large (max 10MB)'); return; }
    setUploading(true);
    try {
      const result = await uploadCsv(file);
      setImportId(result.import_id);
      setHeaders(result.headers);
      setPreviewRows(result.preview_rows);
      setTotalRows(result.total_rows);
      setFieldMapping(deriveDefaultMapping(result.headers));
      setStep('mapping' as WizardStep);
    } catch (e: any) {
      toast.error(e.response?.data?.error || 'Upload failed');
    } finally {
      setUploading(false);
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  };

  const getEffectiveMapping = useCallback(
    () => toEffectiveMapping(fieldMapping, customNames),
    [fieldMapping, customNames]
  );

  const emailMapped = Object.entries(fieldMapping).some(([, v]) => v === 'email');

  const handleValidate = async () => {
    if (!importId) return;
    const mapping = getEffectiveMapping();
    if (!Object.values(mapping).includes('email')) { toast.error('Please map the Email column'); return; }
    setValidating(true);
    setStep('validate');
    try {
      const result = await validateCsv(importId, mapping);
      setValidation(result);
    } catch (e: any) {
      toast.error(e.response?.data?.error || 'Validation failed');
      setStep('mapping' as WizardStep);
    } finally {
      setValidating(false);
    }
  };

  const handleStartImport = async () => {
    if (!importId) return;
    const mapping = getEffectiveMapping();
    setStep('processing');
    try {
      const result = await startImport(importId, mapping, dedupStrategy);
      setImportData(result);
      pollRef.current = setInterval(async () => {
        try {
          const status = await getImportStatus(result.id);
          setImportData(status);
          if (status.status === 'completed' || status.status === 'failed') {
            if (pollRef.current) clearInterval(pollRef.current);
          }
        } catch { /* ignore */ }
      }, 1500);
    } catch (e: any) {
      toast.error(e.response?.data?.error || 'Failed to start import');
      setStep('validate' as WizardStep);
    }
  };

  useEffect(() => { return () => { if (pollRef.current) clearInterval(pollRef.current); }; }, []);

  const progress = importData ? Math.round((importData.processed_rows / Math.max(importData.total_rows, 1)) * 100) : 0;

  return (
    <Dialog open={open} onOpenChange={(o) => !o && handleClose()}>
      <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Import Customers from CSV</DialogTitle>
        </DialogHeader>
        <StepIndicator current={step} />

        {/* Step 1: Upload */}
        {step === 'upload' && (
          <div className="space-y-4">
            <div
              className={`border-2 border-dashed rounded-xl p-12 text-center cursor-pointer transition-colors ${dragOver ? 'border-primary bg-primary/5' : 'border-muted-foreground/30 hover:border-primary/50'}`}
              onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
              onDragLeave={() => setDragOver(false)}
              onDrop={handleDrop}
              onClick={() => fileInputRef.current?.click()}
            >
              <UploadCloud className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <p className="text-lg font-medium mb-1">Drag & drop your CSV here</p>
              <p className="text-sm text-muted-foreground mb-3">or click to browse</p>
              <p className="text-xs text-muted-foreground">CSV only · max 10MB</p>
              {uploading && <p className="text-sm text-primary mt-4 font-medium animate-pulse">Uploading…</p>}
            </div>
            <input ref={fileInputRef} type="file" accept=".csv" className="hidden" onChange={e => e.target.files?.[0] && handleFile(e.target.files[0])} />
          </div>
        )}

        {/* Step 2: Field Mapping */}
        {step === 'mapping' && (
          <div className="space-y-4">
            <div className="text-sm text-muted-foreground mb-2">{totalRows} rows detected. Map your CSV columns to customer fields.</div>
            <div className="space-y-3 max-h-64 overflow-y-auto pr-1">
              {headers.map(col => (
                <div key={col} className="flex items-center gap-3">
                  <div className="w-36 shrink-0 text-sm font-mono bg-muted px-2 py-1.5 rounded truncate" title={col}>{col}</div>
                  <span className="text-muted-foreground text-sm">→</span>
                  <Select value={fieldMapping[col] || 'skip'} onValueChange={v => setFieldMapping(m => ({ ...m, [col]: v }))}>
                    <SelectTrigger className="w-48">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {SYSTEM_FIELDS.map(f => <SelectItem key={f.value} value={f.value}>{f.label}</SelectItem>)}
                    </SelectContent>
                  </Select>
                  {fieldMapping[col] === 'custom' && (
                    <Input
                      className="w-40"
                      placeholder="Attribute name"
                      value={customNames[col] || ''}
                      onChange={e => setCustomNames(n => ({ ...n, [col]: e.target.value }))}
                    />
                  )}
                </div>
              ))}
            </div>
            {!emailMapped && (
              <div className="flex items-center gap-2 text-amber-600 text-sm bg-amber-50 border border-amber-200 rounded px-3 py-2">
                <AlertTriangle className="h-4 w-4 shrink-0" />
                Email column must be mapped before continuing.
              </div>
            )}
            <div className="border-t pt-3">
              <p className="text-xs text-muted-foreground mb-2 font-medium">Preview (first 3 rows)</p>
              <div className="overflow-x-auto rounded border">
                <table className="text-xs w-full">
                  <thead className="bg-muted">
                    <tr>{headers.map(h => <th key={h} className="px-2 py-1.5 text-left font-medium">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {previewRows.slice(0, 3).map((row, i) => (
                      <tr key={i} className="border-t">
                        {headers.map(h => <td key={h} className="px-2 py-1.5 text-muted-foreground">{row[h] || '—'}</td>)}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
            <div className="flex justify-between pt-2">
              <Button variant="outline" onClick={() => setStep('upload')}><ArrowLeft className="h-4 w-4 mr-2" />Back</Button>
              <Button onClick={handleValidate} disabled={!emailMapped}>Next: Validate</Button>
            </div>
          </div>
        )}

        {/* Step 3: Validate */}
        {step === 'validate' && (
          <div className="space-y-4">
            {validating ? (
              <div className="text-center py-12 text-muted-foreground">
                <div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full mx-auto mb-4" />
                Validating rows…
              </div>
            ) : validation ? (
              <>
                <div className="grid grid-cols-3 gap-3">
                  <Card><CardContent className="p-4 text-center"><p className="text-2xl font-bold">{validation.total_rows}</p><p className="text-xs text-muted-foreground">Total rows</p></CardContent></Card>
                  <Card><CardContent className="p-4 text-center"><p className="text-2xl font-bold text-green-600">{validation.valid_count}</p><p className="text-xs text-muted-foreground">Valid</p></CardContent></Card>
                  <Card><CardContent className="p-4 text-center"><p className="text-2xl font-bold text-red-500">{validation.error_count}</p><p className="text-xs text-muted-foreground">Errors</p></CardContent></Card>
                </div>

                {validation.errors.length > 0 && (
                  <div>
                    <p className="text-sm font-medium mb-2 text-red-600">Row errors {validation.error_count > 50 && '(showing first 50)'}</p>
                    <div className="max-h-48 overflow-y-auto border rounded">
                      <table className="text-xs w-full">
                        <thead className="bg-muted sticky top-0">
                          <tr><th className="px-2 py-1.5 text-left">Row</th><th className="px-2 py-1.5 text-left">Email</th><th className="px-2 py-1.5 text-left">Error</th></tr>
                        </thead>
                        <tbody>
                          {validation.errors.map((e, i) => (
                            <tr key={i} className="border-t">
                              <td className="px-2 py-1.5 text-muted-foreground">{e.row}</td>
                              <td className="px-2 py-1.5 font-mono">{e.email || '—'}</td>
                              <td className="px-2 py-1.5 text-red-500">{e.errors.join(', ')}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}

                <div>
                  <Label className="text-sm font-medium mb-2 block">Deduplication Strategy</Label>
                  <div className="grid grid-cols-2 gap-3">
                    {(['skip', 'update'] as const).map(s => (
                      <div
                        key={s}
                        className={`border rounded-lg p-3 cursor-pointer transition-colors ${dedupStrategy === s ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50'}`}
                        onClick={() => setDedupStrategy(s)}
                      >
                        <p className="font-medium text-sm">{s === 'skip' ? 'Skip duplicates' : 'Update existing'}</p>
                        <p className="text-xs text-muted-foreground mt-0.5">
                          {s === 'skip' ? 'Rows with existing email are skipped' : 'Existing customers are updated with new data'}
                        </p>
                      </div>
                    ))}
                  </div>
                </div>
              </>
            ) : null}

            <div className="flex justify-between pt-2">
              <Button variant="outline" onClick={() => setStep('mapping')}><ArrowLeft className="h-4 w-4 mr-2" />Back</Button>
              <Button onClick={handleStartImport} disabled={validating || !validation || validation.valid_count === 0}>
                Start Import ({validation?.valid_count || 0} rows)
              </Button>
            </div>
          </div>
        )}

        {/* Step 4: Processing */}
        {step === 'processing' && (
          <div className="space-y-6 py-4">
            {importData?.status === 'completed' ? (
              <div className="text-center space-y-4">
                <CheckCircle className="h-16 w-16 text-green-500 mx-auto" />
                <h3 className="text-xl font-semibold">Import Complete!</h3>
                <div className="grid grid-cols-2 gap-3 max-w-xs mx-auto">
                  <Card><CardContent className="p-3 text-center"><p className="text-xl font-bold text-green-600">{importData.success_count}</p><p className="text-xs text-muted-foreground">Imported</p></CardContent></Card>
                  <Card><CardContent className="p-3 text-center"><p className="text-xl font-bold text-red-500">{importData.failed_count}</p><p className="text-xs text-muted-foreground">Failed/Skipped</p></CardContent></Card>
                </div>
                <Button onClick={() => { reset(); onComplete(); }}>Done</Button>
              </div>
            ) : importData?.status === 'failed' ? (
              <div className="text-center space-y-4">
                <XCircle className="h-16 w-16 text-red-500 mx-auto" />
                <h3 className="text-xl font-semibold">Import Failed</h3>
                <p className="text-muted-foreground text-sm">Something went wrong during processing.</p>
                <Button variant="outline" onClick={handleClose}>Close</Button>
              </div>
            ) : (
              <div className="space-y-4">
                <div className="text-center">
                  <div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full mx-auto mb-3" />
                  <h3 className="font-semibold text-lg">Importing…</h3>
                  <p className="text-sm text-muted-foreground">{importData?.processed_rows || 0} of {importData?.total_rows || totalRows} rows processed</p>
                </div>
                <Progress value={progress} className="h-3" />
                <div className="grid grid-cols-2 gap-3">
                  <Card><CardContent className="p-3 text-center"><p className="text-xl font-bold text-green-600">{importData?.success_count || 0}</p><p className="text-xs text-muted-foreground">Imported</p></CardContent></Card>
                  <Card><CardContent className="p-3 text-center"><p className="text-xl font-bold text-red-500">{importData?.failed_count || 0}</p><p className="text-xs text-muted-foreground">Failed</p></CardContent></Card>
                </div>
              </div>
            )}
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}

export function CustomersIndexPage() {
  const navigate = useNavigate();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const debouncedSearch = useDebouncedValue(search, 350);
  const [page, setPage] = usePageParam();
  const activeEnvId = useActiveEnvironment();
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [importOpen, setImportOpen] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null);
  const { confirm, ConfirmDialog } = useConfirm();

  useEffect(() => { setPage(1); }, [debouncedSearch]);

  const loadCustomers = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getCustomers({ q: debouncedSearch || undefined, page, per_page: 25 });
      setCustomers(data.customers);
      setTotal(data.total);
      setTotalPages(data.total_pages);
    } catch {
      toast.error('Failed to load customers');
    } finally {
      setLoading(false);
    }
  }, [debouncedSearch, page, activeEnvId]);

  useEffect(() => { loadCustomers(); }, [loadCustomers]);

  const handleExport = async () => {
    setExporting(true);
    try {
      const blob = await exportCustomers({ q: debouncedSearch || undefined });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `contacts-${format(new Date(), 'yyyy-MM-dd')}.csv`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    } catch {
      toast.error('Failed to export contacts');
    } finally {
      setExporting(false);
    }
  };

  const handleDelete = async (id: number, email: string) => {
    const confirmed = await confirm({ title: 'Delete Customer', description: `Delete customer "${email}"? This cannot be undone.`, confirmLabel: 'Delete', variant: 'destructive' });
    if (!confirmed) return;
    try {
      await deleteCustomer(id);
      setCustomers(c => c.filter(x => x.id !== id));
      setTotal(t => t - 1);
      toast.success('Customer deleted');
    } catch {
      toast.error('Failed to delete customer');
    }
  };

  return (
    <div className="p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div>
          <h1 className="page-heading">Contacts</h1>
          <p className="page-subtitle">Manage and import your contacts</p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <Button variant="outline" onClick={handleExport} disabled={exporting || total === 0}>
            <Download className="h-4 w-4 mr-2" />
            {exporting ? 'Exporting…' : 'Export CSV'}
          </Button>
          <Button onClick={() => setImportOpen(true)}>
            <Upload className="h-4 w-4 mr-2" />
            Import CSV
          </Button>
        </div>
      </div>

      <Card>
        <CardHeader className="pb-3">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <CardTitle className="flex items-center gap-2">
              <Users className="h-5 w-5" />
              All Contacts
              <Badge variant="outline">{total}</Badge>
            </CardTitle>
            <div className="relative w-full sm:w-64">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search by email or name…"
                value={search}
                onChange={e => setSearch(e.target.value)}
                className="pl-8"
              />
            </div>
          </div>
        </CardHeader>
        <CardContent className="p-0">
          {loading ? (
            <PageSkeleton columns={5} rows={8} actions={1} />
          ) : customers.length === 0 ? (
            <div className="text-center py-16">
              <Users className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <h3 className="text-lg font-medium mb-2">{debouncedSearch ? 'No contacts found' : 'No contacts yet'}</h3>
              <p className="text-muted-foreground mb-4 text-sm">
                {debouncedSearch ? 'Try a different search term.' : 'Import your first contacts via CSV to get started.'}
              </p>
              {!debouncedSearch && (
                <Button onClick={() => setImportOpen(true)}>
                  <Upload className="h-4 w-4 mr-2" />
                  Import CSV
                </Button>
              )}
            </div>
          ) : (
            <>
              {/* Mobile: stacked cards */}
              <div className="md:hidden divide-y divide-border">
                {customers.map(c => (
                  <button
                    key={c.id}
                    onClick={() => navigate(`/customers/${c.id}`)}
                    className="w-full text-left p-4 flex flex-col gap-2 hover:bg-muted/50 transition-colors"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <Avatar className="h-8 w-8 shrink-0">
                        <AvatarFallback className="bg-primary/10 text-primary text-xs font-semibold">
                          {getInitials(c.first_name, c.last_name, c.email)}
                        </AvatarFallback>
                      </Avatar>
                      <span className="font-medium font-mono text-sm truncate">{c.email}</span>
                    </div>
                    {(c.first_name || c.last_name) && (
                      <div className="text-sm text-muted-foreground truncate">
                        {[c.first_name, c.last_name].filter(Boolean).join(' ')}
                      </div>
                    )}
                    <div className="flex items-center gap-2 text-xs text-muted-foreground">
                      {Object.keys(c.custom_attributes || {}).length > 0 && (
                        <Badge variant="secondary">
                          {Object.keys(c.custom_attributes).length} attr{Object.keys(c.custom_attributes).length !== 1 ? 's' : ''}
                        </Badge>
                      )}
                      <span className="ml-auto font-mono">{format(new Date(c.created_at), 'MMM d, yyyy')}</span>
                    </div>
                  </button>
                ))}
              </div>

              {/* Desktop: table */}
              <Table className="hidden md:table">
                <TableHeader>
                  <TableRow>
                    <TableHead>Email</TableHead>
                    <TableHead>First Name</TableHead>
                    <TableHead>Last Name</TableHead>
                    <TableHead>Attributes</TableHead>
                    <TableHead>Added</TableHead>
                    <TableHead className="w-12"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {customers.map(c => (
                    <TableRow key={c.id} className="cursor-pointer hover:bg-muted/50" onClick={() => navigate(`/customers/${c.id}`)}>
                      <TableCell className="font-medium">
                        <div className="flex items-center gap-3 min-w-0">
                          <Avatar className="h-8 w-8 shrink-0">
                            <AvatarFallback className="bg-primary/10 text-primary text-xs font-semibold">
                              {getInitials(c.first_name, c.last_name, c.email)}
                            </AvatarFallback>
                          </Avatar>
                          <span className="font-mono text-sm truncate">{c.email}</span>
                        </div>
                      </TableCell>
                      <TableCell>{c.first_name || <span className="text-muted-foreground">—</span>}</TableCell>
                      <TableCell>{c.last_name || <span className="text-muted-foreground">—</span>}</TableCell>
                      <TableCell onClick={e => e.stopPropagation()}>
                        {Object.keys(c.custom_attributes || {}).length > 0 ? (
                          <Popover>
                            <PopoverTrigger asChild>
                              <Badge variant="secondary" className="cursor-default">
                                {Object.keys(c.custom_attributes).length} attr{Object.keys(c.custom_attributes).length !== 1 ? 's' : ''}
                              </Badge>
                            </PopoverTrigger>
                            <PopoverContent className="p-2 space-y-1 min-w-[160px]">
                              {Object.entries(c.custom_attributes).map(([k, v]) => (
                                <div key={k} className="flex items-center justify-between gap-3 text-xs">
                                  <span className="text-muted-foreground font-medium">{k}</span>
                                  <span className="font-mono">{v || '—'}</span>
                                </div>
                              ))}
                            </PopoverContent>
                          </Popover>
                        ) : <span className="text-muted-foreground text-sm">—</span>}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground font-mono">
                        {format(new Date(c.created_at), 'MMM d, yyyy')}
                      </TableCell>
                      <TableCell onClick={e => e.stopPropagation()}>
                        <Button variant="ghost" size="sm" onClick={() => handleDelete(c.id, c.email)} className="text-destructive hover:text-destructive">
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
              {totalPages > 1 && (
                <div className="flex items-center justify-between px-4 py-3 border-t">
                  <p className="text-sm text-muted-foreground">Page {page} of {totalPages}</p>
                  <div className="flex gap-2">
                    <Button variant="outline" size="sm" disabled={page === 1} onClick={() => setPage(page - 1)}>
                      <ChevronLeft className="h-4 w-4" />Prev
                    </Button>
                    <Button variant="outline" size="sm" disabled={page === totalPages} onClick={() => setPage(page + 1)}>
                      Next<ChevronRight className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>

      <ImportWizard
        open={importOpen}
        onClose={() => setImportOpen(false)}
        onComplete={() => { setImportOpen(false); loadCustomers(); toast.success('Import complete!'); }}
      />

      <CustomerDetailPanel
        customer={selectedCustomer}
        onClose={() => setSelectedCustomer(null)}
        onDelete={handleDelete}
      />

      {ConfirmDialog}
    </div>
  );
}
