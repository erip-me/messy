import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import { setCredentials } from '../store/auth-slice';
import request from '@/utils/request';
import { consumePostLoginRedirect } from '@/utils/post-login-redirect';

export default function ValidatePage() {
  const { token } = useParams<{ token: string }>();
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) return;

    (async () => {
      try {
        const res = await request.get('/magic_links/validate', { params: { token } });
        dispatch(setCredentials({
          user: res.data.user,
          account: res.data.account,
          token: res.data.token,
        }));
        // New accounts haven't completed onboarding yet. Otherwise resume a
        // mid-flow return path (e.g. OAuth consent) if one was stashed.
        const onboarded = !!res.data.account?.onboarding_completed_at;
        const dest = onboarded ? (consumePostLoginRedirect() || '/') : '/onboarding';
        navigate(dest, { replace: true });
      } catch {
        setError('Invalid or expired magic link. Please request a new one.');
      }
    })();
  }, [token, dispatch, navigate]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-b from-white to-gray-50">
      <div className="text-center max-w-sm mx-auto px-6">
        {error ? (
          <>
            <div className="w-16 h-16 rounded-full bg-red-100 flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
            </div>
            <h1 className="text-xl font-semibold text-foreground mb-2 font-serif">Link Expired</h1>
            <p className="text-muted-foreground text-sm mb-6">{error}</p>
            <a href="/login" className="inline-flex items-center gap-2 px-5 py-2.5 rounded-lg bg-primary text-white text-sm font-medium">
              Back to Login
            </a>
          </>
        ) : (
          <>
            <div className="w-10 h-10 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4" />
            <p className="text-muted-foreground text-sm">Verifying your magic link...</p>
          </>
        )}
      </div>
    </div>
  );
}
