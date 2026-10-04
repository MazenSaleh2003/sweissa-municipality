// Public client configuration only. Never add service_role or database secrets.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://kmppdktxrxvmglmfvcld.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_sFDKVLRpW6ix06PT-SoyjQ_CO87sVex',
);
const smsEnabled = bool.fromEnvironment('ENABLE_SMS_AUTH', defaultValue: false);
const mapTileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);
const mapAttribution = String.fromEnvironment(
  'MAP_ATTRIBUTION',
  defaultValue: '© OpenStreetMap contributors',
);
