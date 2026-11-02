import { uiMaterial } from '@kit.ArkUI';
export class AppTheme {
  private static thinMaterial?: uiMaterial.Material;
  static supportsImmersive(): boolean { try { return uiMaterial.isImmersiveMaterialSupported(); } catch (_) { return false; } }
  static material(reduceTransparency: boolean): uiMaterial.Material | undefined {
    if (reduceTransparency) { return uiMaterial.Material.empty; }
    if (!AppTheme.supportsImmersive()) { return undefined; }
    if (!AppTheme.thinMaterial) { AppTheme.thinMaterial = new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.THIN, materialColor: '#08FFFFFF', applyShadow: true, interactive: false, lightEffect: { color: '#E6F3FF' } }); }
    return AppTheme.thinMaterial;
  }
  static fallbackColor(reduceTransparency: boolean): ResourceColor | undefined { return reduceTransparency ? AppTheme.surface : AppTheme.supportsImmersive() ? undefined : AppTheme.popupFallback; }
  static fallbackBlur(reduceTransparency: boolean): BlurStyle | undefined { return reduceTransparency ? BlurStyle.NONE : AppTheme.supportsImmersive() ? undefined : BlurStyle.COMPONENT_ULTRA_THIN; }
  static readonly background: ResourceColor = $r('app.color.ui_background');
  static readonly surface: ResourceColor = $r('app.color.ui_surface');
  static readonly glass: ResourceColor = $r('app.color.ui_glass');
  static readonly border: ResourceColor = $r('app.color.ui_border');
  static readonly text: ResourceColor = $r('app.color.ui_text');
  static readonly secondary: ResourceColor = $r('app.color.ui_secondary');
  static readonly suggestionInk: ResourceColor = $r('app.color.ui_suggestionInk');
  static readonly muted: ResourceColor = $r('app.color.ui_muted');
  static readonly selected: ResourceColor = $r('app.color.ui_selected');
  static readonly accent: ResourceColor = $r('app.color.ui_accent');
  static readonly error: ResourceColor = $r('app.color.ui_error');
  static readonly contentSurface: ResourceColor = $r('app.color.ui_contentSurface');
  static readonly codeSurface: ResourceColor = $r('app.color.ui_codeSurface');
  static readonly codeInline: ResourceColor = $r('app.color.ui_codeInline');
  static readonly bubble: ResourceColor = $r('app.color.ui_bubble');
  static readonly inputSurface: ResourceColor = $r('app.color.ui_inputSurface');
  static readonly inputGlass: ResourceColor = $r('app.color.ui_inputGlass');
  static readonly subtle: ResourceColor = $r('app.color.ui_subtle');
  static readonly chip: ResourceColor = $r('app.color.ui_chip');
  static readonly rail: ResourceColor = $r('app.color.ui_rail');
  static readonly thumb: ResourceColor = $r('app.color.ui_thumb');
  static readonly primary: ResourceColor = $r('app.color.ui_primary');
  static readonly primaryText: ResourceColor = $r('app.color.ui_primaryText');
  static readonly warning: ResourceColor = $r('app.color.ui_warning');
  static readonly warningSurface: ResourceColor = $r('app.color.ui_warningSurface');
  static readonly warningText: ResourceColor = $r('app.color.ui_warningText');
  static readonly link: ResourceColor = $r('app.color.ui_link');
  static readonly success: ResourceColor = $r('app.color.ui_success');
  static readonly glassRim: ResourceColor = $r('app.color.ui_glassRim');
  static readonly drawerTint: ResourceColor = $r('app.color.ui_drawerTint');
  static readonly scrim: ResourceColor = $r('app.color.ui_scrim');
  static readonly errorSurface: ResourceColor = $r('app.color.ui_errorSurface');
  static readonly popupFallback: ResourceColor = $r('app.color.ui_popupFallback');
  static readonly executionInk: ResourceColor = $r('app.color.ui_executionInk');
  static readonly inkHighlight: ResourceColor = $r('app.color.ui_inkHighlight');
  static readonly shadow: ResourceColor = $r('app.color.ui_shadow');
  static readonly touch: number = 44;
}
