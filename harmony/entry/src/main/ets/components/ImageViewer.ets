import { AppTheme } from '../theme/AppTheme';
@Component
export struct ImageViewer {
  @Prop uri: string = '';
  @Prop loading: boolean = false;
  @Prop progress: number = 0;
  @Prop reduceMotion: boolean = false;
  @State private zoom: number = 1;
  @State private x: number = 0;
  @State private y: number = 0;
  private viewWidth: number = 0;
  private viewHeight: number = 0;
  private clamp(value: number, size: number): number { const bound: number = size * (this.zoom - 1) / 2; return Math.max(-bound, Math.min(bound, value)); }
  private startZoom: number = 1;
  private startX: number = 0;
  private startY: number = 0;
  private reset(): void { this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 200, curve: Curve.EaseOut }, () => { this.zoom = 1; this.x = 0; this.y = 0; }); }
  build() {
    Column({ space: 8 }) {
      Stack() {
        if (this.uri) {
          Image(this.uri).id('image-original').width('100%').height('100%').objectFit(ImageFit.Contain).scale({ x: this.zoom, y: this.zoom }).translate({ x: this.x, y: this.y })
            .gesture(GestureGroup(GestureMode.Parallel,
              PinchGesture().onActionStart(() => { this.startZoom = this.zoom; }).onActionUpdate((event: GestureEvent) => { this.zoom = Math.min(5, Math.max(1, this.startZoom * event.scale)); }).onActionEnd(() => { if (this.zoom <= 1) { this.reset(); } else { this.x = this.clamp(this.x, this.viewWidth); this.y = this.clamp(this.y, this.viewHeight); } }),
              PanGesture().onActionStart(() => { this.startX = this.x; this.startY = this.y; }).onActionUpdate((event: GestureEvent) => { if (this.zoom > 1) { this.x = this.clamp(this.startX + event.offsetX, this.viewWidth); this.y = this.clamp(this.startY + event.offsetY, this.viewHeight); } })
            ))
        } else { Column({ space: 14 }) { if (this.loading) { LoadingProgress().width(32).height(32).color(AppTheme.accent) } Text(this.loading ? '正在加载图片 · ' + this.progress + '%' : '图片暂不可用，请返回会话重试').fontSize(14).fontColor(AppTheme.secondary) } }
      }.layoutWeight(1).width('100%').onAreaChange((_old: Area, area: Area) => { this.viewWidth = Number(area.width); this.viewHeight = Number(area.height); }).clip(true).backgroundColor(AppTheme.contentSurface).borderRadius(14)
      Row() { Text('双指缩放 · 放大后拖动查看').fontSize(12).fontColor(AppTheme.secondary).layoutWeight(1); Button('重置').id('reset-image').height(44).fontSize(13).fontColor(AppTheme.text).backgroundColor(Color.Transparent).onClick(() => { this.reset(); }) }.width('100%')
    }.layoutWeight(1).width('100%')
  }
}
