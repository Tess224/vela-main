// lib/config/env.dart — Environment configuration.
// Railway service URLs and Supabase config.
// These are public HTTPS endpoints, not secrets.
// Secrets (Supabase anon key) stay in flutter_secure_storage.

class Env {
  Env._();

  // Railway backend services
  static const String patternEngineUrl =
      'https://vela-backend2-production.up.railway.app';
  static const String sessionPipelineUrl =
      'https://vela-backend2-production-afe7.up.railway.app';
  static const String monitoringEngineUrl =
      'https://vela-backend2-production-9b0e.up.railway.app';
  static const String plannerUrl =
      'https://vela-backend2-production-351e.up.railway.app';

  // Supabase (anon key is public — gated by RLS, safe to bundle)
  static const String supabaseUrl =
      'https://wgvhkczioxfhkydjoodm.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndndmhrY3ppb3hmaGt5ZGpvb2RtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUyMTg5NjQsImV4cCI6MjA5MDc5NDk2NH0.WkbA8ProH9d4OuKDxRq-Mwts6gbpWkEtTt7svWn5Uz4'; // <-- paste your real anon key
}