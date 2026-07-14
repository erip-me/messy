import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '@/store';
import { setCredentials } from '@/store/auth-slice';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import {
  UserPlus, ChevronRight, Check, Mail, Zap,
  Users, ArrowRight, Sparkles, X
} from 'lucide-react';
import request from '@/utils/request';
import toast from 'react-hot-toast';
import nameLogo from '@/assets/nameLogo.png';

const STEPS = ['Invite team', 'Choose plan'];

// ── Invite step ───────────────────────────────────────────────────────────────

function StepInvite({ onNext, onSkip }: { onNext: () => void; onSkip: () => void }) {
  const [emails, setEmails] = useState<string[]>([]);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);

  const addEmail = () => {
    const e = input.trim().toLowerCase();
    if (e && /\S+@\S+\.\S+/.test(e) && !emails.includes(e)) setEmails(prev => [...prev, e]);
    setInput('');
  };

  const handleKey = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ',') { e.preventDefault(); addEmail(); }
  };

  const handleInvite = async () => {
    if (emails.length === 0) return onNext();
    setSending(true);
    try {
      await Promise.all(emails.map(email =>
        request.post('/users', { name: email.split('@')[0], email })
      ));
      toast.success(`${emails.length} invite${emails.length > 1 ? 's' : ''} sent!`);
      onNext();
    } catch {
      toast.error('Some invites failed. You can invite more from the Users page.');
      onNext();
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="text-center">
        <div className="w-14 h-14 rounded-2xl bg-accent flex items-center justify-center mx-auto mb-4">
          <Users className="h-7 w-7 text-primary" />
        </div>
        <h2 className="text-2xl font-semibold text-foreground font-serif">Invite your team</h2>
        <p className="text-muted-foreground text-sm mt-1">Add teammates now, or do it later from Settings → Users.</p>
      </div>

      <div className="space-y-3">
        <Label>Email addresses</Label>
        <div className="flex gap-2">
          <Input
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={handleKey}
            onBlur={addEmail}
            placeholder="colleague@company.com"
            type="email"
          />
          <Button type="button" variant="outline" onClick={addEmail}>Add</Button>
        </div>

        {emails.length > 0 && (
          <div className="flex flex-wrap gap-2 pt-1">
            {emails.map(e => (
              <Badge key={e} variant="secondary" className="gap-1 pr-1">
                {e}
                <button
                  type="button"
                  onClick={() => setEmails(prev => prev.filter(x => x !== e))}
                  className="hover:text-destructive"
                >
                  <X className="h-3 w-3" />
                </button>
              </Badge>
            ))}
          </div>
        )}
      </div>

      <div className="flex gap-3 pt-2">
        <Button
          className="flex-1 gap-2"
          onClick={handleInvite}
          disabled={sending}
        >
          {emails.length > 0
            ? <><UserPlus className="h-4 w-4" /> Send {emails.length} Invite{emails.length > 1 ? 's' : ''}</>
            : <><ArrowRight className="h-4 w-4" /> Continue</>
          }
        </Button>
        <Button variant="ghost" onClick={onSkip}>Skip</Button>
      </div>
    </div>
  );
}

// ── Plan step ─────────────────────────────────────────────────────────────────

function StepPlan({ onComplete }: { onComplete: (plan: 'free' | 'pro') => void }) {
  return (
    <div className="space-y-6">
      <div className="text-center">
        <div className="w-14 h-14 rounded-2xl bg-accent flex items-center justify-center mx-auto mb-4">
          <Sparkles className="h-7 w-7 text-primary" />
        </div>
        <h2 className="text-2xl font-semibold text-foreground font-serif">Choose your plan</h2>
        <p className="text-muted-foreground text-sm mt-1">You can upgrade anytime.</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {/* Free */}
        <button
          onClick={() => onComplete('free')}
          className="text-left p-5 rounded-xl border-2 border-border hover:border-gray-300 transition-colors group"
        >
          <p className="text-base font-semibold text-foreground mb-1">Free</p>
          <p className="text-2xl font-bold text-foreground mb-3">$0<span className="text-sm font-normal text-muted-foreground"> /mo</span></p>
          <ul className="space-y-1.5 text-sm text-muted-foreground">
            <li className="flex items-start gap-2"><Check className="h-4 w-4 text-emerald-500 mt-0.5 shrink-0" /><span>10,000 messages/month</span></li>
            <li className="flex items-start gap-2"><Mail className="h-4 w-4 text-muted-foreground mt-0.5 shrink-0" /><span>Email channel only</span></li>
            <li className="flex items-start gap-2"><Check className="h-4 w-4 text-emerald-500 mt-0.5 shrink-0" /><span>Unlimited templates</span></li>
            <li className="flex items-start gap-2"><Check className="h-4 w-4 text-emerald-500 mt-0.5 shrink-0" /><span>Delivery rules</span></li>
          </ul>
          <p className="text-xs text-muted-foreground mt-4 group-hover:text-muted-foreground">Continue with Free →</p>
        </button>

        {/* Pro */}
        <button
          onClick={() => onComplete('pro')}
          className="text-left p-5 rounded-xl border-2 border-primary bg-accent/40 transition-colors relative"
        >
          <Badge className="absolute top-3 right-3 bg-primary text-white text-[10px]">Popular</Badge>
          <p className="text-base font-semibold text-foreground mb-1">Pro</p>
          <p className="text-2xl font-bold text-foreground mb-3">$49<span className="text-sm font-normal text-muted-foreground"> /mo</span></p>
          <ul className="space-y-1.5 text-sm text-muted-foreground">
            <li className="flex items-start gap-2"><Check className="h-4 w-4 text-emerald-500 mt-0.5 shrink-0" /><span>Unlimited messages</span></li>
            <li className="flex items-start gap-2"><Zap className="h-4 w-4 text-amber-500 mt-0.5 shrink-0" /><span>All channels (SMS, WhatsApp, Push)</span></li>
            <li className="flex items-start gap-2"><Check className="h-4 w-4 text-emerald-500 mt-0.5 shrink-0" /><span>Priority support</span></li>
            <li className="flex items-start gap-2"><Check className="h-4 w-4 text-emerald-500 mt-0.5 shrink-0" /><span>Advanced analytics</span></li>
          </ul>
          <p className="text-xs text-primary font-medium mt-4">Upgrade to Pro →</p>
        </button>
      </div>
    </div>
  );
}

// ── Main wizard ───────────────────────────────────────────────────────────────

export function OnboardingPage() {
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { user, account } = useSelector((state: RootState) => state.auth);
  const [step, setStep] = useState(0);

  // Already onboarded — bounce to dashboard
  if (account?.onboarding_completed_at) {
    navigate('/', { replace: true });
    return null;
  }

  const advance = () => setStep(s => s + 1);

  const completeOnboarding = async (plan: 'free' | 'pro') => {
    try {
      // Mark onboarding done on backend
      await request.patch(`/accounts/${account?.id}/onboarding`, {
        step: 2,
        completed: true,
      });

      // If upgrading to pro — placeholder (future payment flow)
      if (plan === 'pro') {
        toast('Pro upgrade coming soon. You\'ve been placed on the free plan for now.', { icon: '💳' });
      }

      // Refresh account in Redux state
      const accountRes = await request.get('/accounts');
      dispatch(setCredentials({ user: user!, account: accountRes.data, token: undefined }));

      toast.success('Welcome to Messy! 🎉');
      navigate('/', { replace: true });
    } catch {
      toast.error('Something went wrong. Please try again.');
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-primary via-primary/90 to-primary/80 flex flex-col items-center justify-center px-4">
      <img src={nameLogo} alt="Messy" className="h-12 mb-8 brightness-0 invert" />

      <div className="w-full max-w-lg bg-card rounded-2xl shadow-xl p-8">
        {/* Step indicator */}
        <div className="flex items-center justify-center gap-2 mb-8">
          {STEPS.map((label, i) => (
            <div key={i} className="flex items-center gap-2">
              <div className={`flex items-center gap-2 text-sm font-medium ${
                i < step ? 'text-emerald-600' : i === step ? 'text-primary' : 'text-gray-300'
              }`}>
                <span className={`w-6 h-6 rounded-full flex items-center justify-center text-xs border-2 ${
                  i < step
                    ? 'bg-emerald-500 border-emerald-500 text-white'
                    : i === step
                    ? 'border-primary text-primary'
                    : 'border-border text-gray-300'
                }`}>
                  {i < step ? <Check className="h-3 w-3" /> : i + 1}
                </span>
                <span className="hidden sm:inline">{label}</span>
              </div>
              {i < STEPS.length - 1 && (
                <ChevronRight className={`h-4 w-4 ${i < step ? 'text-emerald-400' : 'text-gray-200'}`} />
              )}
            </div>
          ))}
        </div>

        {step === 0 && <StepInvite onNext={advance} onSkip={advance} />}
        {step === 1 && <StepPlan onComplete={completeOnboarding} />}
      </div>

      <p className="text-white/50 text-xs mt-6">
        You can always change these settings later.
      </p>
    </div>
  );
}
