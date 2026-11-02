import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d_video.dart';

void main() {
  group('jellyVideoPetBodySpan 启用区域联合包围盒', () {
    test('空列表与全停用返回 null（按整画布计算）', () {
      expect(jellyVideoPetBodySpan(const []), isNull);
      expect(
        jellyVideoPetBodySpan([
          VideoPetRegion(
            id: 'a',
            name: 'A',
            x: 0.1,
            y: 0.1,
            width: 0.2,
            height: 0.2,
            enabled: false,
          ),
        ]),
        isNull,
      );
    });

    test('多个启用区域取联合包围盒', () {
      final span = jellyVideoPetBodySpan([
        VideoPetRegion(
          id: 'a',
          name: 'A',
          x: 0.3,
          y: 0.1,
          width: 0.2,
          height: 0.2,
        ),
        VideoPetRegion(
          id: 'b',
          name: 'B',
          x: 0.1,
          y: 0.5,
          width: 0.2,
          height: 0.2,
        ),
      ]);
      expect(span, isNotNull);
      expect(span!.left, closeTo(0.1, 1e-9));
      expect(span.right, closeTo(0.5, 1e-9));
    });
  });

  group('jellyVideoPetDefaultRect 默认显示矩形（镜像舞台数学）', () {
    test('宠物小于容器：水平居中、垂直贴活动区底部', () {
      final rect = jellyVideoPetDefaultRect(
        layoutWidth: 400,
        layoutHeight: 800,
        topInset: 60,
        bottomInset: 40,
        petWidth: 200,
        canvasAspectRatio: 1.5,
      );
      // 可用高 800-60-40=700；无缩放 w=200 h=300；
      // 无区域且非满宽：x ∈ [0,200] 取中心 100
      expect(rect.left, closeTo(100, 1e-9));
      expect(rect.top, closeTo(460, 1e-9));
      expect(rect.width, closeTo(200, 1e-9));
      expect(rect.height, closeTo(300, 1e-9));
      // 底边正好落在底部预留线上
      expect(rect.bottom, closeTo(800 - 40, 1e-9));
    });

    test('宠物超出容器：按宽高比缩放并走中心锚点边界', () {
      final rect = jellyVideoPetDefaultRect(
        layoutWidth: 400,
        layoutHeight: 800,
        topInset: 60,
        bottomInset: 40,
        petWidth: 900,
        canvasAspectRatio: 1.0,
      );
      // scale=min(400/900, 700/900)=0.444… → 满宽画布 w=h=400，
      // 中心锚点 minX=-200 maxX=200 → 中心 0
      expect(rect.width, closeTo(400, 1e-6));
      expect(rect.height, closeTo(400, 1e-6));
      expect(rect.left, closeTo(0, 1e-6));
      expect(rect.top, closeTo(60 + (700 - 400), 1e-6));
    });

    test('有启用区域联合包围盒：按包围盒贴边取活动中心', () {
      final rect = jellyVideoPetDefaultRect(
        layoutWidth: 400,
        layoutHeight: 800,
        topInset: 0,
        bottomInset: 0,
        petWidth: 400,
        canvasAspectRatio: 1.0,
        bodySpan: (left: 0.2, right: 0.8),
      );
      // minX=-0.2*400=-80，maxX=400-0.8*400=80 → 中心 0
      expect(rect.left, closeTo(0, 1e-9));
      expect(rect.top, closeTo(400, 1e-9));
    });
  });

  group('jellyVideoBubbleBoxAboveVideo 气泡锚定盒', () {
    test('与视频同宽、上方居中、盒底贴视频顶', () {
      final videoRect = Rect.fromLTWH(100, 460, 200, 300);
      final box = jellyVideoBubbleBoxAboveVideo(
        containerWidth: 400,
        containerTop: 60,
        videoRect: videoRect,
      );
      expect(box.width, closeTo(200, 1e-9));
      expect(box.left, closeTo(100, 1e-9));
      expect(box.top, closeTo(60, 1e-9));
      // 盒底 = 视频顶 - gap(8)
      expect(box.bottom, closeTo(452, 1e-9));
    });

    test('视频比容器宽：按边距收窄并夹回屏内', () {
      final videoRect = Rect.fromLTWH(-60, 150, 520, 400);
      final box = jellyVideoBubbleBoxAboveVideo(
        containerWidth: 400,
        containerTop: 40,
        videoRect: videoRect,
      );
      // width=min(520, 400-24)=376；left 夹到 margin
      expect(box.width, closeTo(376, 1e-9));
      expect(box.left, closeTo(12, 1e-9));
      expect(box.height, closeTo(150 - 8 - 40, 1e-9));
    });
  });

  group('JellyVideoBubbleAboveDelegate 盒内底部对齐居中', () {
    const delegate = JellyVideoBubbleAboveDelegate();

    test('子级在盒内水平居中且底边贴盒底（自然高度）', () {
      final offset = delegate.getPositionForChild(
        const Size(200, 392),
        const Size(180, 80),
      );
      expect(offset.dx, closeTo(10, 1e-9));
      expect(offset.dy, closeTo(392 - 80, 1e-9));
    });

    test('子级约束只设上限（宽度跟随盒宽、高度自然伸缩）', () {
      final constraints = delegate.getConstraintsForChild(
        const BoxConstraints(maxWidth: 300, maxHeight: 392),
      );
      expect(constraints.maxWidth, 300);
      expect(constraints.maxHeight, 392);
      expect(constraints.minWidth, 0);
      expect(constraints.minHeight, 0);
    });
  });

  group('气泡盒跟随当前（被拖动后的）视频矩形', () {
    test('宠物拖到左上角：气泡盒随之居中在当前矩形上方', () {
      // 宠物从默认落点被拖到容器左上角（topInset 之下紧贴）
      final draggedRect = Rect.fromLTWH(12, 60, 180, 260);
      final box = jellyVideoBubbleBoxAboveVideo(
        containerWidth: 400,
        containerTop: 20,
        videoRect: draggedRect,
      );
      // 与当前视频同宽、水平中心对齐当前矩形
      expect(box.width, closeTo(180, 1e-9));
      expect(box.left, closeTo(12, 1e-9));
      // 盒底 = 当前视频顶 - 8
      expect(box.bottom, closeTo(60 - 8, 1e-9));
      expect(box.top, closeTo(20, 1e-9));
    });

    test('宠物拖到右侧：中心对齐当前矩形而非容器中心', () {
      final draggedRect = Rect.fromLTWH(220, 300, 160, 240);
      final box = jellyVideoBubbleBoxAboveVideo(
        containerWidth: 400,
        containerTop: 40,
        videoRect: draggedRect,
      );
      // 当前矩形中心 = 220+80 = 300 → left = 300-80 = 220
      expect(box.left, closeTo(220, 1e-9));
      expect(box.width, closeTo(160, 1e-9));
      expect(box.bottom, closeTo(300 - 8, 1e-9));
    });
  });

  group('jellyVideoBubbleWidthFor 浮动宠精确同宽', () {
    test('窄视频（<160）不再被人为抬到 160', () {
      expect(
        jellyVideoBubbleWidthFor(videoWidth: 120, maxWidth: 800),
        closeTo(120, 1e-9),
      );
    });

    test('宽视频（>260）不再被截到 260', () {
      expect(
        jellyVideoBubbleWidthFor(videoWidth: 340, maxWidth: 800),
        closeTo(340, 1e-9),
      );
    });

    test('仅屏幕安全宽度可收窄；非法宽度归零', () {
      expect(
        jellyVideoBubbleWidthFor(videoWidth: 340, maxWidth: 300),
        closeTo(300, 1e-9),
      );
      expect(jellyVideoBubbleWidthFor(videoWidth: 0, maxWidth: 300), 0);
      expect(jellyVideoBubbleWidthFor(videoWidth: -5, maxWidth: 300), 0);
    });
  });
}
