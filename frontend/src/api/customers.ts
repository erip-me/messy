import request from '@/utils/request';

export interface CustomerActivity {
  id: number;
  activity_type: string;
  environment: string;
  properties: Record<string, unknown>;
  created_at: string;
}

export interface CustomerMessage {
  id: number;
  to: string;
  subject: string | null;
  channel: string;
  status: string;
  environment: string;
  created_at: string;
}

export interface Customer {
  id: number;
  email: string;
  first_name: string | null;
  last_name: string | null;
  custom_attributes: Record<string, string>;
  unsubscribed_channels: Record<string, string>;
  unsubscribed_categories: Record<string, string>;
  email_score: number | null;
  email_score_checked_at: string | null;
  last_seen_at: string | null;
  created_at: string;
  activities?: CustomerActivity[];
  messages?: CustomerMessage[];
}

export interface CustomersResponse {
  customers: Customer[];
  total: number;
  page: number;
  total_pages: number;
}

export interface CsvImport {
  id: number;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  total_rows: number;
  processed_rows: number;
  success_count: number;
  failed_count: number;
  row_errors: Array<{ row: number; email: string; errors: string[] }>;
  created_at: string;
}

export interface UploadResponse {
  import_id: number;
  headers: string[];
  preview_rows: Record<string, string>[];
  total_rows: number;
}

export interface ValidationResponse {
  total_rows: number;
  valid_count: number;
  error_count: number;
  errors: Array<{ row: number; email: string; errors: string[] }>;
}

export const getCustomers = (params?: { q?: string; page?: number; per_page?: number }) =>
  request.get<CustomersResponse>('/customers', { params }).then(r => r.data);

export const getCustomer = (id: number) =>
  request.get<{ customer: Customer }>(`/customers/${id}`).then(r => r.data.customer);

export const deleteCustomer = (id: number) =>
  request.delete(`/customers/${id}`).then(r => r.data);

export const exportCustomers = (params?: { q?: string }) =>
  request.get('/customers/export', { params, responseType: 'blob' }).then(r => r.data as Blob);

export const uploadCsv = (file: File) => {
  const fd = new FormData();
  fd.append('file', file);
  return request.post<UploadResponse>('/csv_imports/upload', fd).then(r => r.data);
};

export const validateCsv = (importId: number, fieldMapping: Record<string, string>) =>
  request.post<ValidationResponse>(`/csv_imports/${importId}/validate`, { field_mapping: fieldMapping }).then(r => r.data);

export const startImport = (importId: number, fieldMapping: Record<string, string>, dedupStrategy: string) =>
  request.post<CsvImport>(`/csv_imports/${importId}/start`, {
    field_mapping: fieldMapping,
    dedup_strategy: dedupStrategy
  }).then(r => r.data);

export const getImportStatus = (importId: number) =>
  request.get<CsvImport>(`/csv_imports/${importId}`).then(r => r.data);

export const toggleUnsubscribe = (customerId: number, channel: string) =>
  request.post<{ message: string; unsubscribed_channels: Record<string, string> }>(
    `/customers/${customerId}/toggle_unsubscribe`,
    { channel }
  ).then(r => r.data);

export const unsubscribeAll = (customerId: number) =>
  request.post<{ message: string; unsubscribed_channels: Record<string, string> }>(
    `/customers/${customerId}/unsubscribe_all`
  ).then(r => r.data);

export const toggleCategoryUnsubscribe = (customerId: number, category = 'marketing') =>
  request.post<{ message: string; unsubscribed_categories: Record<string, string> }>(
    `/customers/${customerId}/toggle_category_unsubscribe`,
    { category }
  ).then(r => r.data);
