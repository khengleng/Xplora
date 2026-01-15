export type UserRole = 'TELLER' | 'SUPERVISOR' | 'MANAGER' | 'VVIP' | 'ADMIN' | 'DBA';
export type RequestStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'EXPIRED';
export type SensitiveField = 'account_number' | 'ssn' | 'balance' | 'email' | 'phone' | 'address';

export interface User {
  id: number;
  employee_id: string;
  username: string;
  full_name: string;
  role: UserRole;
  branch_code?: string;
  is_active: boolean;
  is_locked: boolean;
  failed_login_attempts: number;
  created_at: string;
}

export interface Account {
  id: number;
  account_number_last4: string;
  account_number_hash: string;
  holder_name_search?: string;
  ssn_last4?: string;
  email_hint?: string;
  phone_last4?: string;
  status: string;
  created_at: string;
}

export interface FieldAccessRequest {
  id: number;
  request_ref: string;
  requester_id: number;
  account_id: number;
  field_name: SensitiveField;
  reason: string;
  ticket_reference?: string;
  status: RequestStatus;
  reviewed_by?: number;
  reviewed_at?: string;
  rejection_reason?: string;
  access_expires_at?: string;
  access_duration_minutes: number;
  created_at: string;
}

export interface PendingRequest {
  id: number;
  request_ref: string;
  requester: string;
  branch_code?: string;
  account: string;
  field_name: SensitiveField;
  reason: string;
  mins_waiting: number;
}

export interface SessionUser {
  id: string;
  name?: string;
  username?: string;
  role?: UserRole;
  email?: string;
}
