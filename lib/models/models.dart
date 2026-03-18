import 'package:flutter/material.dart';

enum PermitStatus { pending, active, completed, cancelled }

enum UserRole { driver, mineOwner, hardwareOwner }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.driver:
        return "Transporter";
      case UserRole.mineOwner:
        return "Mines";
      case UserRole.hardwareOwner:
        return "Hardware Stores";
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.driver:
        return Icons.local_shipping;
      case UserRole.mineOwner:
        return Icons.engineering;
      case UserRole.hardwareOwner:
        return Icons.store;
    }
  }

  MaterialColor get color {
    switch (this) {
      case UserRole.driver:
        return Colors.blue;
      case UserRole.mineOwner:
        return Colors.orange;
      case UserRole.hardwareOwner:
        return Colors.purple;
    }
  }
}

class TransportPermit {
  final String id;
  String? permitCode;
  final String truckNumber;
  final double volumeCubes;
  final DateTime transportDate;
  DateTime expirationDate;
  final String? originLocationId;
  PermitStatus status;

  TransportPermit({
    required this.id,
    this.permitCode,
    required this.truckNumber,
    required this.volumeCubes,
    required this.transportDate,
    required this.expirationDate,
    this.originLocationId,
    this.status = PermitStatus.pending,
  });

  factory TransportPermit.fromJson(Map<String, dynamic> json) {
    return TransportPermit(
      id: json['id'].toString(),
      permitCode: json['permit_code'],
      truckNumber: json['truck_number'],
      volumeCubes: (json['volume_cubes'] as num).toDouble(),
      transportDate: DateTime.parse(json['transport_date']),
      expirationDate: DateTime.parse(json['expiration_date']),
      status: PermitStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == json['status'],
        orElse: () => PermitStatus.pending,
      ),
      originLocationId: json['origin_location_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'permit_code': permitCode,
      'truck_number': truckNumber,
      'volume_cubes': volumeCubes,
      'transport_date': transportDate.toIso8601String(),
      'expiration_date': expirationDate.toIso8601String(),
      'status': status.name.toUpperCase(),
    };
  }
}

class AppUser {
  final String id;
  final String name;
  final bool isMineOwner;
  final bool isHardwareOwner;

  AppUser({
    required this.id,
    required this.name,
    this.isMineOwner = false,
    this.isHardwareOwner = false,
  });
}
