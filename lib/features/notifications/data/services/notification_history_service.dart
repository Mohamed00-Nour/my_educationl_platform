import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/domain/entities/user_entity.dart';

typedef NotificationDocument = QueryDocumentSnapshot<Map<String, dynamic>>;

class NotificationHistoryService {
  final FirebaseFirestore _firestore;

  NotificationHistoryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<NotificationDocument>> watchForUser(UserEntity user) {
    final collection = _firestore.collection(
      FirestoreCollections.notificationsQueue,
    );

    if (user.isSuperAdmin) {
      return collection.snapshots().map((snapshot) => _sort(snapshot.docs));
    }

    if (user.isAdmin) {
      return collection
          .where('createdBy', isEqualTo: user.id)
          .snapshots()
          .map((snapshot) => _sort(snapshot.docs));
    }

    final targetIds =
        <String>{
          user.id,
          if (user.ownerAdminId != null && user.ownerAdminId!.trim().isNotEmpty)
            user.ownerAdminId!.trim(),
          ...user.enrolledCourseIds.where((id) => id.trim().isNotEmpty),
        }.toList();
    if (targetIds.isEmpty) {
      return Stream.value(const <NotificationDocument>[]);
    }

    final queries = <Query<Map<String, dynamic>>>[];
    for (var offset = 0; offset < targetIds.length; offset += 30) {
      final end = (offset + 30).clamp(0, targetIds.length);
      queries.add(
        collection.where('targetId', whereIn: targetIds.sublist(offset, end)),
      );
    }
    return _merge(queries);
  }

  Stream<List<NotificationDocument>> _merge(
    List<Query<Map<String, dynamic>>> queries,
  ) {
    late final StreamController<List<NotificationDocument>> controller;
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final latest = <int, List<NotificationDocument>>{};

    void emit() {
      final byId = <String, NotificationDocument>{};
      for (final documents in latest.values) {
        for (final document in documents) {
          byId[document.id] = document;
        }
      }
      controller.add(_sort(byId.values));
    }

    controller = StreamController<List<NotificationDocument>>(
      onListen: () {
        for (var index = 0; index < queries.length; index++) {
          subscriptions.add(
            queries[index].snapshots().listen((snapshot) {
              latest[index] = snapshot.docs;
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  List<NotificationDocument> _sort(Iterable<NotificationDocument> documents) {
    final sorted = documents.toList();
    sorted.sort((left, right) {
      final leftDate = _date(left.data()['createdAt']);
      final rightDate = _date(right.data()['createdAt']);
      return rightDate.compareTo(leftDate);
    });
    return sorted;
  }

  DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
