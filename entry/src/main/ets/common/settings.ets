
export type ValueType = number | string | boolean | Array<number> | Array<string> | Array<boolean> | Uint8Array | object | bigint;
export type UserPreferences = Map<string, ValueType>;

export const DefaultUserPreferences: UserPreferences = new Map([
    ['EnableManualInput', false],
    ['EnableBiometricUnlock', false],
    ['EnableBiometricAuth', false],
]);
