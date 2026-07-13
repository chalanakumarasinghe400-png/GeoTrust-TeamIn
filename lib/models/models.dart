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
  final String truckNumberPlate;
  final double noOfCubes;
  final DateTime startedDate;
  DateTime expiryDate;
  final String? mineId;
  final String? hardwareId;
  PermitStatus status;

  TransportPermit({
    required this.id,
    this.permitCode,
    required this.truckNumberPlate,
    required this.noOfCubes,
    required this.startedDate,
    required this.expiryDate,
    this.mineId,
    this.hardwareId,
    this.status = PermitStatus.active,
  });

  factory TransportPermit.fromJson(Map<String, dynamic> json) {
    return TransportPermit(
      id: json['permit_id'].toString(),
      permitCode: json['permit_code'],
      truckNumberPlate: json['truck_number_plate'],
      noOfCubes: (json['no_of_cubes'] as num).toDouble(),
      startedDate: DateTime.parse(json['started_date']),
      expiryDate: DateTime.parse(json['expiry_date']),
      status: PermitStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == json['status'],
        orElse: () => PermitStatus.active,
      ),
      mineId: json['mine_id'],
      hardwareId: json['hardware_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'permit_id': id,
      if (permitCode != null) 'permit_code': permitCode,
      'truck_number_plate': truckNumberPlate,
      'no_of_cubes': noOfCubes,
      // Using substring to send only the Date part (YYYY-MM-DD) for SQL DATE type
      'started_date': startedDate.toIso8601String().substring(0, 10),
      'expiry_date': expiryDate.toIso8601String().substring(0, 10),
      'status': status.name.toUpperCase(),
      if (mineId != null) 'mine_id': mineId,
      if (hardwareId != null) 'hardware_id': hardwareId,
    };
  }
}

class AppUser {
  final String id;
  final String name;
  final String nic;
  final String email;
  final String? profilePicture;

  AppUser({
    required this.id,
    required this.name,
    required this.nic,
    required this.email,
    this.profilePicture,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['user_id'].toString(),
      name: json['name'],
      nic: json['nic'],
      email: json['email'],
      profilePicture: json['profile_picture'],
    );
  }
}