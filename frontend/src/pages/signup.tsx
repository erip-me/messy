import { useEffect, useRef, useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { RootState } from '@/store';
import { signup } from '@/api/signup';
import { appSettings } from '@/utils/constants';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { RequiredAsterisk } from '@/components/ui/required-asterisk';
import { Loader2 } from 'lucide-react';
import nameLogo from '@/assets/nameLogo.png';
import toast from 'react-hot-toast';

declare global {
  interface Window {
    turnstile?: {
      render: (
        el: HTMLElement,
        opts: {
          sitekey: string;
          action?: string;
          callback?: (token: string) => void;
          'expired-callback'?: () => void;
        }
      ) => string;
    };
  }
}

export function SignupPage() {
  const isAuthenticated = useSelector((state: RootState) => state.auth.isAuthenticated);
  const navigate = useNavigate();

  const [form, setForm] = useState({ name: '', email: '', account_name: '' });
  const [submitted, setSubmitted] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [turnstileToken, setTurnstileToken] = useState('');
  const turnstileRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!appSettings.turnstileSiteKey || !turnstileRef.current) return;

    const render = () =>
      window.turnstile?.render(turnstileRef.current!, {
        sitekey: appSettings.turnstileSiteKey,
        action: 'turnstile-spin-v1',
        callback: setTurnstileToken,
        'expired-callback': () => setTurnstileToken(''),
      });

    if (window.turnstile) {
      render();
    } else {
      const script = document.createElement('script');
      script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js';
      script.async = true;
      script.onload = render;
      document.head.appendChild(script);
    }
  }, []);

  if (isAuthenticated) return <Navigate to="/" replace />;

  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm(f => ({ ...f, [k]: e.target.value }));

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitted(true);
    if (!form.name.trim() || !form.email.trim() || !form.account_name.trim()) return;
    if (appSettings.turnstileSiteKey && !turnstileToken) {
      toast.error('Please complete the verification below');
      return;
    }

    setIsLoading(true);
    try {
      const res = await signup({ ...form, turnstile_token: turnstileToken || undefined });

      // Dev mode: backend returns token directly — navigate with it so verify-email can show it
      navigate('/verify-email', {
        state: {
          email: form.email,
          devToken: res.token,
          devVerifyUrl: res.verify_url,
        },
      });
    } catch (err: any) {
      const msg = err.response?.data?.error || 'Failed to create account';
      if (err.response?.status === 409) {
        toast.error(msg, { duration: 5000 });
      } else {
        toast.error(msg);
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-4 bg-gradient-to-br from-primary via-primary/90 to-primary/80">
      <img src={nameLogo} alt="Messy" className="h-14 mb-8 brightness-0 invert" />
      <Card className="w-full max-w-md card-shadow bg-card">
        <CardHeader className="text-center pb-4">
          <CardTitle className="text-2xl text-foreground">Create your account</CardTitle>
          <CardDescription className="text-muted-foreground">Start sending smarter notifications</CardDescription>
        </CardHeader>

        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">Full Name <RequiredAsterisk error={submitted && !form.name.trim()} /></Label>
              <Input
                id="name"
                value={form.name}
                onChange={set('name')}
                placeholder="Jane Smith"
                autoFocus
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="email">Work Email <RequiredAsterisk error={submitted && !form.email.trim()} /></Label>
              <Input
                id="email"
                type="email"
                value={form.email}
                onChange={set('email')}
                placeholder="jane@company.com"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="account_name">Company / Account Name <RequiredAsterisk error={submitted && !form.account_name.trim()} /></Label>
              <Input
                id="account_name"
                value={form.account_name}
                onChange={set('account_name')}
                placeholder="Acme Inc."
              />
            </div>

            {appSettings.turnstileSiteKey && (
              <div ref={turnstileRef} className="flex justify-center" />
            )}

            <Button
              type="submit"
              className="w-full mt-2"
              disabled={isLoading}
            >
              {isLoading ? <><Loader2 className="mr-2 h-4 w-4 animate-spin" /> Creating account…</> : 'Create Account'}
            </Button>
          </form>
        </CardContent>

        <div className="px-6 pb-6 text-center text-sm text-muted-foreground">
          Already have an account?{' '}
          <Link to="/login" className="font-medium text-primary hover:underline">Sign in</Link>
        </div>
      </Card>
    </div>
  );
}
