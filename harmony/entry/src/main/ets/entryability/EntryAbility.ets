import { UIAbility, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { mobileSession } from '../model/MobileSession';
export default class EntryAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void { const light: boolean = mobileSession.appearance === 'light'; this.context.getApplicationContext().setColorMode(light ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_DARK); stage.getMainWindow().then(async (main: window.Window) => { await main.setWindowSystemBarProperties({ statusBarColor: light ? '#F6F8FB' : '#2D333F', statusBarContentColor: light ? '#202B3D' : '#DBE3EF', navigationBarColor: light ? '#F6F8FB' : '#2D333F', navigationBarContentColor: light ? '#202B3D' : '#DBE3EF' }); }).catch(() => {}); stage.loadContent('pages/Index').catch(() => { console.error('远码页面加载失败'); }); }
  onForeground(): void { mobileSession.setForeground(true); }
  onBackground(): void { mobileSession.setForeground(false); }
  onDestroy(): void { mobileSession.dispose(); }
}
