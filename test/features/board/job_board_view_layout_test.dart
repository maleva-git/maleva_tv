import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maleva_tv/features/board/job_board_view.dart';
import 'package:maleva_tv/features/home/domain/entities/job_model.dart';

JobModel _job(int id, String status) => JobModel(
      id: id,
      jobNo: 'SO-26-0148$id',
      jobStatus: status,
      picName: 'Ahmad Faizal Bin Abdullah',
      loadingVesselName: 'MV OCEAN PIONEER EXPRESS',
      offVesselName: 'MV SEA EAGLE',
      port: 'Westport, Port Klang',
      seta: '2026-10-14 10:30:00',
      setb: '2026-10-14 12:00:00',
      setd: '2026-10-14 20:00:00',
      soeta: '2026-10-14 13:30:00',
      soetb: '2026-10-14 15:00:00',
      soetd: '2026-10-15 06:00:00',
    );

void main() {
  final jobs = [
    _job(1, 'ASSIGNED'),
    _job(2, 'IN TRANSIT'),
    _job(3, 'PENDING'),
    _job(4, 'COMPLETED'),
    _job(5, 'CANCELLED'),
  ];

  // 894 px wide puts the title bar's Row at the 846 px from the reported overflow.
  for (final width in [800.0, 894.0, 1280.0, 1920.0, 3840.0]) {
    testWidgets('the board lays out without overflow at $width px', (tester) async {
      tester.view.physicalSize = Size(width, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: JobBoardView(
            title: 'VESSEL PLANNING',
            subtitle: 'Vessel jobs board',
            date: DateTime(2026, 10, 14),
            onChangeDate: (_) {},
            jobs: AsyncValue.data(jobs),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('VESSEL PLANNING'), findsOneWidget);
    });
  }
}
