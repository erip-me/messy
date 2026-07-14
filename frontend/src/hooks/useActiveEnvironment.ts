import { useSelector } from 'react-redux';
import { RootState } from '@/store';

export function useActiveEnvironment() {
  return useSelector((state: RootState) => state.environment.activeEnvironmentId);
}
