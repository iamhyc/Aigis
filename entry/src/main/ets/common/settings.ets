
export type ValueType = number | string | boolean | Array<number> | Array<string> | Array<boolean> | Uint8Array | object | bigint;
export type UserPreferences = Map<string, ValueType>;

export type AppLanguage = 'default' | 'zh-Hans' | 'en-Latn-US';
export type DarkMode = 'default' | 'light' | 'dark';
export type ViewMode = 'compact' | 'normal' | 'large';
export type DigitGroup = '2' | '3' | '4' | 'even' | 'none';
export type ShowAccountName = 'always' | 'smart' | 'off';
export type AuthTypePriority = 'face' | 'touch' | 'pin';
export type ItemSortOrder = 'custom' | 'issuer_asc' | 'issuer_dsc' | 'account_asc' | 'account_dsc' | 'count';
export type PasswordReminderPeriod = 'never' | 'weekly' | 'biweekly' | 'monthly' | 'quarterly';

export const DefaultUserPreferences: UserPreferences = new Map<string, ValueType>([
    // general
    ['EnableManualInput',     false],
    ['EnableDoubleClickCopy', false],
    ['DisableAddConfirm',     false],
    ['PreviewNextToken',      false],
    // outlook
    ['AppLanguage',     'default' as AppLanguage],
    ['DarkMode',        'default' as DarkMode],
    ['ViewMode',        'compact' as ViewMode],
    ['DigitGroup',      '3' as DigitGroup],
    ['ShowAccountName', 'always' as ShowAccountName],
    ['ItemSortOrder',   'custom' as ItemSortOrder],
    // icons
    ['ShowIssuerIcons', true],
    // security
    ['PasswordReminderPeriod', 'biweekly' as PasswordReminderPeriod],
    ['EnableScreenSecurity',  true],
    ['EnableBiometricUnlock', false],
    ['AuthTypePriority',      'face' as AuthTypePriority],
    ['EnableBiometricAuth',   false],
    // backup
    ['EnableBackupReminder',    true],
]);
