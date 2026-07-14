import { useEffect, useRef } from 'react';
import { useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { RootState } from '@/store';
import { identify, reset, capturePageview } from '@/lib/analytics';

// Keeps PostHog in sync with the Redux auth state and the router:
//  - identifies the user + their tenant (account group) on login / account load
//  - resets on logout so a shared browser doesn't attribute events to the
//    previous person
//  - captures a $pageview on every client-side route change
export function useAnalytics() {
  const user = useSelector((state: RootState) => state.auth.user);
  const account = useSelector((state: RootState) => state.auth.account);
  const location = useLocation();

  // Only re-identify when something material to the identity actually changes,
  // not on every account-object reference churn.
  const identityKey = user
    ? [user.id, user.email, user.name, user.role, account?.id, account?.name, account?.plan, account?.status].join('|')
    : null;
  const lastIdentity = useRef<string | null>(null);

  useEffect(() => {
    if (user) {
      if (identityKey !== lastIdentity.current) {
        identify(user, account);
        lastIdentity.current = identityKey;
      }
    } else if (lastIdentity.current !== null) {
      reset();
      lastIdentity.current = null;
    }
  }, [user, account, identityKey]);

  useEffect(() => {
    capturePageview();
  }, [location.pathname]);
}
