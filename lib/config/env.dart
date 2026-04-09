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

  // Supabase (URL is not secret — anon key is stored in secure storage)
  static const String supabaseUrl =
      'https://wgvhkczioxfhkydjoodm.supabase.co';
}