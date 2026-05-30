import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.reeflycare.app',
  appName: 'Reefly',
  webDir: 'www',
  server: {
    url: 'https://reeflycare.com',
    cleartext: false,
  },
  ios: {
    contentInset: 'always',
    limitsNavigationsToAppBoundDomains: false,
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 1000,
      launchAutoHide: true,
      backgroundColor: '#0b1220',
      showSpinner: false,
    },
  },
};

export default config;
