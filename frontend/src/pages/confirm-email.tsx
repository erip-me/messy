import { useEffect, useRef, useState } from 'react';
import { useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { RootState } from '@/store';
import { updateUser } from '../store/auth-slice';
import request from '@/utils/request';

// Landing page for the link in the email-change confirmation mail. Works signed
// in or out: the token alone authorizes the change.
export default function ConfirmEmailPage() {
  const { token } = useParams<{ token: string }>();
  const dispatch = useDispatch();
  const user = useSelector((state: RootState) => state.auth.user);
  // The token is single use, so StrictMode's double effect run would turn a
  // successful change into an "expired" error. Fire once per token.
  const sentFor = useRef<string | null>(null);
  const [result, setResult] = useState<{ email?: string; error?: string } | null>(null);

  useEffect(() => {
    if (!token || sentFor.current === token) return;
    sentFor.current = token;
    (async () => {
      try {
        const res = await request.post('/users/confirm_email_change', { token });
        if (user) dispatch(updateUser({ email: res.data.email }));
        setResult({ email: res.data.email });
      } catch (error: any) {
        setResult({ error: error.response?.data?.message || 'This link is invalid or has expired' });
      }
    })();
    // Run once per token; `user` only decides whether to patch the store.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-b from-white to-gray-50">
      <div className="text-center max-w-sm mx-auto px-6">
        {result ? (
          <>
            <h1 className="text-xl font-semibold text-foreground mb-2 font-serif">
              {result.error ? 'Link Expired' : 'Email Updated'}
            </h1>
            <p className="text-muted-foreground text-sm mb-6">
              {result.error || <>You now sign in with <strong className="text-foreground">{result.email}</strong>.</>}
            </p>
            <a href={user ? '/' : '/login'} className="inline-flex items-center gap-2 px-5 py-2.5 rounded-lg bg-primary text-white text-sm font-medium">
              {user ? 'Back to Messy' : 'Sign in'}
            </a>
          </>
        ) : (
          <>
            <div className="w-10 h-10 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4" />
            <p className="text-muted-foreground text-sm">Confirming your new email...</p>
          </>
        )}
      </div>
    </div>
  );
}
