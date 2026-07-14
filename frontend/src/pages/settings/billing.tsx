import { useState, useEffect, useCallback } from "react";
import { useSelector } from "react-redux";
import { useSearchParams } from "react-router-dom";
import { RootState } from "@/store";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { PageSkeleton } from "@/components/ui/table-skeleton";
import { PAYMENT_STATUS_COLORS } from "@/lib/labels";
import { formatDate } from "@/utils/format-date";
import request from "@/utils/request";
import toast from "react-hot-toast";
import {
  CreditCard,
  Loader2,
  Download,
  ExternalLink,
  Info,
  Check,
} from "lucide-react";

interface Plan {
  key: "free" | "byok" | "managed";
  name: string;
  amount: number; // cents, EUR
  coming_soon: boolean;
  purchasable: boolean;
}

interface BillingData {
  configured: boolean;
  plan: string;
  plan_name: string;
  payment_status: string | null;
  current_period_end: string | null;
  cancel_at_period_end: boolean;
  has_subscription: boolean;
  plans: Plan[];
}

interface Invoice {
  number: string;
  status: string;
  amount_paid: number;
  amount_due: number;
  currency: string;
  created: string;
  pdf: string;
  hosted_url: string;
}

/** Format a cents amount in the given ISO currency (default EUR). */
function formatMoney(cents: number, currency = "EUR"): string {
  try {
    return new Intl.NumberFormat(undefined, {
      style: "currency",
      currency: currency.toUpperCase(),
    }).format((cents || 0) / 100);
  } catch {
    return `€${((cents || 0) / 100).toFixed(2)}`;
  }
}

export function BillingPage() {
  const currentUser = useSelector((state: RootState) => state.auth.user);
  const isAdmin = currentUser?.role === "admin" || currentUser?.is_super_admin === true;

  const [searchParams, setSearchParams] = useSearchParams();
  const [billing, setBilling] = useState<BillingData | null>(null);
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionPlan, setActionPlan] = useState<string | null>(null);
  const [openingPortal, setOpeningPortal] = useState(false);

  const loadBilling = useCallback(async () => {
    try {
      const res = await request.get("/billing");
      setBilling(res.data);
      if (res.data?.configured && res.data?.has_subscription) {
        try {
          const inv = await request.get("/billing/invoices");
          setInvoices(inv.data?.invoices || []);
        } catch {
          // invoices are non-critical; leave empty on failure
        }
      }
    } catch {
      toast.error("Failed to load billing information");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadBilling();
  }, [loadBilling]);

  // Handle return from Stripe Checkout (?status=success | cancelled).
  useEffect(() => {
    const status = searchParams.get("status");
    if (status === "success") {
      toast.success("Subscription updated successfully");
    } else if (status === "cancelled") {
      toast("Checkout cancelled");
    }
    if (status) {
      searchParams.delete("status");
      setSearchParams(searchParams, { replace: true });
      loadBilling();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleCheckout = async (planKey: string) => {
    setActionPlan(planKey);
    try {
      const res = await request.post("/billing/checkout", { plan: planKey });
      if (res.data?.url) {
        window.location.href = res.data.url;
      } else {
        toast.error("Could not start checkout");
        setActionPlan(null);
      }
    } catch (error: any) {
      if (error.response?.status === 503) {
        toast.error(error.response?.data?.error || "Billing is not configured");
      } else {
        toast.error("Could not start checkout");
      }
      setActionPlan(null);
    }
  };

  const handlePortal = async () => {
    setOpeningPortal(true);
    try {
      const res = await request.post("/billing/portal");
      if (res.data?.url) {
        window.location.href = res.data.url;
      } else {
        toast.error("Could not open billing portal");
        setOpeningPortal(false);
      }
    } catch (error: any) {
      if (error.response?.status === 503) {
        toast.error(error.response?.data?.error || "Billing is not configured");
      } else {
        toast.error("Could not open billing portal");
      }
      setOpeningPortal(false);
    }
  };

  if (loading) {
    return <PageSkeleton columns={4} rows={4} actions={0} />;
  }

  if (!billing) {
    return (
      <div className="p-6 max-w-3xl">
        <h1 className="page-heading">Billing</h1>
        <p className="page-subtitle">Manage your plan, payment method, and invoices</p>
        <Card className="mt-6">
          <CardContent className="py-6 text-sm text-muted-foreground">
            Billing information is unavailable right now.
          </CardContent>
        </Card>
      </div>
    );
  }

  // Non-admins can't manage billing.
  if (!isAdmin) {
    return (
      <div className="p-6 max-w-3xl">
        <h1 className="page-heading">Billing</h1>
        <p className="page-subtitle">Manage your plan, payment method, and invoices</p>
        <Card className="mt-6">
          <CardContent className="flex items-start gap-3 py-6 text-sm text-muted-foreground">
            <Info className="h-5 w-5 shrink-0 text-muted-foreground" />
            <span>Billing is managed by your account administrators.</span>
          </CardContent>
        </Card>
      </div>
    );
  }

  const configured = billing.configured;
  const statusKey = billing.payment_status || "";
  const statusClass = PAYMENT_STATUS_COLORS[statusKey] || PAYMENT_STATUS_COLORS.inactive;

  return (
    <div className="p-6 max-w-3xl">
      <h1 className="page-heading">Billing</h1>
      <p className="page-subtitle">Manage your plan, payment method, and invoices</p>

      {!configured && (
        <Card className="mt-6">
          <CardContent className="flex items-start gap-3 py-6 text-sm text-muted-foreground">
            <Info className="h-5 w-5 shrink-0 text-muted-foreground" />
            <span>
              Billing isn&apos;t enabled on this deployment yet. Self-hosted
              installations run without a payment provider configured.
            </span>
          </CardContent>
        </Card>
      )}

      {/* Current plan */}
      <Card className="mt-6">
        <CardHeader>
          <div className="flex items-start justify-between gap-4">
            <div>
              <CardTitle className="text-base flex items-center gap-2">
                <CreditCard className="h-4 w-4 text-primary" />
                Current Plan
              </CardTitle>
              <CardDescription className="mt-1">
                Your active subscription and renewal details.
              </CardDescription>
            </div>
            {billing.payment_status && (
              <Badge className={`${statusClass} capitalize`}>
                {billing.payment_status.replace(/_/g, " ")}
              </Badge>
            )}
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap items-end justify-between gap-4">
            <div>
              <p className="text-2xl font-semibold text-foreground">{billing.plan_name}</p>
              {billing.has_subscription && billing.current_period_end && (
                <p className="text-sm text-muted-foreground mt-1">
                  {billing.cancel_at_period_end
                    ? `Cancels on ${formatDate(billing.current_period_end)}`
                    : `Renews on ${formatDate(billing.current_period_end)}`}
                </p>
              )}
            </div>
            {configured && billing.has_subscription && (
              <Button onClick={handlePortal} disabled={openingPortal}>
                {openingPortal ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" /> Opening...
                  </>
                ) : (
                  "Manage billing & invoices"
                )}
              </Button>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Plan options */}
      <Card className="mt-6">
        <CardHeader>
          <CardTitle className="text-base">Plans</CardTitle>
          <CardDescription>Choose the plan that fits your team.</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {billing.plans.map((plan) => {
              const isCurrent = plan.key === billing.plan;
              return (
                <div
                  key={plan.key}
                  className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border p-4"
                >
                  <div>
                    <div className="flex items-center gap-2">
                      <p className="font-medium text-foreground">{plan.name}</p>
                      {isCurrent && (
                        <Badge variant="secondary" className="gap-1">
                          <Check className="h-3 w-3" /> Current
                        </Badge>
                      )}
                      {plan.coming_soon && (
                        <Badge variant="outline">Coming soon</Badge>
                      )}
                    </div>
                    <p className="text-sm text-muted-foreground mt-0.5">
                      {plan.amount > 0
                        ? `${formatMoney(plan.amount)} / month`
                        : plan.key === "free"
                          ? "Free: self-hosted, bring your own infrastructure"
                          : "Free"}
                    </p>
                  </div>
                  <div>
                    {plan.coming_soon ? (
                      <Button variant="outline" size="sm" disabled>
                        Coming soon
                      </Button>
                    ) : isCurrent ? (
                      <Button variant="outline" size="sm" disabled>
                        Current
                      </Button>
                    ) : plan.purchasable ? (
                      <Button
                        size="sm"
                        disabled={!configured || actionPlan === plan.key || openingPortal}
                        onClick={() =>
                          billing.has_subscription ? handlePortal() : handleCheckout(plan.key)
                        }
                      >
                        {actionPlan === plan.key ? (
                          <>
                            <Loader2 className="h-4 w-4 mr-2 animate-spin" /> Redirecting...
                          </>
                        ) : billing.has_subscription ? (
                          "Switch"
                        ) : (
                          "Upgrade"
                        )}
                      </Button>
                    ) : plan.key === "free" ? (
                      <span className="text-xs text-muted-foreground">Self-host</span>
                    ) : (
                      <span className="text-xs text-muted-foreground">{configured ? "Unavailable" : "Not enabled"}</span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </CardContent>
      </Card>

      {/* Invoices */}
      {configured && invoices.length > 0 && (
        <Card className="mt-6">
          <CardHeader>
            <CardTitle className="text-base">Invoices</CardTitle>
            <CardDescription>Download tax invoices for your records.</CardDescription>
          </CardHeader>
          <CardContent className="px-0">
            {/* Mobile: stacked cards */}
            <div className="md:hidden divide-y divide-border">
              {invoices.map((inv) => (
                <div key={inv.number} className="px-6 py-4 flex flex-col gap-2">
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-medium truncate">{inv.number}</span>
                    <Badge variant="outline" className="capitalize shrink-0">
                      {inv.status}
                    </Badge>
                  </div>
                  <div className="flex items-center justify-between gap-2 text-sm text-muted-foreground">
                    <span>{formatDate(inv.created)}</span>
                    <span>{formatMoney(inv.amount_paid || inv.amount_due, inv.currency)}</span>
                  </div>
                  {inv.pdf ? (
                    <Button asChild variant="ghost" size="sm" className="self-start px-0">
                      <a href={inv.pdf} target="_blank" rel="noopener noreferrer">
                        <Download className="h-4 w-4 mr-1.5" /> Download
                      </a>
                    </Button>
                  ) : inv.hosted_url ? (
                    <Button asChild variant="ghost" size="sm" className="self-start px-0">
                      <a href={inv.hosted_url} target="_blank" rel="noopener noreferrer">
                        <ExternalLink className="h-4 w-4 mr-1.5" /> View
                      </a>
                    </Button>
                  ) : null}
                </div>
              ))}
            </div>

            <Table className="hidden md:table">
              <TableHeader>
                <TableRow>
                  <TableHead>Invoice</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead>Amount</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">PDF</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {invoices.map((inv) => (
                  <TableRow key={inv.number}>
                    <TableCell className="font-medium">{inv.number}</TableCell>
                    <TableCell>{formatDate(inv.created)}</TableCell>
                    <TableCell>
                      {formatMoney(inv.amount_paid || inv.amount_due, inv.currency)}
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline" className="capitalize">
                        {inv.status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      {inv.pdf ? (
                        <Button asChild variant="ghost" size="sm">
                          <a href={inv.pdf} target="_blank" rel="noopener noreferrer">
                            <Download className="h-4 w-4 mr-1.5" /> Download
                          </a>
                        </Button>
                      ) : inv.hosted_url ? (
                        <Button asChild variant="ghost" size="sm">
                          <a href={inv.hosted_url} target="_blank" rel="noopener noreferrer">
                            <ExternalLink className="h-4 w-4 mr-1.5" /> View
                          </a>
                        </Button>
                      ) : null}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
