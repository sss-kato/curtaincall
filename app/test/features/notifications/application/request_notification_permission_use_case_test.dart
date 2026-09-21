import 'package:curtaincall/features/notifications/application/request_notification_permission_use_case.dart';
import 'package:curtaincall/features/notifications/domain/push_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_push_gateway.dart';

void main() {
  group('許可の要求', () {
    test('permissionStatus が notDetermined → requestPermission が 1 回呼ばれ、 '
        'その戻り値（authorized / denied）を返す', () async {
      final gateway = FakePushGateway(
        permissionStatus: PushPermissionStatus.notDetermined,
      )..requestPermissionResult = PushPermissionStatus.authorized;
      final useCase = RequestNotificationPermissionUseCase(gateway);

      final result = await useCase.execute();

      expect(result, PushPermissionStatus.authorized);
      expect(
        gateway.calls.where((c) => c == 'requestPermission'),
        hasLength(1),
      );
    });

    test('permissionStatus が notDetermined → requestPermission の denied '
        'をそのまま返す', () async {
      final gateway = FakePushGateway(
        permissionStatus: PushPermissionStatus.notDetermined,
      )..requestPermissionResult = PushPermissionStatus.denied;
      final useCase = RequestNotificationPermissionUseCase(gateway);

      final result = await useCase.execute();

      expect(result, PushPermissionStatus.denied);
    });

    test('authorized → requestPermission を呼ばず authorized', () async {
      final gateway = FakePushGateway();
      final useCase = RequestNotificationPermissionUseCase(gateway);

      final result = await useCase.execute();

      expect(result, PushPermissionStatus.authorized);
      expect(gateway.calls, isNot(contains('requestPermission')));
    });

    test('denied → requestPermission を呼ばず denied', () async {
      final gateway = FakePushGateway(
        permissionStatus: PushPermissionStatus.denied,
      );
      final useCase = RequestNotificationPermissionUseCase(gateway);

      final result = await useCase.execute();

      expect(result, PushPermissionStatus.denied);
      expect(gateway.calls, isNot(contains('requestPermission')));
    });

    test('requestPermission が例外 → そのまま伝播する', () async {
      final gateway = FakePushGateway(
        permissionStatus: PushPermissionStatus.notDetermined,
      )..requestPermissionError = Exception('boom');
      final useCase = RequestNotificationPermissionUseCase(gateway);

      await expectLater(useCase.execute(), throwsException);
    });
  });
}
