(() => {
  'use strict';
  const config = window.BF_SUPABASE_CONFIG || {};
  const configured = /^https:\/\/[^/]+\.supabase\.co$/.test(config.url || '') &&
    typeof config.anonKey === 'string' &&
    config.anonKey.length > 20 &&
    !config.anonKey.startsWith('YOUR_');
  window.BF_SUPABASE_READY = configured && !!window.supabase?.createClient;
  window.BF_SUPABASE = window.BF_SUPABASE_READY
    ? window.supabase.createClient(config.url, config.anonKey, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
      })
    : null;
})();
