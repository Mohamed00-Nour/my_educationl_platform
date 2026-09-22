import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/auth/domain/entities/user_entity.dart';
import 'package:instructor/features/student_management/data/student_management_repository.dart';
import 'package:instructor/features/student_management/presentation/screens/student_management_screen.dart';
import 'package:mocktail/mocktail.dart';

class _StudentManagementRepositoryMock extends Mock
    implements StudentManagementRepository {}

void main() {
  testWidgets('admin must confirm deletion of a student profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const admin = UserEntity(
      id: 'admin-1',
      email: 'admin@example.com',
      displayName: 'Teacher',
      role: UserRole.admin,
    );
    const student = ManagedStudent(
      id: 'student-1',
      displayName: 'Student One',
      email: 'student@example.com',
      grade: null,
      ownerAdminId: 'admin-1',
      enrolledCourseIds: [],
      createdAt: null,
    );
    final repository = _StudentManagementRepositoryMock();
    var deleted = false;
    when(
      () => repository.loadStudents(admin),
    ).thenAnswer((_) async => deleted ? [] : [student]);
    when(() => repository.loadCourses(admin)).thenAnswer((_) async => []);
    when(() => repository.deleteStudent(student)).thenAnswer((_) async {
      deleted = true;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StudentManagementScreen(admin: admin, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Student One'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف ملف الطالب'));
    await tester.pumpAndSettle();
    expect(find.text('حذف ملف الطالب؟'), findsOneWidget);
    verifyNever(() => repository.deleteStudent(student));

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.deleteStudent(student));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف ملف الطالب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الملف'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteStudent(student)).called(1);
    expect(find.text('Student One'), findsNothing);
  });
}
