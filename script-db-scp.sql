-- ==================================================================================
-- SITEMA DE CONTROL DE PERSONAL (SCP)
-- Engine: MySQL 8.x
-- Convención: PascalCase con Prefijo de Dominio (Simulando Schemas)
-- Fecha: 2026-03-17
-- ==================================================================================

CREATE DATABASE IF NOT EXISTS scp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE scp_db;

-- ==================================================================================
-- DOMINIO: SYS (Seguridad, Auditoría y Configuración)
-- Contexto: Autenticación, control de accesos, settings globales.
-- ==================================================================================

CREATE TABLE IF NOT EXISTS Sys_Roles (
    RoleId       INT AUTO_INCREMENT PRIMARY KEY,
    Name         VARCHAR(80) NOT NULL,
    Description  VARCHAR(250) NULL,
    IsActive     TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY UQ_SysRoles_Name (Name)
);

CREATE TABLE IF NOT EXISTS Sys_Sites (
    SiteId        INT AUTO_INCREMENT PRIMARY KEY,
    Name          VARCHAR(150) NOT NULL,
    Code          VARCHAR(20)  NULL,
    Location      VARCHAR(250) NULL,
    IsActive      TINYINT(1) NOT NULL DEFAULT 1,
    CreatedByUserId INT NULL, -- FK referenciada después
    CreatedAtUtc  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY UQ_SysSites_Name (Name),
    UNIQUE KEY UQ_SysSites_Code (Code)
);

CREATE TABLE IF NOT EXISTS Sys_Users (
    UserId             INT AUTO_INCREMENT PRIMARY KEY,
    SiteId             INT NULL,
    Username           VARCHAR(120) NOT NULL,
    PasswordHash       VARCHAR(255) NULL,
    FullName           VARCHAR(200) NULL,
    EmployeeCode       VARCHAR(60)  NULL,
    AssignedArea       VARCHAR(120) NULL,
    IsActive           TINYINT(1) NOT NULL DEFAULT 1,
    LoginIssue         TINYINT(1) NOT NULL DEFAULT 0,
    LoginIssueAtUtc    DATETIME NULL,
    TokenNotBeforeUtc  DATETIME NOT NULL DEFAULT '2000-01-01 00:00:00',
    CreatedAtUtc       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAtUtc       DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY UQ_SysUsers_Username (Username),
    CONSTRAINT FK_SysUsers_SysSites FOREIGN KEY (SiteId) REFERENCES Sys_Sites(SiteId)
);

-- Agregar la FK circular ahora que Sys_Users existe
ALTER TABLE Sys_Sites
ADD CONSTRAINT FK_SysSites_CreatedBy FOREIGN KEY (CreatedByUserId) REFERENCES Sys_Users(UserId);

CREATE TABLE IF NOT EXISTS Sys_UserRoles (
    UserId INT NOT NULL,
    RoleId INT NOT NULL,
    PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_SysUserRoles_Users FOREIGN KEY (UserId) REFERENCES Sys_Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_SysUserRoles_Roles FOREIGN KEY (RoleId) REFERENCES Sys_Roles(RoleId) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Sys_RevokedTokens (
    Jti         VARCHAR(64) NOT NULL PRIMARY KEY,
    ExpiresAtUtc DATETIME NOT NULL,
    CreatedAtUtc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Sys_AuditLogs (
    AuditLogId     BIGINT AUTO_INCREMENT PRIMARY KEY,
    TableName      VARCHAR(128) NOT NULL,
    RecordId       VARCHAR(80) NULL,
    Action         VARCHAR(40) NOT NULL,
    OldValues      JSON NULL,
    NewValues      JSON NULL,
    ChangedBy      VARCHAR(120) NULL,
    ChangedAtUtc   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX IX_SysAuditLogs_ChangedAt (ChangedAtUtc)
);

CREATE TABLE IF NOT EXISTS Sys_SecurityEvents (
    SecurityEventId BIGINT AUTO_INCREMENT PRIMARY KEY,
    EventType       VARCHAR(80) NOT NULL,
    Username        VARCHAR(120) NULL,
    IpAddress       VARCHAR(60) NULL,
    Detail          VARCHAR(500) NULL,
    CreatedAtUtc    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX IX_SysSecurity_CreatedAt (CreatedAtUtc)
);

CREATE TABLE IF NOT EXISTS Sys_Settings (
    SystemSettingId INT AUTO_INCREMENT PRIMARY KEY,
    SettingGroup    VARCHAR(80) NOT NULL,
    SettingKey      VARCHAR(120) NOT NULL,
    SettingValue    VARCHAR(500) NULL,
    Description     VARCHAR(250) NULL,
    IsActive        TINYINT(1) NOT NULL DEFAULT 1,
    UpdatedByUserId INT NULL,
    UpdatedAtUtc    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY UQ_SysSettings_GroupKey (SettingGroup, SettingKey),
    CONSTRAINT FK_SysSettings_UpdatedBy FOREIGN KEY (UpdatedByUserId) REFERENCES Sys_Users(UserId)
);

-- ==================================================================================
-- DOMINIO: ORG (Organización Arquitectónica)
-- Contexto: Jerarquía de trabajo: Proyectos -> Áreas + Procesos/Puestos.
-- ==================================================================================

CREATE TABLE IF NOT EXISTS Org_Projects (
    ProjectId    INT AUTO_INCREMENT PRIMARY KEY,
    SiteId       INT NOT NULL,
    Name         VARCHAR(180) NOT NULL,
    Code         VARCHAR(40)  NULL,
    Description  VARCHAR(500) NULL,
    ClientName   VARCHAR(180) NULL,
    StartDate    DATE NULL,
    Status       VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    IsActive     TINYINT(1) NOT NULL DEFAULT 1,
    Icon         VARCHAR(80) NOT NULL DEFAULT 'fa-folder-tree',
    CreatedByUserId INT NULL,
    CreatedAtUtc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY UQ_OrgProjects_Name (Name),
    CONSTRAINT FK_OrgProjects_SysSites FOREIGN KEY (SiteId) REFERENCES Sys_Sites(SiteId),
    CONSTRAINT FK_OrgProjects_SysUsers FOREIGN KEY (CreatedByUserId) REFERENCES Sys_Users(UserId)
);

CREATE TABLE IF NOT EXISTS Org_Areas (
    AreaId      INT AUTO_INCREMENT PRIMARY KEY,
    ProjectId   INT NOT NULL,
    Name        VARCHAR(180) NOT NULL,
    IsActive    TINYINT(1) NOT NULL DEFAULT 1,
    CreatedByUserId INT NULL,
    CreatedAtUtc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY UQ_OrgAreas_Project_Name (ProjectId, Name),
    CONSTRAINT FK_OrgAreas_OrgProjects FOREIGN KEY (ProjectId) REFERENCES Org_Projects(ProjectId) ON DELETE CASCADE,
    CONSTRAINT FK_OrgAreas_SysUsers FOREIGN KEY (CreatedByUserId) REFERENCES Sys_Users(UserId)
);

CREATE TABLE IF NOT EXISTS Org_Processes (
    ProcessId   INT AUTO_INCREMENT PRIMARY KEY,
    Name        VARCHAR(140) NOT NULL,
    IsActive    TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY UQ_OrgProcesses_Name (Name)
);

CREATE TABLE IF NOT EXISTS Org_Positions (
    PositionId   INT AUTO_INCREMENT PRIMARY KEY,
    Name         VARCHAR(140) NOT NULL,
    IsActive     TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY UQ_OrgPositions_Name (Name)
);

-- ==================================================================================
-- DOMINIO: HR (Recursos Humanos - Control de Personal)
-- Contexto: Headcount físico, organigrama, historial y estatus laboral.
-- ==================================================================================

CREATE TABLE IF NOT EXISTS HR_Staff (
    StaffId                 INT AUTO_INCREMENT PRIMARY KEY,
    SiteId                  INT NOT NULL,
    ProjectId               INT NULL,
    AreaId                  INT NULL,
    PositionId              INT NULL,
    ProcessId               INT NULL,
    SupervisorStaffId       INT NULL,
    ManagerStaffId          INT NULL,
    EmployeeCode            VARCHAR(60) NOT NULL,
    FullName                VARCHAR(200) NOT NULL,
    PayrollType             VARCHAR(40) NULL,
    Shift                   VARCHAR(40) NULL,
    ShiftPublished          TINYINT(1) NOT NULL DEFAULT 1,
    EntryDate               DATE NULL,
    OriginalEntryDate       DATE NULL,
    TerminationDate         DATE NULL,
    TerminationReason       VARCHAR(250) NULL,
    PreviousTerminationReason VARCHAR(250) NULL,
    CurrentStatus           VARCHAR(40) NOT NULL DEFAULT 'active',
    PositionTag             VARCHAR(80) NOT NULL DEFAULT '',
    IsRehire                TINYINT(1) NOT NULL DEFAULT 0,
    IsActive                TINYINT(1) NOT NULL DEFAULT 1,
    AdditionalComment       VARCHAR(500) NULL,
    AreaAssignedAtUtc       DATETIME NULL,
    CreatedAtUtc            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAtUtc            DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY UQ_HRStaff_EmployeeCode (EmployeeCode),
    INDEX IX_HRStaff_SiteId (SiteId),
    INDEX IX_HRStaff_AreaId (AreaId),
    CONSTRAINT FK_HRStaff_SysSites FOREIGN KEY (SiteId) REFERENCES Sys_Sites(SiteId),
    CONSTRAINT FK_HRStaff_OrgProjects FOREIGN KEY (ProjectId) REFERENCES Org_Projects(ProjectId),
    CONSTRAINT FK_HRStaff_OrgAreas FOREIGN KEY (AreaId) REFERENCES Org_Areas(AreaId),
    CONSTRAINT FK_HRStaff_OrgPositions FOREIGN KEY (PositionId) REFERENCES Org_Positions(PositionId),
    CONSTRAINT FK_HRStaff_OrgProcesses FOREIGN KEY (ProcessId) REFERENCES Org_Processes(ProcessId),
    CONSTRAINT FK_HRStaff_Supervisor FOREIGN KEY (SupervisorStaffId) REFERENCES HR_Staff(StaffId),
    CONSTRAINT FK_HRStaff_Manager FOREIGN KEY (ManagerStaffId) REFERENCES HR_Staff(StaffId)
);

CREATE TABLE IF NOT EXISTS HR_StaffStatusHistory (
    StaffStatusHistoryId INT AUTO_INCREMENT PRIMARY KEY,
    StaffId              INT NOT NULL,
    Status               VARCHAR(40) NOT NULL,
    Reason               VARCHAR(250) NULL,
    ChangedByUserId      INT NULL,
    ChangedAtUtc         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_HRStatus_HRStaff FOREIGN KEY (StaffId) REFERENCES HR_Staff(StaffId) ON DELETE CASCADE,
    CONSTRAINT FK_HRStatus_SysUsers FOREIGN KEY (ChangedByUserId) REFERENCES Sys_Users(UserId)
);

CREATE TABLE IF NOT EXISTS HR_StaffEvents (
    StaffEventId    INT AUTO_INCREMENT PRIMARY KEY,
    StaffId         INT NOT NULL,
    EventType       VARCHAR(80) NOT NULL,
    Note            VARCHAR(500) NULL,
    CreatedByUserId INT NULL,
    CreatedAtUtc    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_HREvents_HRStaff FOREIGN KEY (StaffId) REFERENCES HR_Staff(StaffId) ON DELETE CASCADE,
    CONSTRAINT FK_HREvents_SysUsers FOREIGN KEY (CreatedByUserId) REFERENCES Sys_Users(UserId)
);

-- ==================================================================================
-- DOMINIO: PLAN (Planeación y Liberaciones)
-- Contexto: El "DEBE", asignaciones esperadas vs reale, flujos de liberación.
-- ==================================================================================

CREATE TABLE IF NOT EXISTS Plan_Debe (
    PlanningDebeId INT AUTO_INCREMENT PRIMARY KEY,
    SiteId         INT NOT NULL,
    ProjectId      INT NOT NULL,
    AreaId         INT NOT NULL,
    PositionId     INT NOT NULL,
    Shift          VARCHAR(40) NOT NULL,
    Headcount      INT NOT NULL,
    EffectiveDate  DATE NULL,
    IsActive       TINYINT(1) NOT NULL DEFAULT 1,
    CreatedAtUtc   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAtUtc   DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY UQ_PlanDebe (SiteId, ProjectId, AreaId, PositionId, Shift, EffectiveDate),
    CONSTRAINT FK_PlanDebe_SysSites FOREIGN KEY (SiteId) REFERENCES Sys_Sites(SiteId),
    CONSTRAINT FK_PlanDebe_OrgProjects FOREIGN KEY (ProjectId) REFERENCES Org_Projects(ProjectId),
    CONSTRAINT FK_PlanDebe_OrgAreas FOREIGN KEY (AreaId) REFERENCES Org_Areas(AreaId),
    CONSTRAINT FK_PlanDebe_OrgPositions FOREIGN KEY (PositionId) REFERENCES Org_Positions(PositionId)
);

CREATE TABLE IF NOT EXISTS Plan_Assignments (
    PlanningAssignmentId INT AUTO_INCREMENT PRIMARY KEY,
    PlanningDebeId       INT NOT NULL,
    StaffId              INT NOT NULL,
    AssignedAtUtc        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    IsActive             TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY UQ_PlanAssignments (PlanningDebeId, StaffId),
    CONSTRAINT FK_PlanAssign_PlanDebe FOREIGN KEY (PlanningDebeId) REFERENCES Plan_Debe(PlanningDebeId) ON DELETE CASCADE,
    CONSTRAINT FK_PlanAssign_HRStaff FOREIGN KEY (StaffId) REFERENCES HR_Staff(StaffId) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Plan_Releases (
    ReleaseId          INT AUTO_INCREMENT PRIMARY KEY,
    StaffId            INT NOT NULL,
    SiteId             INT NOT NULL,
    ProjectId          INT NULL,
    AreaId             INT NULL,
    PositionId         INT NULL,
    AssignedShift      VARCHAR(40) NULL,
    AssignedProcess    VARCHAR(140) NULL,
    AssignedSupervisor VARCHAR(200) NULL,
    WeekStartDate      DATE NULL,
    ReleaseType        VARCHAR(30) NOT NULL,
    Status             VARCHAR(30) NOT NULL DEFAULT 'pending',
    PublishedAtUtc     DATETIME NULL,
    CreatedAtUtc       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAtUtc       DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    INDEX IX_PlanReleases_Staff (StaffId),
    CONSTRAINT FK_PlanReleases_HRStaff FOREIGN KEY (StaffId) REFERENCES HR_Staff(StaffId) ON DELETE CASCADE,
    CONSTRAINT FK_PlanReleases_SysSites FOREIGN KEY (SiteId) REFERENCES Sys_Sites(SiteId),
    CONSTRAINT FK_PlanReleases_OrgProjects FOREIGN KEY (ProjectId) REFERENCES Org_Projects(ProjectId),
    CONSTRAINT FK_PlanReleases_OrgAreas FOREIGN KEY (AreaId) REFERENCES Org_Areas(AreaId),
    CONSTRAINT FK_PlanReleases_OrgPositions FOREIGN KEY (PositionId) REFERENCES Org_Positions(PositionId)
);

-- ==================================================================================
-- DOMINIO: OPS (Operaciones Diarias)
-- Contexto: Asistencias, inasistencias, horas extra y rotaciones diarias.
-- ==================================================================================

CREATE TABLE IF NOT EXISTS Ops_Attendance (
    AttendanceId  INT AUTO_INCREMENT PRIMARY KEY,
    StaffId       INT NOT NULL,
    AttendanceDate DATE NOT NULL,
    Status        VARCHAR(40) NOT NULL,
    ArrivalTime   TIME NULL,
    DepartureTime TIME NULL,
    Notes         VARCHAR(400) NULL,
    CreatedAtUtc  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAtUtc  DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY UQ_OpsAttendance (StaffId, AttendanceDate),
    CONSTRAINT FK_OpsAttendance_HRStaff FOREIGN KEY (StaffId) REFERENCES HR_Staff(StaffId) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Ops_Absences (
    AbsenceId        INT AUTO_INCREMENT PRIMARY KEY,
    StaffId          INT NOT NULL,
    AbsenceType      VARCHAR(60) NOT NULL,
    Folio            VARCHAR(80) NULL,
    Status           VARCHAR(40) NOT NULL DEFAULT 'pending',
    Description      VARCHAR(500) NULL,
    AttachmentPath   VARCHAR(400) NULL,
    StartDate        DATE NOT NULL,
    EndDate          DATE NULL,
    ApprovalStatus   VARCHAR(40) NULL,
    ApprovedByUserId INT NULL,
    ApprovedAtUtc    DATETIME NULL,
    CreatedAtUtc     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAtUtc     DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT FK_OpsAbs_HRStaff FOREIGN KEY (StaffId) REFERENCES HR_Staff(StaffId) ON DELETE CASCADE,
    CONSTRAINT FK_OpsAbs_SysUsers FOREIGN KEY (ApprovedByUserId) REFERENCES Sys_Users(UserId)
);

CREATE TABLE IF NOT EXISTS Ops_OvertimeRequests (
    OvertimeRequestId INT AUTO_INCREMENT PRIMARY KEY,
    StaffId           INT NOT NULL,
    RelatedAbsenceId  INT NULL,
    OvertimeDate      DATE NOT NULL,
    Hours             DECIMAL(5,2) NOT NULL,
    OvertimeType      VARCHAR(30) NOT NULL,
    Status            VARCHAR(30) NOT NULL DEFAULT 'pending',
    AttachmentPath    VARCHAR(400) NULL,
    ApprovedByUserId  INT NULL,
    ApprovedAtUtc     DATETIME NULL,
    CreatedAtUtc      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAtUtc      DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT FK_OpsOVT_HRStaff FOREIGN KEY (StaffId) REFERENCES HR_Staff(StaffId) ON DELETE CASCADE,
    CONSTRAINT FK_OpsOVT_OpsAbs FOREIGN KEY (RelatedAbsenceId) REFERENCES Ops_Absences(AbsenceId),
    CONSTRAINT FK_OpsOVT_SysUsers FOREIGN KEY (ApprovedByUserId) REFERENCES Sys_Users(UserId)
);

CREATE TABLE IF NOT EXISTS Ops_ShiftRotations (
    ShiftRotationId   INT AUTO_INCREMENT PRIMARY KEY,
    SiteId            INT NOT NULL,
    SupervisorStaffId INT NULL,
    FromShift         VARCHAR(40) NOT NULL,
    ToShift           VARCHAR(40) NOT NULL,
    PlannedDate       DATE NOT NULL,
    Status            VARCHAR(30) NOT NULL DEFAULT 'programado',
    Notes             VARCHAR(500) NULL,
    CreatedAtUtc      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_OpsRotations_SysSites FOREIGN KEY (SiteId) REFERENCES Sys_Sites(SiteId),
    CONSTRAINT FK_OpsRotations_HRStaff FOREIGN KEY (SupervisorStaffId) REFERENCES HR_Staff(StaffId)
);

CREATE TABLE IF NOT EXISTS Ops_RotationAssignments (
    RotationAssignmentId INT AUTO_INCREMENT PRIMARY KEY,
    ShiftRotationId      INT NOT NULL,
    StaffId              INT NOT NULL,
    Status               VARCHAR(30) NOT NULL DEFAULT 'asignado',
    CreatedAtUtc         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY UQ_OpsRotAssign (ShiftRotationId, StaffId),
    CONSTRAINT FK_OpsRotAssign_Rotation FOREIGN KEY (ShiftRotationId) REFERENCES Ops_ShiftRotations(ShiftRotationId) ON DELETE CASCADE,
    CONSTRAINT FK_OpsRotAssign_HRStaff FOREIGN KEY (StaffId) REFERENCES HR_Staff(StaffId) ON DELETE CASCADE
);

-- ==================================================================================
-- SEED DATA (Catálogos y Configuraciones Iniciales)
-- ==================================================================================

INSERT IGNORE INTO Sys_Sites (Name, Code, Location)
VALUES ('Puebla', 'PUE', 'Puebla, México');

INSERT IGNORE INTO Sys_Roles (Name, Description) VALUES
    ('admin', 'Acceso total'),
    ('director', 'Vista estratégica'),
    ('gerente', 'Gestión táctica'),
    ('planning', 'Planeación DEBE'),
    ('rh', 'Recursos humanos'),
    ('coordinador', 'Asignación y operación'),
    ('supervisor', 'Operación diaria');

INSERT IGNORE INTO Sys_Settings (SettingGroup, SettingKey, SettingValue, Description) VALUES
    ('app', 'default_site_code', 'PUE', 'Código de la sede por defecto'),
    ('security', 'jwt_expiry_hours', '8', 'Horas de vida del token JWT'),
    ('security', 'max_login_attempts', '5', 'Intentos máximos de login por ventana'),
    ('security', 'rate_limit_window_seconds', '300', 'Ventana de rate limit para login'),
    ('ui', 'default_project_icon', 'fa-folder-tree', 'Icono por defecto para proyectos'),
    ('admin', 'enable_audit_log', '1', 'Habilitar auditoría del sistema');

