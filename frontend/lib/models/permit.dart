class Permit {
  final int id;
  final String permitNumber;
  final int applicantId;
  final String permitType;
  final String status;
  final String workDescription;
  final String workLocation;
  final DateTime startDate;
  final DateTime endDate;
  final String? hazardIdentification;
  final String? controlMeasures;
  final String? ppeRequired;
  final String? rejectionReason;
  final String? applicantName;
  final String? applicantDepartment;
  final DateTime createdAt;

  Permit({
    required this.id,
    required this.permitNumber,
    required this.applicantId,
    required this.permitType,
    required this.status,
    required this.workDescription,
    required this.workLocation,
    required this.startDate,
    required this.endDate,
    this.hazardIdentification,
    this.controlMeasures,
    this.ppeRequired,
    this.rejectionReason,
    this.applicantName,
    this.applicantDepartment,
    required this.createdAt,
  });

  factory Permit.fromJson(Map<String, dynamic> json) {
    return Permit(
      id: json['id'],
      permitNumber: json['permit_number'],
      applicantId: json['applicant_id'],
      permitType: json['permit_type'],
      status: json['status'],
      workDescription: json['work_description'],
      workLocation: json['work_location'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      hazardIdentification: json['hazard_identification'],
      controlMeasures: json['control_measures'],
      ppeRequired: json['ppe_required'],
      rejectionReason: json['rejection_reason'],
      applicantName: json['applicant_name'],
      applicantDepartment: json['applicant_department'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get typeLabel {
    switch (permitType) {
      case 'confined_space':
        return 'Confined Space';
      case 'working_at_height':
        return 'Working at Height';
      case 'excavation':
        return 'Excavation';
      case 'electrical':
        return 'Electrical Work';
      case 'hot_work':
        return 'Hot Work';
      default:
        return permitType;
    }
  }

  String get typeIcon {
    switch (permitType) {
      case 'confined_space':
        return '🕳️';
      case 'working_at_height':
        return '🪜';
      case 'excavation':
        return '⛏️';
      case 'electrical':
        return '⚡';
      case 'hot_work':
        return '🔥';
      default:
        return '📋';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'submitted':
        return 'Submitted';
      case 'k3_filled':
        return 'K3 Filled (Review By K3 Umum)';
      case 'k3_umum_approved':
        return 'K3 Umum Approved (Review By Mill Assistant)';
      case 'mill_assistant_approved':
        return 'Mill Assistant Approved (Pending Final Approval)';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'active':
        return 'Active';
      case 'expired':
        return 'Expired';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }
}

class PermitDocument {
  final int id;
  final int permitId;
  final String documentName;
  final String filePath;
  final String? fileType;
  final int? fileSize;

  PermitDocument({
    required this.id,
    required this.permitId,
    required this.documentName,
    required this.filePath,
    this.fileType,
    this.fileSize,
  });

  factory PermitDocument.fromJson(Map<String, dynamic> json) {
    return PermitDocument(
      id: json['id'],
      permitId: json['permit_id'],
      documentName: json['document_name'],
      filePath: json['file_path'],
      fileType: json['file_type'],
      fileSize: json['file_size'],
    );
  }
}

class ApprovalHistory {
  final int id;
  final int permitId;
  final int? reviewerId;
  final String action;
  final String? comments;
  final String? reviewerRole;
  final String? reviewerName;
  final DateTime actionDate;

  ApprovalHistory({
    required this.id,
    required this.permitId,
    this.reviewerId,
    required this.action,
    this.comments,
    this.reviewerRole,
    this.reviewerName,
    required this.actionDate,
  });

  factory ApprovalHistory.fromJson(Map<String, dynamic> json) {
    return ApprovalHistory(
      id: json['id'],
      permitId: json['permit_id'],
      reviewerId: json['reviewer_id'],
      action: json['action'],
      comments: json['comments'],
      reviewerRole: json['reviewer_role'],
      reviewerName: json['reviewer_name'],
      actionDate: DateTime.parse(json['action_date']),
    );
  }
}
