import { Offset, Position } from "@kit.ArkUI";

export enum ScrollPosition {
    None,
    TopBound,
    BottomBound,
}

export interface ScrollEventCallbacks {
    onTopBound?: (p: Offset) => void,
    onTopBoundRelease?: (p: Offset) => void,
    onBottomBound?: (p: Offset) => void,
    onBottomBoundRelease?: (p: Offset) => void,
}

export class ScrollEventExtension {
    private readonly callbacks: ScrollEventCallbacks;
    private scrollPosition: ScrollPosition = ScrollPosition.None;
    private startPoint: Position = { x:0,y:0 };
    private endPoint: Position = { x:0,y:0 };

    constructor(callbacks: ScrollEventCallbacks) {
        this.callbacks = callbacks;
    }

    get delta(): Position {
        const delta_x = this.endPoint.x - this.startPoint.x;
        const delta_y = this.endPoint.y - this.startPoint.y;
        return { x:delta_x, y:delta_y};
    }

    get isPullDown(): boolean {
        return (this.scrollPosition===ScrollPosition.TopBound) && (this.delta.y > 0);
    }

    get isPullUp(): boolean {
        return (this.scrollPosition===ScrollPosition.BottomBound) && (this.delta.y < 0);
    }

    onScrollPostionChanges(scrollPosition: ScrollPosition) {
        this.scrollPosition = scrollPosition;
    }

    onTouch(event: TouchEvent) {
        switch (event.type) {
            case TouchType.Cancel:
                break;
            case TouchType.Down:
                this.startPoint = { x:event.touches[0].x, y:event.touches[0].y };
                this.endPoint = { x:event.touches[0].x, y:event.touches[0].y };
                break;
            case TouchType.Up:
                if (this.isPullDown && this.callbacks.onTopBoundRelease) {
                    this.callbacks.onTopBoundRelease(this.delta);
                } else if (this.isPullUp && this.callbacks.onBottomBoundRelease) {
                    this.callbacks.onBottomBoundRelease(this.delta);
                }
                this.startPoint = { x:0, y:0 };
                this.endPoint = { x:0, y:0 };
                break;
            case TouchType.Move:
                this.endPoint = { x:event.touches[0].x, y:event.touches[0].y };
                if (this.isPullDown && this.callbacks.onTopBound) {
                    this.callbacks.onTopBound(this.delta);
                } else if (this.isPullUp && this.callbacks.onBottomBound) {
                    this.callbacks.onBottomBound(this.delta);
                }
                break;
            default:
                break;
        }
    }
}
