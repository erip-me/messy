import { useCallback, useEffect, useRef, useState } from 'react';
import type { DependencyList, Dispatch, SetStateAction } from 'react';
import toast from 'react-hot-toast';

interface UseResourceOptions<T> {
  /** Value returned before the first fetch resolves (e.g. `[]` for list pages). */
  initialData?: T;
  /** Toast message shown when the fetcher rejects. Defaults to "Failed to load". */
  errorMessage?: string;
}

interface UseResourceResult<T> {
  data: T | undefined;
  /** Exposed so callers can apply optimistic updates without a refetch. */
  setData: Dispatch<SetStateAction<T | undefined>>;
  loading: boolean;
  error: unknown;
  reload: () => void;
}

/**
 * Loads an async resource in an effect keyed by `deps`, managing loading state
 * and toasting on failure. Stale/unmounted resolutions are ignored so a slower
 * earlier fetch can't clobber a newer one.
 */
export function useResource<T>(
  fetcher: () => Promise<T>,
  deps: DependencyList = [],
  options: UseResourceOptions<T> = {},
): UseResourceResult<T> {
  const { initialData, errorMessage = 'Failed to load' } = options;
  const [data, setData] = useState<T | undefined>(initialData);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);

  // Keep the latest fetcher/message without forcing them into the deps array.
  const fetcherRef = useRef(fetcher);
  fetcherRef.current = fetcher;
  const errorMessageRef = useRef(errorMessage);
  errorMessageRef.current = errorMessage;

  // Bumped on every load; a resolved fetch is applied only if its id is current.
  const runIdRef = useRef(0);

  const load = useCallback(() => {
    const runId = ++runIdRef.current;
    setLoading(true);
    setError(null);
    fetcherRef
      .current()
      .then((result) => {
        if (runId !== runIdRef.current) return;
        setData(result);
      })
      .catch((err) => {
        if (runId !== runIdRef.current) return;
        setError(err);
        toast.error(errorMessageRef.current);
      })
      .finally(() => {
        if (runId !== runIdRef.current) return;
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    load();
    // Invalidate the in-flight fetch on unmount or when deps change.
    return () => {
      runIdRef.current++;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return { data, setData, loading, error, reload: load };
}
