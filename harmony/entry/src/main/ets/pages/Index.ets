import { WorkspaceView } from '../components/WorkspaceView';
import { mobileSession } from '../model/MobileSession';
@Entry
@Component
struct Index {
  build() { Stack() { WorkspaceView({ client: mobileSession }) }.width('100%').height('100%') }
}
