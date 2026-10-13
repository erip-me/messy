import { useEffect, useState } from "react";
import { Loader2, Mail, Search, X } from "lucide-react";
import toast from "react-hot-toast";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { getCustomers, Customer } from "@/api/customers";
import { sendTemplateTest } from "@/api/templates";

const customerLabel = (c: Customer) => [c.first_name, c.last_name].filter(Boolean).join(" ") || c.email;

// "Send a test to me" for a saved email template. An optional customer supplies
// the merge data (their custom attributes); the email always goes to the
// signed-in user. Used by the template editor and the drip step editor.
export function SendTemplateTest({ templateId, sendingIdentityId }: { templateId: number; sendingIdentityId?: number | null }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<Customer[]>([]);
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [sending, setSending] = useState(false);

  useEffect(() => {
    if (!query.trim()) { setResults([]); return; }
    const timeout = setTimeout(() => {
      getCustomers({ q: query, per_page: 8 }).then(r => setResults(r.customers)).catch(() => {});
    }, 300);
    return () => clearTimeout(timeout);
  }, [query]);

  const send = async () => {
    setSending(true);
    try {
      const r = await sendTemplateTest(templateId, { customer_id: customer?.id, sending_identity_id: sendingIdentityId });
      toast.success(r.message);
    } catch (e: unknown) {
      const err = e as { response?: { data?: { error?: string } } };
      toast.error(err.response?.data?.error || "Failed to send test");
    } finally { setSending(false); }
  };

  return (
    <div className="space-y-2">
      {customer ? (
        <Badge variant="secondary" className="gap-1 pr-1">
          Data from {customerLabel(customer)}
          <button type="button" onClick={() => setCustomer(null)} className="ml-0.5 rounded-sm hover:bg-muted-foreground/20 p-0.5">
            <X className="h-3 w-3" />
          </button>
        </Badge>
      ) : (
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input placeholder="Fill variables from a customer (optional)…" value={query}
            onChange={e => setQuery(e.target.value)} className="pl-10" />
          {query.trim() && results.length > 0 && (
            <div className="border rounded-md max-h-48 overflow-y-auto mt-1">
              {results.map(c => (
                <button key={c.id} type="button"
                  onClick={() => { setCustomer(c); setQuery(""); setResults([]); }}
                  className="flex flex-col w-full text-left px-3 py-2 hover:bg-muted/50 transition-colors text-sm">
                  <span className="font-medium truncate">{customerLabel(c)}</span>
                  {(c.first_name || c.last_name) && <span className="text-xs text-muted-foreground truncate">{c.email}</span>}
                </button>
              ))}
            </div>
          )}
        </div>
      )}
      <Button variant="outline" size="sm" onClick={send} disabled={sending} className="w-full">
        {sending ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <Mail className="h-4 w-4 mr-2" />}
        Send test to me
      </Button>
      <p className="text-xs text-muted-foreground">Sends the saved version, subject prefixed with [TEST]. Not counted in stats.</p>
    </div>
  );
}
