import { headers } from "next/headers";

/**
 * Security utilities for PCI-DSS compliance
 */

/**
 * Get client IP address from request headers
 * Used for audit logging and rate limiting
 */
export async function getClientIp(): Promise<string> {
  const headersList = await headers();
  
  // Check various headers for IP (proxy, forwarded, etc.)
  return (
    headersList.get('x-forwarded-for')?.split(',')[0] ||
    headersList.get('x-real-ip') ||
    headersList.get('cf-connecting-ip') ||
    'unknown'
  );
}

/**
 * Get user agent string
 * Used for audit logging and anomaly detection
 */
export async function getUserAgent(): Promise<string> {
  const headersList = await headers();
  return headersList.get('user-agent') || 'unknown';
}

/**
 * Validate session timeout
 * Returns true if session is still valid
 */
export function isSessionValid(lastActivity: Date, timeoutMinutes: number = 15): boolean {
  const now = new Date();
  const timeoutMs = timeoutMinutes * 60 * 1000;
  const elapsed = now.getTime() - lastActivity.getTime();
  return elapsed < timeoutMs;
}

/**
 * Sanitize user input to prevent XSS
 */
export function sanitizeInput(input: string): string {
  return input
    .replace(/&/g, '&')
    .replace(/</g, '<')
    .replace(/>/g, '>')
    .replace(/"/g, '"')
    .replace(/'/g, '&#x27;');
}

/**
 * Validate account number format (basic validation)
 */
export function validateAccountNumber(accountNumber: string): boolean {
  // Remove spaces and dashes
  const cleaned = accountNumber.replace(/[\s-]/g, '');
  
  // Check if it's numeric and reasonable length (8-19 digits)
  return /^\d{8,19}$/.test(cleaned);
}

/**
 * Validate SSN format (basic validation)
 */
export function validateSSN(ssn: string): boolean {
  // Allow format: XXX-XX-XXXX or XXXXXXXXX
  return /^\d{3}-?\d{2}-?\d{4}$/.test(ssn);
}

/**
 * Validate email format
 */
export function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

/**
 * Validate phone number format
 */
export function validatePhone(phone: string): boolean {
  // Allow various formats: (XXX) XXX-XXXX, XXX-XXX-XXXX, XXXXXXXXXX
  const cleaned = phone.replace(/[\s\-\(\)]/g, '');
  return /^\d{10}$/.test(cleaned);
}

/**
 * Check if password meets requirements
 * Minimum 8 characters, at least one uppercase, one lowercase, one number
 */
export function isStrongPassword(password: string): boolean {
  if (password.length < 8) return false;
  if (!/[A-Z]/.test(password)) return false;
  if (!/[a-z]/.test(password)) return false;
  if (!/\d/.test(password)) return false;
  return true;
}

/**
 * Generate secure random token
 */
export function generateSecureToken(length: number = 32): string {
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}

/**
 * Log security event for monitoring
 * In production, this would send to a security monitoring service
 */
export async function logSecurityEvent(event: {
  type: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  userId?: string;
  ip?: string;
  userAgent?: string;
  details?: unknown;
}): Promise<void> {
  const timestamp = new Date().toISOString();
  
  // In production, send to security monitoring service (Sentry, Datadog, etc.)
  console.warn(`[SECURITY EVENT] ${timestamp}:`, {
    ...event,
    timestamp,
  });
  
  // Could also send to a dedicated security log table in database
  // await query(`INSERT INTO security_events (...) VALUES (...)`);
}

/**
 * Rate limiting check (in-memory, would use Redis in production)
 */
const rateLimitMap = new Map<string, { count: number; resetTime: number }>();

export function checkRateLimit(
  identifier: string,
  maxRequests: number = 10,
  windowMs: number = 60000 // 1 minute
): { allowed: boolean; remaining: number; resetTime: number } {
  const now = Date.now();
  const record = rateLimitMap.get(identifier);
  
  if (!record || now > record.resetTime) {
    // First request or window expired
    const resetTime = now + windowMs;
    rateLimitMap.set(identifier, { count: 1, resetTime });
    return { allowed: true, remaining: maxRequests - 1, resetTime };
  }
  
  if (record.count >= maxRequests) {
    return {
      allowed: false,
      remaining: 0,
      resetTime: record.resetTime,
    };
  }
  
  record.count++;
  return {
    allowed: true,
    remaining: maxRequests - record.count,
    resetTime: record.resetTime,
  };
}

/**
 * Clean up expired rate limit entries
 * Should be called periodically
 */
export function cleanupRateLimits(): void {
  const now = Date.now();
  for (const [key, value] of rateLimitMap.entries()) {
    if (now > value.resetTime) {
      rateLimitMap.delete(key);
    }
  }
}

// Clean up rate limits every 5 minutes
if (typeof window === 'undefined') {
  setInterval(cleanupRateLimits, 5 * 60 * 1000);
}
