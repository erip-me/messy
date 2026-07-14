import { useState, useEffect } from 'react';
import { Link, Navigate, useSearchParams } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '@/store';
import { setCredentials } from '@/store/auth-slice';
import { sanitizeReturnPath, storePostLoginRedirect, consumePostLoginRedirect } from '@/utils/post-login-redirect';
import nameLogo from '@/assets/nameLogo.png';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Loader2 } from 'lucide-react';
import request from '@/utils/request';
import toast from 'react-hot-toast';

export function LoginPage() {
  const isAuthenticated = useSelector((state: RootState) => state.auth.isAuthenticated);
  const dispatch = useDispatch();
  
  const [searchParams] = useSearchParams();
  const [email, setEmail] = useState('');
  const [token, setToken] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [step, setStep] = useState<'email' | 'token'>('email');

  // Preserve a mid-flow return path (e.g. from the OAuth consent screen) so the
  // magic-link email path can resume it too.
  const returnParam = sanitizeReturnPath(searchParams.get('return'));
  useEffect(() => {
    if (returnParam) storePostLoginRedirect(returnParam);
  }, [returnParam]);

  if (isAuthenticated) {
    return <Navigate to={returnParam || consumePostLoginRedirect() || '/'} replace />;
  }

  const handleSendMagicLink = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      const res = await request.post('/magic_links', { email });
      // Dev mode: backend returns token directly - auto-login
      if (res.data.token) {
        const validateRes = await request.get('/magic_links/validate', {
          params: { token: res.data.token }
        });
        dispatch(setCredentials({
          user: validateRes.data.user,
          account: validateRes.data.account,
          token: validateRes.data.token,
        }));
        toast.success('Welcome back!');
        return;
      }
      toast.success('Magic link sent! Check your email.');
      setStep('token');
    } catch (error: any) {
      toast.error(error.response?.data?.message || 'Failed to send magic link');
    } finally {
      setIsLoading(false);
    }
  };

  const handleValidateToken = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      const response = await request.get('/magic_links/validate', {
        params: { token, email }
      });

      if (response.data.user && response.data.account) {
        dispatch(setCredentials({
          user: response.data.user,
          account: response.data.account,
          token
        }));
        toast.success('Welcome back!');
      }
    } catch (error: any) {
      toast.error(error.response?.data?.message || 'Invalid token');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-4 bg-gradient-to-br from-primary via-primary/90 to-primary/80">
      <img src={nameLogo} alt="Messy" className="h-14 mb-8 brightness-0 invert" />
      <Card className="w-full max-w-md card-shadow bg-card">
        <CardHeader className="text-center pb-6">
          <CardTitle className="text-2xl text-foreground">Welcome back</CardTitle>
          <CardDescription className="text-muted-foreground">
            {step === 'email' 
              ? 'Enter your email to receive a magic link'
              : 'Enter the token from your email'
            }
          </CardDescription>
        </CardHeader>

        <CardContent>
          {step === 'email' ? (
            <form onSubmit={handleSendMagicLink} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="email">Email address</Label>
                <Input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="Enter your email"
                  required
                />
              </div>
              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Sending...
                  </>
                ) : (
                  'Send Magic Link'
                )}
              </Button>
            </form>
          ) : (
            <form onSubmit={handleValidateToken} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="token">Magic Link Token</Label>
                <Input
                  id="token"
                  type="text"
                  value={token}
                  onChange={(e) => setToken(e.target.value)}
                  placeholder="Enter token from email"
                  required
                />
              </div>
              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Validating...
                  </>
                ) : (
                  'Sign In'
                )}
              </Button>
            </form>
          )}
        </CardContent>

        {step === 'token' && (
          <CardFooter>
            <Button
              variant="ghost"
              className="w-full"
              onClick={() => setStep('email')}
            >
              ← Back to email
            </Button>
          </CardFooter>
        )}
      </Card>

      <p className="mt-5 text-sm text-white/70 text-center">
        Don't have an account?{' '}
        <Link to="/signup" className="text-white font-medium hover:underline underline-offset-2">
          Sign up for free
        </Link>
      </p>
    </div>
  );
}