import { useSearchParams } from 'react-router-dom';
import { useCallback } from 'react';

export function usePageParam(): [number, (page: number) => void] {
  const [searchParams, setSearchParams] = useSearchParams();

  const page = Math.max(1, Number(searchParams.get('page')) || 1);

  const setPage = useCallback((newPage: number) => {
    setSearchParams(prev => {
      const next = new URLSearchParams(prev);
      if (newPage <= 1) {
        next.delete('page');
      } else {
        next.set('page', String(newPage));
      }
      return next;
    }, { replace: true });
  }, [setSearchParams]);

  return [page, setPage];
}
