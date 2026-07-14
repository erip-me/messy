import { useLocation, Link } from 'react-router-dom';
import { Mail, ArrowRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import nameLogo from '@/assets/nameLogo.png';

interface LocationState {
  email?: string;
  devToken?: string;
  devVerifyUrl?: string;
}

export function VerifyEmailPage() {
  const location = useLocation();
  const state = (location.state as LocationState) || {};
  const { email, devToken, devVerifyUrl } = state;

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-4 bg-gradient-to-br from-primary via-primary/90 to-primary/80">
      <img src={nameLogo} alt="Messy" className="h-14 mb-8 brightness-0 invert" />

      <div className="w-full max-w-md bg-card rounded-2xl shadow-lg p-8 text-center">
        <div className="w-16 h-16 rounded-full bg-accent flex items-center justify-center mx-auto mb-5">
          <Mail className="h-8 w-8 text-primary" />
        </div>

        <h1 className="text-2xl font-semibold text-foreground mb-2 font-serif">Check your inbox</h1>
        <p className="text-muted-foreground text-sm leading-relaxed mb-6">
          We sent a verification link to{' '}
          {email ? <strong className="text-foreground">{email}</strong> : 'your email address'}.
          {' '}Click the link to activate your account.
        </p>

        {/* Dev mode shortcut */}
        {devVerifyUrl && (
          <div className="rounded-lg bg-amber-50 border border-amber-200 p-4 mb-6 text-left">
            <p className="text-xs font-semibold text-amber-700 mb-2">⚡ Dev mode: skip email</p>
            <p className="text-xs text-amber-600 mb-3 font-mono break-all">{devToken}</p>
            <a href={devVerifyUrl}>
              <Button size="sm" className="w-full gap-2">
                Verify & continue <ArrowRight className="h-3.5 w-3.5" />
              </Button>
            </a>
          </div>
        )}

        <p className="text-xs text-muted-foreground mb-4">
          Didn't receive it? Check your spam folder or{' '}
          <Link to="/signup" className="text-primary hover:underline">try again</Link>.
        </p>

        <Link to="/login" className="text-xs text-muted-foreground hover:text-muted-foreground underline-offset-2 hover:underline">
          Back to sign in
        </Link>
      </div>
    </div>
  );
}
