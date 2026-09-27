import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { resourceManager } from '@kit.LocalizationKit';

export enum ThemeMode {
  SYSTEM = 'system',
  LIGHT = 'light',
  DARK = 'dark'
}

export class ThemePreference {
  private static readonly STORE_NAME: string = 'appearance';
  private static readonly MODE_KEY: string = 'theme_mode';

  static async load(context: common.UIAbilityContext): Promise<ThemeMode> {
    try {
      const store = await preferences.getPreferences(context, ThemePreference.STORE_NAME);
      const value = await store.get(ThemePreference.MODE_KEY, ThemeMode.SYSTEM);
      return value === ThemeMode.LIGHT || value === ThemeMode.DARK ? value : ThemeMode.SYSTEM;
    } catch (_) {
      throw new Error('Appearance preference read failed');
    }
  }

  static async save(context: common.UIAbilityContext, mode: ThemeMode): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, ThemePreference.STORE_NAME);
      await store.put(ThemePreference.MODE_KEY, mode);
      await store.flush();
    } catch (_) {
      throw new Error('Appearance preference save failed');
    }
  }

  static apply(context: common.UIAbilityContext, mode: ThemeMode): void {
    const colorMode = mode === ThemeMode.DARK ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
      (mode === ThemeMode.LIGHT ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT :
        ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    try {
      context.getApplicationContext().setColorMode(colorMode);
    } catch (_) {
      throw new Error('Appearance mode apply failed');
    }
    AppStorage.setOrCreate<string>('themeMode', mode);
    AppStorage.setOrCreate<boolean>('darkMode', mode === ThemeMode.DARK ||
      (mode === ThemeMode.SYSTEM && context.resourceManager.getConfigurationSync().colorMode ===
        resourceManager.ColorMode.DARK));
  }
}
