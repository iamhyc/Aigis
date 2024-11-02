
export type ValueType = number | string | boolean | Array<number> | Array<string> | Array<boolean> | Uint8Array | object | bigint;
export type UserPreferences = Map<string, ValueType>;

export type AppLanguage = 'default' | 'zh-Hans' | 'en-Latn-US';
export type DarkMode = 'default' | 'light' | 'dark';

export const DefaultUserPreferences: UserPreferences = new Map<string, ValueType>([
    // general
    ['EnableManualInput', false],
    // outlook
    ['AppLanguage', 'default' as AppLanguage],
    ['DarkMode', 'default' as DarkMode],
    // security
    ['EnableBiometricUnlock', false],
    ['EnableBiometricAuth', false],
]);
