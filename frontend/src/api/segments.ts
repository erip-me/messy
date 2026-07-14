import request from '@/utils/request';

export type ConditionOperator = 'equals' | 'not_equals' | 'contains' | 'not_contains' | 'greater_than' | 'less_than' | 'before' | 'after' | 'is_blank' | 'is_present';
export type GroupOperator = 'and' | 'or';

export interface LeafCondition {
  id: string;
  attribute: string;
  operator: ConditionOperator;
  value: string;
}

export interface ConditionGroup {
  id: string;
  operator: GroupOperator;
  conditions: (LeafCondition | ConditionGroup)[];
}

export interface Attribute {
  key: string;
  label: string;
  type: 'string' | 'date';
}

export interface Segment {
  id: number;
  name: string;
  description: string | null;
  conditions: ConditionGroup;
  customer_count: number;
  cleanup_status?: string | null;
  cleanup_progress?: number;
  cleanup_total?: number;
  cleanup_stats?: { total: number; skipped: number; unsubscribed: number; high: number; medium: number; low: number; invalid: number } | null;
  cleanup_started_at?: string | null;
  cleanup_completed_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface PreviewResult {
  count: number;
  sample: Array<{ id: number; email: string; first_name: string | null; last_name: string | null }>;
}

export const getSegments = () =>
  request.get<Segment[]>('/segments').then(r => r.data);

export const getSegment = (id: number) =>
  request.get<Segment>(`/segments/${id}`).then(r => r.data);

export const createSegment = (data: { name: string; description?: string; conditions: object }) =>
  request.post<Segment>('/segments', data).then(r => r.data);

export const updateSegment = (id: number, data: { name: string; description?: string; conditions: object }) =>
  request.put<Segment>(`/segments/${id}`, data).then(r => r.data);

export const deleteSegment = (id: number) =>
  request.delete(`/segments/${id}`).then(r => r.data);

export const previewSegment = (conditions: object) =>
  request.post<PreviewResult>('/segments/preview', { conditions }).then(r => r.data);

export const getAttributes = () =>
  request.get<{ attributes: Attribute[] }>('/segments/attributes').then(r => r.data.attributes);

export const cleanSegment = (id: number) =>
  request.post<{ message: string }>(`/segments/${id}/clean`).then(r => r.data);
