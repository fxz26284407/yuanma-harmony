import { AppTheme } from '../theme/AppTheme';
import { Animator, AnimatorResult } from '@kit.ArkUI';

@Component
export struct ExecutionLabel {
  @Prop label: string = '';
  @Prop @Watch('updateMotion') running: boolean = false;
  @Prop failed: boolean = false;
  @Prop @Watch('updateMotion') reduceMotion: boolean = false;
  @State private beam: number = -0.3;
  @State private halfWidth: number = 0.15;
  private motion?: AnimatorResult;
  private ready: boolean = false;
  private updateMotion(): void {
    if (!this.ready) { return; }
    if (!this.running || this.reduceMotion) { this.motion?.cancel(); this.motion = undefined; this.beam = -0.3; return; }
    if (this.motion) { return; }
    this.motion = Animator.create({ duration: 1800, easing: 'linear', delay: 0, fill: 'none', direction: 'normal', iterations: -1, begin: -0.3, end: 1.3 });
    this.motion.onFrame = (value: number) => { this.beam = value; }; this.motion.play();
  }
  aboutToDisappear(): void { this.motion?.cancel(); this.motion = undefined; this.ready = false; }
  private ink(): ShaderStyle {
    if (!this.running || this.reduceMotion || this.failed) { return new ColorShaderStyle(this.failed ? AppTheme.warningText : AppTheme.executionInk); }
    return new LinearGradientStyle({ direction: GradientDirection.Right, colors: [
      [AppTheme.executionInk, 0], [AppTheme.executionInk, Math.max(0, Math.min(1, this.beam - this.halfWidth))], [AppTheme.inkHighlight, Math.max(0, Math.min(1, this.beam))],
      [AppTheme.executionInk, Math.max(0, Math.min(1, this.beam + this.halfWidth))], [AppTheme.executionInk, 1]
    ] });
  }
  build() {
    Text(this.label).fontSize(13).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').height(24)
      .shaderStyle(this.ink())
      .onAreaChange((_old: Area, area: Area) => { this.halfWidth = Math.min(0.3, 56 / Math.max(1, Number(area.width))); this.ready = true; this.updateMotion(); })
  }
}
