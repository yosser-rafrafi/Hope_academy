import '../models/user_model.dart';

/// Central permission checks for the entire application.
/// Always pass the current [UserModel] — never hardcode role strings elsewhere.
class Permissions {
  // ── User Management ────────────────────────────────────────────────────────

  static bool canManageUsers(UserModel user) => user.role.canManageUsers;

  /// Admins can create any role. SubAdmins can only create Teacher and Parent.
  static bool canCreateRole(UserModel actor, UserRole target) =>
      actor.role.canCreateRole(target);

  /// SubAdmins cannot edit Admin or other SubAdmin accounts
  static bool canEditUser(UserModel actor, UserModel target) {
    if (actor.role == UserRole.admin) return true;
    if (actor.role == UserRole.subAdmin) {
      return target.role == UserRole.teacher ||
          target.role == UserRole.student;
    }
    return false;
  }

  static bool canDeactivateUser(UserModel actor, UserModel target) =>
      canEditUser(actor, target);

  // ── Financial / Salary ────────────────────────────────────────────────────

  static bool canViewSalaries(UserModel user) => user.role.canViewSalaries;
  static bool canEditSalaries(UserModel user) => user.role.canViewSalaries;

  // ── Fees (tuition, payments, receipts) ────────────────────────────────────

  /// Admin + SubAdmin run the fee desk. Parents read their own child's account.
  static bool canManageFees(UserModel user) =>
      user.role == UserRole.admin || user.role == UserRole.subAdmin;

  /// Cancelling payments / deleting charges is admin-only.
  static bool canDeleteFinance(UserModel user) => user.role == UserRole.admin;

  // ── System Settings ───────────────────────────────────────────────────────

  static bool canAccessSettings(UserModel user) =>
      user.role.canAccessSettings;

  // ── Analytics / Reports ───────────────────────────────────────────────────

  static bool canViewGlobalStats(UserModel user) =>
      user.role.canViewGlobalStats;

  /// SubAdmins can see operational stats but not financial ones
  static bool canViewOperationalStats(UserModel user) =>
      user.role == UserRole.admin || user.role == UserRole.subAdmin;

  // ── Classes & Students ────────────────────────────────────────────────────

  /// Admin/SubAdmin can see all classes; Teacher sees only their own
  static bool canViewAllClasses(UserModel user) =>
      user.role == UserRole.admin || user.role == UserRole.subAdmin;

  static bool canManageClasses(UserModel user) =>
      user.role == UserRole.admin || user.role == UserRole.subAdmin;

  /// Teacher can only access students assigned to them
  static bool canAccessStudent(UserModel user, List<String> studentTeacherIds) {
    if (user.role == UserRole.admin || user.role == UserRole.subAdmin) {
      return true;
    }
    if (user.role == UserRole.teacher) {
      return studentTeacherIds.contains(user.uid);
    }
    return false;
  }

  /// Student can only access their own children
  static bool canAccessStudentAsParent(
      UserModel user, List<String> studentParentIds) {
    if (user.role == UserRole.admin || user.role == UserRole.subAdmin) {
      return true;
    }
    if (user.role == UserRole.student) {
      return studentParentIds.contains(user.uid);
    }
    return false;
  }

  // ── PEI (Individualized Education Plan) ───────────────────────────────────

  /// Everyone who can open a student can read the PEI (parents: read-only).
  static bool canViewPei(UserModel user) => true;

  /// Admin / SubAdmin / Teacher write the PEI and record progress.
  /// (Teachers only reach their own students through the app navigation.)
  static bool canEditPei(UserModel user) =>
      user.role == UserRole.admin ||
      user.role == UserRole.subAdmin ||
      user.role == UserRole.teacher;

  /// Deleting goals / archiving plans is limited to the management team.
  static bool canManagePei(UserModel user) =>
      user.role == UserRole.admin || user.role == UserRole.subAdmin;

  // ── Dashboard sections by role ────────────────────────────────────────────

  static List<DashboardSection> sectionsFor(UserModel user) {
    switch (user.role) {
      case UserRole.admin:
        return _adminSections;
      case UserRole.subAdmin:
        return _subAdminSections;
      case UserRole.teacher:
        return _teacherSections;
      case UserRole.student:
        return _studentSections;
    }
  }

  static const _adminSections = [
    DashboardSection.overview,
    DashboardSection.userManagement,
    DashboardSection.studentManagement,
    DashboardSection.classManagement,
    DashboardSection.attendance,
    DashboardSection.activities,
    DashboardSection.reports,
    DashboardSection.finance,
    DashboardSection.salaries,
    DashboardSection.messages,
    DashboardSection.settings,
  ];

  static const _subAdminSections = [
    DashboardSection.overview,
    DashboardSection.userManagement,
    DashboardSection.studentManagement,
    DashboardSection.classManagement,
    DashboardSection.attendance,
    DashboardSection.activities,
    DashboardSection.reports,
    DashboardSection.finance,
    DashboardSection.messages,
    DashboardSection.announcements,
  ];

  static const _teacherSections = [
    DashboardSection.overview,
    DashboardSection.dailyActivity,
    DashboardSection.myStudents,
    DashboardSection.attendance,
    DashboardSection.aiReports,
    DashboardSection.messages,
  ];

  static const _studentSections = [
    DashboardSection.myChild,
    DashboardSection.photos,
    DashboardSection.reports,
    DashboardSection.attendance,
    DashboardSection.invoices,
    DashboardSection.messages,
    DashboardSection.announcements,
  ];
}

// ─── Dashboard sections enum ─────────────────────────────────────────────────

enum DashboardSection {
  overview,
  userManagement,
  studentManagement,
  classManagement,
  attendance,
  activities,
  reports,
  finance,        // admin + subAdmin (fees)
  salaries,       // admin only
  settings,       // admin only
  dailyActivity,  // teacher
  myStudents,     // teacher
  aiReports,      // teacher
  myChild,        // parent
  photos,         // parent
  invoices,       // parent
  messages,
  announcements,
}

extension DashboardSectionExt on DashboardSection {
  String get label {
    switch (this) {
      case DashboardSection.overview:
        return 'Dashboard';
      case DashboardSection.userManagement:
        return 'User Management';
      case DashboardSection.studentManagement:
        return 'Students';
      case DashboardSection.classManagement:
        return 'Classes';
      case DashboardSection.attendance:
        return 'Attendance';
      case DashboardSection.activities:
        return 'Activities Log';
      case DashboardSection.reports:
        return 'Reports';
      case DashboardSection.finance:
        return 'Finance';
      case DashboardSection.salaries:
        return 'Salaries';
      case DashboardSection.settings:
        return 'Settings';
      case DashboardSection.dailyActivity:
        return 'Daily Activity';
      case DashboardSection.myStudents:
        return 'My Students';
      case DashboardSection.aiReports:
        return 'AI Reports';
      case DashboardSection.myChild:
        return "My Child";
      case DashboardSection.photos:
        return 'Photos';
      case DashboardSection.invoices:
        return 'Invoices';
      case DashboardSection.messages:
        return 'Messages';
      case DashboardSection.announcements:
        return 'Announcements';
    }
  }

  String get icon {
    switch (this) {
      case DashboardSection.overview:
        return 'dashboard';
      case DashboardSection.userManagement:
        return 'people';
      case DashboardSection.studentManagement:
        return 'child_care';
      case DashboardSection.classManagement:
        return 'class';
      case DashboardSection.attendance:
        return 'event_available';
      case DashboardSection.activities:
        return 'local_activity';
      case DashboardSection.reports:
        return 'bar_chart';
      case DashboardSection.finance:
        return 'account_balance_wallet';
      case DashboardSection.salaries:
        return 'payments';
      case DashboardSection.settings:
        return 'settings';
      case DashboardSection.dailyActivity:
        return 'edit_note';
      case DashboardSection.myStudents:
        return 'groups';
      case DashboardSection.aiReports:
        return 'auto_awesome';
      case DashboardSection.myChild:
        return 'face';
      case DashboardSection.photos:
        return 'photo_library';
      case DashboardSection.invoices:
        return 'receipt';
      case DashboardSection.messages:
        return 'message';
      case DashboardSection.announcements:
        return 'campaign';
    }
  }

  // ── Section lists per role — defined in Permissions class ─────────────────
}
