import request from '@/utils/request';

export type DripStatus = 'draft' | 'active' | 'paused' | 'archived';

export interface DripStep {
  id?: number;
  position: number;
  template_id: number | null;
  channel: string;
  delay_days: number;
  conditions: { operator: string; conditions: any[] } | Record<string, never>;
  on_fail: 'skip' | 'exit';
  template?: { id: number; name: string; channel: string } | null;
  sent_count?: number;
  skipped_count?: number;
  suppressed_count?: number;
}

export interface DripStats {
  active: number;
  completed: number;
  exited: number;
  total: number;
}

export interface Drip {
  id: number;
  name: string;
  status: DripStatus;
  segment_id: number | null;
  segment: { id: number; name: string } | null;
  environment_id: number | null;
  allow_reentry: boolean;
  exit_on_segment_leave: boolean;
  enroll_existing_on_start: boolean;
  sending_identity_id: number | null;
  steps: DripStep[];
  stats: DripStats;
  created_at: string;
  updated_at: string;
}

export interface DripStepPayload {
  position: number;
  template_id: number | null;
  channel: string;
  delay_days: number;
  conditions: object;
  on_fail: string;
}

export interface DripPayload {
  name: string;
  segment_id: number | null;
  allow_reentry?: boolean;
  exit_on_segment_leave?: boolean;
  enroll_existing_on_start?: boolean;
  sending_identity_id?: number | null;
  steps?: DripStepPayload[];
}

export const getDrips = () =>
  request.get<Drip[]>('/drips').then(r => r.data);

export const getDrip = (id: number) =>
  request.get<Drip>(`/drips/${id}`).then(r => r.data);

export const createDrip = (data: DripPayload) =>
  request.post<Drip>('/drips', data).then(r => r.data);

export const updateDrip = (id: number, data: Partial<DripPayload>) =>
  request.put<Drip>(`/drips/${id}`, data).then(r => r.data);

export const deleteDrip = (id: number) =>
  request.delete(`/drips/${id}`).then(r => r.data);

export const activateDrip = (id: number) =>
  request.post<Drip>(`/drips/${id}/activate`).then(r => r.data);

export const pauseDrip = (id: number) =>
  request.post<Drip>(`/drips/${id}/pause`).then(r => r.data);

export interface DripProjection {
  segment_total: number;
  steps: { position: number; reachable: number; hitting: number; skipped: number; suppressed: number }[];
}

export const projectDrip = (data: { segment_id: number | null; steps: DripStepPayload[] }) =>
  request.post<DripProjection>('/drips/projection', data).then(r => r.data);
