
export type ValueType = number | string | boolean | Array<number> | Array<string> | Array<boolean> | Uint8Array | object | bigint;
export type UserPreferences = Map<string, ValueType>;

export type AppLanguage = 'default' | 'zh-Hans' | 'en-Latn-US';
export type DarkMode = 'default' | 'light' | 'dark';
export type DigitGroup = '2' | '3' | '4' | 'even' | 'none';
export type ShowAccountName = 'always' | 'smart' | 'off';
export type AuthTypePriority = 'face' | 'touch' | 'pin';

export const DefaultUserPreferences: UserPreferences = new Map<string, ValueType>([
    // general
    ['EnableManualInput',     false],
    ['EnableDoubleClickCopy', false],
    ['DisableAddConfirm',     false],
    // outlook
    ['AppLanguage',     'default' as AppLanguage],
    ['DarkMode',        'default' as DarkMode],
    ['DigitGroup',      '3' as DigitGroup],
    ['ShowAccountName', 'always' as ShowAccountName],
    ['ShowIssuerIcons', true],
    // security
    ['EnableBiometricUnlock', false],
    ['AuthTypePriority',      'face' as AuthTypePriority],
    ['EnableBiometricAuth',   false],
]);
