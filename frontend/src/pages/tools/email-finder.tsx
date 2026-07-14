import { useState, useRef } from "react";
import { Search, CheckCircle, XCircle, Loader2, Copy, Mail } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { generateEmails, verifyEmail, verifyStream, VerifyResult } from "@/api/email-finder";
import { copyToClipboard } from "@/utils/clipboard";
import toast from "react-hot-toast";

type EmailStatus = "pending" | "checking" | "valid" | "invalid";

interface EmailEntry {
  email: string;
  status: EmailStatus;
  reason?: string;
}

export function EmailFinderPage() {
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [middleName, setMiddleName] = useState("");
  const [domain, setDomain] = useState("");
  const [emails, setEmails] = useState<EmailEntry[]>([]);
  const [generating, setGenerating] = useState(false);
  const [verifyingAll, setVerifyingAll] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  const handleGenerate = async () => {
    if (!firstName.trim() || !lastName.trim() || !domain.trim()) {
      toast.error("First name, last name, and domain are required");
      return;
    }

    try {
      setGenerating(true);
      const data = await generateEmails({
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        domain: domain.trim().replace(/^@/, ""),
        middle_name: middleName.trim() || undefined,
      });
      setEmails(data.emails.map((email) => ({ email, status: "pending" as EmailStatus })));
    } catch {
      toast.error("Failed to generate emails");
    } finally {
      setGenerating(false);
    }
  };

  const handleVerifySingle = async (index: number) => {
    const entry = emails[index];
    setEmails((prev) => prev.map((e, i) => (i === index ? { ...e, status: "checking" } : e)));

    try {
      const result: VerifyResult = await verifyEmail(entry.email);
      setEmails((prev) =>
        prev.map((e, i) =>
          i === index
            ? { ...e, status: result.valid ? "valid" : "invalid", reason: result.reason }
            : e
        )
      );
    } catch {
      setEmails((prev) =>
        prev.map((e, i) => (i === index ? { ...e, status: "invalid", reason: "error" } : e))
      );
    }
  };

  const handleVerifyAll = async () => {
    const pending = emails.filter((e) => e.status === "pending").map((e) => e.email);
    if (pending.length === 0) return;

    setVerifyingAll(true);
    setEmails((prev) =>
      prev.map((e) => (e.status === "pending" ? { ...e, status: "checking" } : e))
    );

    const controller = new AbortController();
    abortRef.current = controller;
    let foundValid = false;

    try {
      await verifyStream(
        pending,
        true,
        (result) => {
          if (result.valid) foundValid = true;
          setEmails((prev) =>
            prev.map((e) =>
              e.email === result.email
                ? { ...e, status: result.valid ? "valid" : "invalid", reason: result.reason }
                : e
            )
          );
        },
        controller.signal
      );

      // Reset any emails still marked "checking" (early stop left unchecked)
      setEmails((prev) =>
        prev.map((e) => (e.status === "checking" ? { ...e, status: "pending" } : e))
      );

      if (foundValid) {
        toast.success("Found a valid email");
      } else {
        toast("Verification complete: no valid email found", { icon: "📭" });
      }
    } catch {
      setEmails((prev) =>
        prev.map((e) => (e.status === "checking" ? { ...e, status: "pending" } : e))
      );
      if (!controller.signal.aborted) {
        toast.error("Verification failed");
      }
    } finally {
      setVerifyingAll(false);
      abortRef.current = null;
    }
  };

  const handleStopVerify = () => {
    abortRef.current?.abort();
  };

  const handleCopy = (email: string) => {
    copyToClipboard(email).then(() => toast.success("Copied to clipboard"));
  };

  const renderStatusBadge = (status: EmailStatus) => {
    switch (status) {
      case "pending":
        return <Badge variant="outline">Pending</Badge>;
      case "checking":
        return (
          <Badge variant="secondary">
            <Loader2 className="h-3 w-3 mr-1 animate-spin" />
            Checking
          </Badge>
        );
      case "valid":
        return (
          <Badge className="bg-emerald-100 text-emerald-700 hover:bg-emerald-100">
            <CheckCircle className="h-3 w-3 mr-1" />
            Valid
          </Badge>
        );
      case "invalid":
        return (
          <Badge variant="secondary">
            <XCircle className="h-3 w-3 mr-1" />
            Invalid
          </Badge>
        );
    }
  };

  const validCount = emails.filter((e) => e.status === "valid").length;
  const checkedCount = emails.filter(
    (e) => e.status === "valid" || e.status === "invalid"
  ).length;

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="page-heading">Email Finder</h1>
        <p className="page-subtitle">
          Generate and verify email addresses from a name and domain
        </p>
      </div>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Search className="h-5 w-5" />
            Find Email
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-4 max-w-xl">
            <div className="space-y-2">
              <Label htmlFor="first_name">First Name</Label>
              <Input
                id="first_name"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleGenerate()}
                placeholder="John"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="last_name">Last Name</Label>
              <Input
                id="last_name"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleGenerate()}
                placeholder="Doe"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="middle_name">Middle Name (optional)</Label>
              <Input
                id="middle_name"
                value={middleName}
                onChange={(e) => setMiddleName(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleGenerate()}
                placeholder="Michael"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="domain">Domain</Label>
              <Input
                id="domain"
                value={domain}
                onChange={(e) => setDomain(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleGenerate()}
                placeholder="example.com"
              />
            </div>
          </div>
          <Button onClick={handleGenerate} disabled={generating}>
            {generating ? (
              <>
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                Generating...
              </>
            ) : (
              <>
                <Search className="h-4 w-4 mr-2" />
                Generate Patterns
              </>
            )}
          </Button>
        </CardContent>
      </Card>

      {emails.length > 0 && (
        <Card>
          <CardHeader>
            <div className="flex flex-wrap items-center justify-between gap-2">
              <CardTitle className="flex items-center gap-2">
                <Mail className="h-5 w-5" />
                Email Candidates
                <Badge variant="outline">{emails.length} patterns</Badge>
                {checkedCount > 0 && (
                  <Badge variant={validCount > 0 ? "default" : "secondary"}>
                    {validCount} valid / {checkedCount} checked
                  </Badge>
                )}
              </CardTitle>
              <div className="flex gap-2">
                {verifyingAll ? (
                  <Button variant="outline" onClick={handleStopVerify}>
                    Stop
                  </Button>
                ) : (
                  <Button onClick={handleVerifyAll}>
                    <Search className="h-4 w-4 mr-2" />
                    Verify All (stops on first valid)
                  </Button>
                )}
              </div>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            {/* Mobile: stacked cards */}
            <div className="md:hidden divide-y divide-border">
              {emails.map((entry, index) => (
                <div
                  key={entry.email}
                  className={`p-4 flex flex-col gap-2 ${entry.status === "valid" ? "bg-emerald-50" : ""}`}
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-mono text-sm truncate">{entry.email}</span>
                    <div className="flex gap-1 shrink-0">
                      {entry.status === "pending" && !verifyingAll && (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleVerifySingle(index)}
                        >
                          <Search className="h-4 w-4" />
                        </Button>
                      )}
                      <Button variant="ghost" size="sm" onClick={() => handleCopy(entry.email)}>
                        <Copy className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {renderStatusBadge(entry.status)}
                    {entry.reason && (
                      <span className="text-sm text-muted-foreground truncate">
                        {entry.reason}
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>

            <Table className="hidden md:table">
              <TableHeader>
                <TableRow>
                  <TableHead className="w-12">#</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Details</TableHead>
                  <TableHead className="w-24"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {emails.map((entry, index) => (
                  <TableRow
                    key={entry.email}
                    className={entry.status === "valid" ? "bg-emerald-50" : ""}
                  >
                    <TableCell className="text-muted-foreground font-mono text-sm">
                      {index + 1}
                    </TableCell>
                    <TableCell className="font-mono text-sm">{entry.email}</TableCell>
                    <TableCell>{renderStatusBadge(entry.status)}</TableCell>
                    <TableCell className="text-muted-foreground text-sm">
                      {entry.reason || "-"}
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        {entry.status === "pending" && !verifyingAll && (
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleVerifySingle(index)}
                          >
                            <Search className="h-4 w-4" />
                          </Button>
                        )}
                        <Button variant="ghost" size="sm" onClick={() => handleCopy(entry.email)}>
                          <Copy className="h-4 w-4" />
                        </Button>
                      </div>
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
