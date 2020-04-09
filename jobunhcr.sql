-- phpMyAdmin SQL Dump
-- version 4.9.0.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Apr 09, 2020 at 06:21 PM
-- Server version: 10.4.6-MariaDB
-- PHP Version: 7.2.22

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `jobunhcr`
--

-- --------------------------------------------------------

--
-- Table structure for table `departments`
--

CREATE TABLE `departments` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `departments`
--

INSERT INTO `departments` (`id`, `name`, `description`, `created_at`, `updated_at`) VALUES
(1, 'Marketing', 'Marketing department', '2019-03-10 20:48:04', NULL),
(2, 'HR', 'HR Dept.', '2019-03-24 12:00:00', '2019-03-31 00:43:25'),
(3, 'Sales', 'Sales department', '2019-03-24 21:22:55', '2019-03-31 00:44:55'),
(4, 'Audit', 'Audit department', '2019-03-24 21:24:48', '2019-03-31 00:44:28');

-- --------------------------------------------------------

--
-- Table structure for table `designations`
--

CREATE TABLE `designations` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `designations`
--

INSERT INTO `designations` (`id`, `name`, `description`, `created_at`, `updated_at`) VALUES
(1, 'GM', 'General Manager, Sales', '2019-03-10 20:48:04', '2019-03-31 00:45:21'),
(2, 'SM', 'Sales Manager', '2019-03-24 21:44:39', '2019-03-31 00:45:42'),
(3, 'RSM', 'Regional Sales Manager', '2019-03-27 20:11:33', '2019-03-31 00:46:13'),
(4, 'AM', 'Area Manager', '2019-03-31 00:46:27', '2019-03-31 00:46:27'),
(5, 'MIO', 'MIO', '2019-03-31 00:46:47', '2019-03-31 00:46:47'),
(6, 'MD', NULL, '2019-03-31 00:47:20', '2019-03-31 00:47:20');

-- --------------------------------------------------------

--
-- Table structure for table `educations`
--

CREATE TABLE `educations` (
  `id` int(11) NOT NULL,
  `jobseeker_id` int(11) DEFAULT NULL,
  `degree_title` varchar(300) NOT NULL,
  `begin_date` date NOT NULL,
  `end_date` date NOT NULL,
  `level_of_education` varchar(300) NOT NULL,
  `school_name` varchar(300) NOT NULL,
  `education_completed` tinyint(4) DEFAULT NULL,
  `topics_of_study` varchar(500) DEFAULT NULL,
  `duration` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `educations`
--

INSERT INTO `educations` (`id`, `jobseeker_id`, `degree_title`, `begin_date`, `end_date`, `level_of_education`, `school_name`, `education_completed`, `topics_of_study`, `duration`, `created_at`, `updated_at`) VALUES
(3, 1, 'Bachelor of Science in Computer Science  & Engineering u', '2020-01-02', '2019-12-12', '1', 'Dhaka University of Engineering and Technology, Gazipur.  u', 0, 'null', 50, '2019-11-29 16:57:42', '2019-12-31 22:11:31'),
(5, 1, 'u', '2020-01-01', '2020-01-31', '4', 'test u', 0, 'null', 30, '2020-01-01 00:12:51', '2020-01-01 00:15:05');

-- --------------------------------------------------------

--
-- Table structure for table `jobseeker_personal_infos`
--

CREATE TABLE `jobseeker_personal_infos` (
  `id` int(11) NOT NULL,
  `first_name` varchar(200) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `jobseeker_personal_infos`
--

INSERT INTO `jobseeker_personal_infos` (`id`, `first_name`, `last_name`, `created_at`, `updated_at`) VALUES
(1, 'dd updated', 'aa updated', '2019-12-17 21:42:13', '2019-12-18 08:39:22');

-- --------------------------------------------------------

--
-- Table structure for table `jobseeker_references`
--

CREATE TABLE `jobseeker_references` (
  `id` int(11) NOT NULL,
  `jobseeker_id` int(11) DEFAULT NULL,
  `reference_name` varchar(500) NOT NULL,
  `title` varchar(500) NOT NULL,
  `employer` varchar(500) NOT NULL,
  `email_address` varchar(100) DEFAULT NULL,
  `address_line_one` text DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `jobseeker_references`
--

INSERT INTO `jobseeker_references` (`id`, `jobseeker_id`, `reference_name`, `title`, `employer`, `email_address`, `address_line_one`, `created_at`, `updated_at`) VALUES
(1, 1, 'Nurul Kabir', 'Field Coordinator', 'Partners in Health and Development(PHP)', 'kabirnurul76@gmail.com', 'Ukhia , Cox\'sbazar', '2019-11-24 12:56:37', '2019-11-24 19:01:19'),
(2, 1, 'Md.Kamrul Hasan', 'Referal Coordinator', 'Partners in Health and Development(PHP)', 'hasankamrul0103.hk@gmail.com', 'Ukhia , Cox\'sbazar', '2019-11-24 16:12:48', '2019-11-24 19:00:35'),
(3, 1, 'Sumon Ahmed Sabir', 'Chief Technology Officer ', 'Fiber @ Home Ltd.', 'sumon@fiberathome.net', 'Dhaka, Bangladesh', '2019-11-24 19:01:44', '2019-11-24 19:01:44');

-- --------------------------------------------------------

--
-- Table structure for table `job_applieds`
--

CREATE TABLE `job_applieds` (
  `id` int(11) NOT NULL,
  `jobeeker_user_id` int(11) NOT NULL,
  `job_post_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL,
  `job_title` varchar(500) NOT NULL,
  `position_number` varchar(200) NOT NULL,
  `email` varchar(100) NOT NULL,
  `shortlisted` tinyint(4) DEFAULT NULL COMMENT '1=yes,0=no'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `job_applieds`
--

INSERT INTO `job_applieds` (`id`, `jobeeker_user_id`, `job_post_id`, `created_at`, `job_title`, `position_number`, `email`, `shortlisted`) VALUES
(2, 1, 1, '2019-12-24 13:39:32', 'Senior Community-Based Protection Assistant	', 'PN 10028818\r\n', 'level1@unhcr.org', 1),
(5, 2, 3, '2019-12-24 15:53:21', 'Senior External Relations Officer', 'P4/234dds', 'applicant@unhcr.org', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `job_posts`
--

CREATE TABLE `job_posts` (
  `id` int(11) NOT NULL,
  `job_title` varchar(500) NOT NULL,
  `vacancy_notice` varchar(200) NOT NULL,
  `position_number` varchar(200) NOT NULL,
  `location` varchar(100) NOT NULL,
  `position_grade` varchar(50) NOT NULL,
  `closing_date` date NOT NULL,
  `organizational_context` text NOT NULL,
  `responsibilities` text NOT NULL,
  `accountability_and_authority` text NOT NULL,
  `minimum_qualification` text NOT NULL,
  `created_at` date DEFAULT NULL,
  `updated_at` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `job_posts`
--

INSERT INTO `job_posts` (`id`, `job_title`, `vacancy_notice`, `position_number`, `location`, `position_grade`, `closing_date`, `organizational_context`, `responsibilities`, `accountability_and_authority`, `minimum_qualification`, `created_at`, `updated_at`) VALUES
(1, 'Senior Community-Based Protection Assistant	', 'VA/BGDCO/FTA/045/2019	', 'PN 10028818\r\n', 'Cox\'s Bazar	', 'General Service, G5	', '2020-01-01', 'The Senior Community-Based Protection Assistant is a member of theProtection Unit and may report to the Protection Officer, Community-Based ProtectionOfficer, or another more senior staff member in the Protection Unit. Under theoverall direction of the Protection Unit, and in coordination with other UNHCRstaff, government, NGO partners and other stakeholders, the Senior Community-BasedProtection Assistant works directly with communities of concern to identify therisks they face and to leverage their capacities to protect themselves, theirfamilies and communities. The incumbent supports the application ofcommunity-based protection standards, operational procedures and practices incommunity-based protection delivery at the field level. To fulfil this role,the Senior Community-Based Protection Assistant is required to spend asubstantial percentage of the workday outside the office, building andmaintaining networks within communities of persons of concern (PoC). Thedevelopment and maintenance of constructive relationships with PoC thatmeasurably impact and enhance protection planning, programming and results,form the core of the work of the incumbent. S/he also supports the designing ofa community-based protection strategy by ensuring that it is based onconsultation with PoC.\r\n\r\n \r\n\r\nPrevious work experience with refugees or other vulnerable group and knowledgeof Chittagonian, Burmese, or Rohingya language will be an advantage.\r\n\r\n \r\n\r\nAll UNHCR staff members are accountable to performtheir duties as reflected in their job description. They do so within theirdelegated authorities, in line with the regulatory framework of UNHCR whichincludes the UN Charter, UN Staff Regulations and Rules, UNHCR Policiesand Administrative Instructions as well as relevant accountability frameworks.In addition, staff members are required to discharge their responsibilities ina manner consistent with the core, functional, cross-functional and managerialcompetencies and UNHCR�s core values of professionalism, integrity and respectfor diversity.', '-       Assist functional units, the Multi-Functional Team(MFT) and senior management to integrate participatory and community-basedapproaches in the overall protection strategy. \r\n\r\n-       Through relationships with PoC and network ofpartners, stay abreast of political, social, economic and cultural developmentsthat have an impact on the protection environment and provide advice to theprotection team. Understand the perspectives, capacities, needs and resourcesof the PoC and advise the protection team accordingly, highlighting thespecific protection needs of women and men, children, youth and older persons,persons with disabilities, marginalized groups.\r\n\r\n-       Assist in initiatives with host communities toinvolve national civil society groups in the protection of PoC.\r\n\r\n-       Support implementing and operational partners aswell as displaced and local communities to develop community-owned activitiesto address, where applicable, the social, educational, psycho-social, cultural,health, organisational and livelihood concerns as well as child protection andprevention and response to SGBV.\r\n\r\n-       Assist in the analysis that identifies thecapacities of communities of concern and risks they face.\r\n\r\n-       Support participatory assessments bymultifunctional teams and ongoing consultation with PoC.\r\n\r\n-       Support efforts to build the office capacity forcommunity-based protection.\r\n\r\n-       Support communities in establishing representationand coordination structures.\r\n\r\n-       Ensure community understanding of UNHCR\'scommitment to deliver on accountability and quality assurance in its response.\r\n\r\n-       Collect data for monitoring of programmesand budgets from an AGD perspective.\r\n\r\n-       Draft and type routine correspondence,documents and reports and maintain up-to-date filing systems.\r\n\r\n-       Act as an interpreter in exchange ofroutine information, contribute to related liaison activities and responddirectly to routine queries.\r\n\r\n-       Assist in the enforcement of participatory AGDsensitive analysis as an essential basis for all of UNHCR�s work.\r\n\r\n-       Initiate AGD sensitive interventions at theappropriate level on community-based protection issues and to respond toprotection concerns and incidents within the office and with persons andcommunities of concern based on agreed parameters.\r\n\r\n-       Identify and recommend which individuals or groupsto prioritize for counselling and field visits based on agreed criteria.\r\n\r\n-       Enforce compliance of implementing partners withglobal protection policies and standards of professional integrity in thedelivery of protection services.\r\n\r\n-       Perform other related duties as required.', 'Functional Skills\r\n\r\n \r\n\r\n-       *IT-MS OfficeApplications\r\n\r\n-       *IT-ComputerLiteracy\r\n\r\n-       IT-EnterpriseResource Planning (ERP)\r\n\r\n-       UN-UN/UNHCR AdministrativeRules, Regulations and Procedures\r\n\r\n-       UN-UN/UNHCRFinancial Rules and Regulations and Procedures\r\n\r\n-       PR-Community-basedProtection\r\n\r\n-       PR-Community-basedProtection - Principles and methodologies\r\n\r\n-       CL-Multi-stakeholderCommunications with Partners, Government & Community\r\n\r\n \r\n\r\n        (FunctionalSkills marked with an asterisk* are essential)\r\n\r\n \r\n\r\nLanguage Requirements\r\n\r\n \r\n\r\n-       For GeneralService jobs: Knowledge of English and/or UN working language of the dutystation if not English.\r\n\r\n \r\nCompetency requirements:\r\n\r\n \r\n\r\nCore Competencies:\r\n\r\n-       Accountability\r\n\r\n-       Communication\r\n\r\n-\r\n\r\n ', 'Education & Professional Work Experience\r\n\r\n \r\n\r\nYears of Experience / Degree Level\r\n\r\n \r\n\r\n-        For G5 - 5 years relevant experience with High school diploma\r\n\r\n \r\n\r\nCertificates and/or Licenses\r\n\r\n \r\n\r\n-        International Development,                            Cultural Studies,                                 Human Rights,\r\n\r\n-        International Social Work,                             Social Science,                                   Political Science,\r\n\r\n-        Anthropology,                                                 International Law\r\n\r\n \r\n\r\nRelevant Job Experience\r\n\r\n \r\n\r\nDesirable\r\n\r\n \r\n\r\n-        UNHCR learning programmes (PLP).\r\n\r\n-        Knowledge of MSRP.', NULL, NULL),
(2, 'Assc Supply Officer\r\n', 'VA/BGDCO/FTA/045/2019', 'Postition', 'Cox\'s Bazar', 'General Service, G8', '2020-03-20', 'Supply Officer', 'responsibilities', 'accountability_and_authority', 'responsibilities', '2019-12-21', '2019-12-21'),
(3, 'Senior External Relations Officer', '', 'P4/234dds', 'Dhaka', 'P4', '0000-00-00', 'Accountability\n• UNHCR country Office provides necessary inputs (proposals, reports, etc.) for fund-raising purposes.\n• UNHCR Country Office has a communications strategy that generates support for UNHCR\'s operations from external partners.\n• External partners are informed regularly on all aspects of the protection and well-being of persons of concern and the status of UNHCR operations.\n• Missions from Headquarters, donors, the press and media are well received and briefed.', 'Accountability\n• UNHCR country Office provides necessary inputs (proposals, reports, etc.) for fund-raising purposes.\n• UNHCR Country Office has a communications strategy that generates support for UNHCR\'s operations from external partners.\n• External partners are informed regularly on all aspects of the protection and well-being of persons of concern and the status of UNHCR operations.\n• Missions from Headquarters, donors, the press and media are well received and briefed.', 'Accountability\n• UNHCR country Office provides necessary inputs (proposals, reports, etc.) for fund-raising purposes.\n• UNHCR Country Office has a communications strategy that generates support for UNHCR\'s operations from external partners.\n• External partners are informed regularly on all aspects of the protection and well-being of persons of concern and the status of UNHCR operations.\n• Missions from Headquarters, donors, the press and media are well received and briefed.', 'Accountability\n• UNHCR country Office provides necessary inputs (proposals, reports, etc.) for fund-raising purposes.\n• UNHCR Country Office has a communications strategy that generates support for UNHCR\'s operations from external partners.\n• External partners are informed regularly on all aspects of the protection and well-being of persons of concern and the status of UNHCR operations.\n• Missions from Headquarters, donors, the press and media are well received and briefed.', '2019-12-24', '2019-12-24');

-- --------------------------------------------------------

--
-- Table structure for table `migrations`
--

CREATE TABLE `migrations` (
  `id` int(10) UNSIGNED NOT NULL,
  `migration` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `migrations`
--

INSERT INTO `migrations` (`id`, `migration`, `batch`) VALUES
(1, '2019_03_25_113855_create_location_levels_table', 1),
(2, '2019_03_25_113856_create_designations_table', 1),
(3, '2019_03_25_113857_create_departments_table', 1),
(4, '2019_03_25_113858_create_location_areas_table', 1),
(5, '2019_03_25_113859_create_permissions_table', 1),
(6, '2019_03_25_113860_create_roles_table', 1),
(7, '2019_03_25_113861_create_role_permissions_table', 1),
(8, '2019_03_25_113862_create_password_resets_table', 1),
(9, '2019_03_25_113863_create_users_table', 1),
(10, '2019_03_25_113866_create_meetings_table', 1),
(11, '2020_03_25_113867_create_clients_table', 1),
(12, '2022_03_25_113864_create_sales_table', 1),
(13, '2023_03_25_184088_create_collections_table', 1),
(14, '2023_03_25_184089_create_meeting_participants_table', 2),
(15, '2023_03_25_184090_create_user_attendances_table', 3),
(16, '2023_03_25_184091_create_calendar_holidays_table', 3),
(17, '2019_03_12_050029_add_location_area_to_sales', 4),
(18, '2019_03_13_041801_create_targets_table', 5),
(19, '2020_03_25_113857_create_depots_table', 6),
(20, '2019_03_30_141620_add_depot_to_users', 7);

-- --------------------------------------------------------

--
-- Table structure for table `password_resets`
--

CREATE TABLE `password_resets` (
  `email` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `permissions`
--

CREATE TABLE `permissions` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `parent_id` int(11) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `permissions`
--

INSERT INTO `permissions` (`id`, `name`, `parent_id`, `created_at`, `updated_at`) VALUES
(1, 'RoleController', NULL, NULL, NULL),
(2, 'index', 1, NULL, NULL),
(3, 'create', 1, NULL, NULL),
(4, 'store', 1, NULL, NULL),
(5, 'show', 1, NULL, NULL),
(6, 'edit', 1, NULL, NULL),
(7, 'update', 1, NULL, NULL),
(8, 'destroy', 1, NULL, NULL),
(9, 'AdminController', NULL, NULL, NULL),
(10, 'index', 9, NULL, NULL),
(11, 'create', 9, NULL, NULL),
(12, 'store', 9, NULL, NULL),
(13, 'edit', 9, NULL, NULL),
(14, 'update', 9, NULL, NULL),
(15, 'destroy', 9, NULL, NULL),
(16, 'LocationAreaController', NULL, NULL, NULL),
(17, 'index', 16, NULL, NULL),
(18, 'store', 16, NULL, NULL),
(19, 'show', 16, NULL, NULL),
(20, 'update', 16, NULL, NULL),
(21, 'destroy', 16, NULL, NULL),
(22, 'levelDD', 16, NULL, NULL),
(23, 'getlevel', 16, NULL, NULL),
(24, 'getlocation_self', 16, NULL, NULL),
(25, 'getlocation', 16, NULL, NULL),
(26, 'getLevelwiseLocation', 16, NULL, NULL),
(27, 'getlocationWithLevel', 16, NULL, NULL),
(28, 'getLocationParents', 16, NULL, NULL),
(29, 'DepartmentController', NULL, NULL, NULL),
(30, 'index', 29, NULL, NULL),
(31, 'store', 29, NULL, NULL),
(32, 'show', 29, NULL, NULL),
(33, 'update', 29, NULL, NULL),
(34, 'destroy', 29, NULL, NULL),
(35, 'DesignationController', NULL, NULL, NULL),
(36, 'index', 35, NULL, NULL),
(37, 'store', 35, NULL, NULL),
(38, 'show', 35, NULL, NULL),
(39, 'update', 35, NULL, NULL),
(40, 'destroy', 35, NULL, NULL),
(41, 'MeetingController', NULL, NULL, NULL),
(42, 'index', 41, NULL, NULL),
(43, 'store', 41, NULL, NULL),
(44, 'show', 41, NULL, NULL),
(45, 'update', 41, NULL, NULL),
(46, 'destroy', 41, NULL, NULL),
(47, 'ClientController', NULL, NULL, NULL),
(48, 'index', 47, NULL, NULL),
(49, 'store', 47, NULL, NULL),
(50, 'show', 47, NULL, NULL),
(51, 'update', 47, NULL, NULL),
(52, 'destroy', 47, NULL, NULL),
(53, 'SaleController', NULL, NULL, NULL),
(54, 'index', 53, NULL, NULL),
(55, 'store', 53, NULL, NULL),
(56, 'show', 53, NULL, NULL),
(57, 'update', 53, NULL, NULL),
(58, 'destroy', 53, NULL, NULL),
(59, 'CalendarHolidayController', NULL, NULL, NULL),
(60, 'index', 59, NULL, NULL),
(61, 'store', 59, NULL, NULL),
(62, 'update', 59, NULL, NULL),
(63, 'UserAttendanceController', NULL, NULL, NULL),
(64, 'checkin', 63, NULL, NULL),
(65, 'checkout', 63, NULL, NULL),
(66, 'history', 63, NULL, NULL),
(67, 'locationSync', 63, NULL, NULL),
(68, 'attendanceSummery', 63, NULL, NULL),
(69, 'monthlyAttendaceDetails', 63, NULL, NULL),
(70, 'dailyActivityMonitor', 63, NULL, NULL),
(71, 'TargetController', NULL, NULL, NULL),
(72, 'index', 71, NULL, NULL),
(73, 'create', 71, NULL, NULL),
(74, 'store', 71, NULL, NULL),
(75, 'show', 71, NULL, NULL),
(76, 'edit', 71, NULL, NULL),
(77, 'update', 71, NULL, NULL),
(78, 'destroy', 71, NULL, NULL),
(79, 'singleClientSales', 53, NULL, NULL),
(80, 'test', 53, NULL, NULL),
(81, 'addCollection', 53, NULL, NULL),
(82, 'getMonthListforUserTarget', 71, NULL, NULL),
(83, 'userTarget', 71, NULL, NULL),
(84, 'ReportingController', NULL, NULL, NULL),
(85, 'MIO_activity', 84, NULL, NULL),
(86, 'getAllSales', 84, NULL, NULL),
(87, 'getAllCollections', 84, NULL, NULL),
(88, 'aMWiseSales', 84, NULL, NULL),
(89, 'aMWiseCollections', 84, NULL, NULL),
(90, 'DepotController', NULL, NULL, NULL),
(91, 'index', 90, NULL, NULL),
(92, 'store', 90, NULL, NULL),
(93, 'show', 90, NULL, NULL),
(94, 'update', 90, NULL, NULL),
(95, 'destroy', 90, NULL, NULL),
(96, 'userSuggestion', 41, NULL, NULL),
(97, 'meetingList', 41, NULL, NULL),
(98, 'selfTarget', 71, NULL, NULL),
(99, 'getlocationWithLevel_self', 16, NULL, NULL),
(100, 'ReferenceController', NULL, NULL, NULL),
(101, 'index', 100, NULL, NULL),
(102, 'store', 100, NULL, NULL),
(103, 'show', 100, NULL, NULL),
(104, 'update', 100, NULL, NULL),
(105, 'destroy', 100, NULL, NULL),
(106, 'EducationController', NULL, NULL, NULL),
(107, 'index', 106, NULL, NULL),
(108, 'store', 106, NULL, NULL),
(109, 'show', 106, NULL, NULL),
(110, 'update', 106, NULL, NULL),
(111, 'destroy', 106, NULL, NULL),
(112, 'WorkExperienceController', NULL, NULL, NULL),
(113, 'index', 112, NULL, NULL),
(114, 'store', 112, NULL, NULL),
(115, 'show', 112, NULL, NULL),
(116, 'update', 112, NULL, NULL),
(117, 'destroy', 112, NULL, NULL),
(118, 'JobseekerPersonalInfoController', NULL, NULL, NULL),
(119, 'login', 118, NULL, NULL),
(120, 'logout', 118, NULL, NULL),
(121, 'index', 118, NULL, NULL),
(122, 'store', 118, NULL, NULL),
(123, 'show', 118, NULL, NULL),
(124, 'update', 118, NULL, NULL),
(125, 'destroy', 118, NULL, NULL),
(126, 'SpecialTrainingController', NULL, NULL, NULL),
(127, 'index', 126, NULL, NULL),
(128, 'store', 126, NULL, NULL),
(129, 'show', 126, NULL, NULL),
(130, 'update', 126, NULL, NULL),
(131, 'destroy', 126, NULL, NULL),
(132, 'JobAppliedController', NULL, NULL, NULL),
(133, 'index', 132, NULL, NULL),
(134, 'store', 132, NULL, NULL),
(135, 'show', 132, NULL, NULL),
(136, 'update', 132, NULL, NULL),
(137, 'destroy', 132, NULL, NULL),
(138, 'JobPostController', NULL, NULL, NULL),
(139, 'index', 138, NULL, NULL),
(140, 'store', 138, NULL, NULL),
(141, 'show', 138, NULL, NULL),
(142, 'update', 138, NULL, NULL),
(143, 'destroy', 138, NULL, NULL),
(144, 'JobDetail', NULL, NULL, NULL),
(145, 'index', 144, NULL, NULL),
(146, 'show', 144, NULL, NULL),
(147, 'fileupload', 118, NULL, NULL),
(148, 'photoFileupload', 118, NULL, NULL),
(149, 'singleJobAllCv', 138, NULL, NULL),
(150, 'shortListUser', 138, NULL, NULL),
(151, 'singleJobShortlistedCv', 138, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `roles`
--

CREATE TABLE `roles` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(400) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `is_deletable` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `roles`
--

INSERT INTO `roles` (`id`, `name`, `description`, `status`, `is_deletable`, `created_at`, `updated_at`) VALUES
(1, 'Super Admin', 'Level1', 1, 0, '2019-03-10 20:48:04', NULL),
(2, 'Level5', 'Level5', 1, 1, '2019-03-20 00:00:59', '2019-03-20 00:00:59'),
(3, 'Level4\r\n', 'Level4', 1, 1, '2019-03-20 01:11:38', '2019-03-20 01:11:38'),
(4, 'Level3', 'Level3', 1, 1, '2019-03-31 00:16:43', '2019-03-31 00:16:43'),
(5, 'Level2', 'Level2', 1, 1, '2019-03-31 00:17:14', '2019-03-31 00:17:14');

-- --------------------------------------------------------

--
-- Table structure for table `role_permissions`
--

CREATE TABLE `role_permissions` (
  `role_id` int(10) UNSIGNED NOT NULL,
  `permission_id` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `role_permissions`
--

INSERT INTO `role_permissions` (`role_id`, `permission_id`, `created_at`, `updated_at`) VALUES
(1, 1, NULL, NULL),
(1, 2, NULL, NULL),
(1, 3, NULL, NULL),
(1, 4, NULL, NULL),
(1, 5, NULL, NULL),
(1, 6, NULL, NULL),
(1, 7, NULL, NULL),
(1, 8, NULL, NULL),
(1, 9, NULL, NULL),
(1, 10, NULL, NULL),
(1, 11, NULL, NULL),
(1, 12, NULL, NULL),
(1, 13, NULL, NULL),
(1, 14, NULL, NULL),
(1, 15, NULL, NULL),
(1, 16, NULL, NULL),
(1, 17, NULL, NULL),
(1, 18, NULL, NULL),
(1, 19, NULL, NULL),
(1, 20, NULL, NULL),
(1, 21, NULL, NULL),
(1, 22, NULL, NULL),
(1, 23, NULL, NULL),
(1, 24, NULL, NULL),
(1, 25, NULL, NULL),
(1, 26, NULL, NULL),
(1, 27, NULL, NULL),
(1, 28, NULL, NULL),
(1, 29, NULL, NULL),
(1, 30, NULL, NULL),
(1, 31, NULL, NULL),
(1, 32, NULL, NULL),
(1, 33, NULL, NULL),
(1, 34, NULL, NULL),
(1, 35, NULL, NULL),
(1, 36, NULL, NULL),
(1, 37, NULL, NULL),
(1, 38, NULL, NULL),
(1, 39, NULL, NULL),
(1, 40, NULL, NULL),
(1, 41, NULL, NULL),
(1, 42, NULL, NULL),
(1, 43, NULL, NULL),
(1, 44, NULL, NULL),
(1, 45, NULL, NULL),
(1, 46, NULL, NULL),
(1, 47, NULL, NULL),
(1, 48, NULL, NULL),
(1, 49, NULL, NULL),
(1, 50, NULL, NULL),
(1, 51, NULL, NULL),
(1, 52, NULL, NULL),
(1, 53, NULL, NULL),
(1, 54, NULL, NULL),
(1, 56, NULL, NULL),
(1, 58, NULL, NULL),
(1, 59, NULL, NULL),
(1, 60, NULL, NULL),
(1, 61, NULL, NULL),
(1, 62, NULL, NULL),
(1, 63, NULL, NULL),
(1, 64, NULL, NULL),
(1, 65, NULL, NULL),
(1, 66, NULL, NULL),
(1, 67, NULL, NULL),
(1, 68, NULL, NULL),
(1, 69, NULL, NULL),
(1, 70, NULL, NULL),
(1, 71, NULL, NULL),
(1, 72, NULL, NULL),
(1, 73, NULL, NULL),
(1, 74, NULL, NULL),
(1, 75, NULL, NULL),
(1, 76, NULL, NULL),
(1, 77, NULL, NULL),
(1, 78, NULL, NULL),
(1, 79, NULL, NULL),
(1, 82, NULL, NULL),
(1, 83, NULL, NULL),
(1, 84, NULL, NULL),
(1, 85, NULL, NULL),
(1, 86, NULL, NULL),
(1, 87, NULL, NULL),
(1, 88, NULL, NULL),
(1, 89, NULL, NULL),
(1, 90, NULL, NULL),
(1, 91, NULL, NULL),
(1, 92, NULL, NULL),
(1, 93, NULL, NULL),
(1, 94, NULL, NULL),
(1, 95, NULL, NULL),
(1, 96, NULL, NULL),
(1, 97, NULL, NULL),
(1, 98, NULL, NULL),
(1, 99, NULL, NULL),
(1, 100, NULL, NULL),
(1, 101, NULL, NULL),
(1, 102, NULL, NULL),
(1, 103, NULL, NULL),
(1, 104, NULL, NULL),
(1, 105, NULL, NULL),
(1, 106, NULL, NULL),
(1, 107, NULL, NULL),
(1, 108, NULL, NULL),
(1, 109, NULL, NULL),
(1, 110, NULL, NULL),
(1, 111, NULL, NULL),
(1, 112, NULL, NULL),
(1, 113, NULL, NULL),
(1, 114, NULL, NULL),
(1, 115, NULL, NULL),
(1, 116, NULL, NULL),
(1, 117, NULL, NULL),
(1, 118, NULL, NULL),
(1, 119, NULL, NULL),
(1, 120, NULL, NULL),
(1, 121, NULL, NULL),
(1, 122, NULL, NULL),
(1, 123, NULL, NULL),
(1, 124, NULL, NULL),
(1, 125, NULL, NULL),
(1, 126, NULL, NULL),
(1, 127, NULL, NULL),
(1, 128, NULL, NULL),
(1, 129, NULL, NULL),
(1, 130, NULL, NULL),
(1, 131, NULL, NULL),
(1, 132, NULL, NULL),
(1, 133, NULL, NULL),
(1, 134, NULL, NULL),
(1, 135, NULL, NULL),
(1, 136, NULL, NULL),
(1, 137, NULL, NULL),
(1, 138, NULL, NULL),
(1, 139, NULL, NULL),
(1, 140, NULL, NULL),
(1, 141, NULL, NULL),
(1, 142, NULL, NULL),
(1, 143, NULL, NULL),
(1, 144, NULL, NULL),
(1, 145, NULL, NULL),
(1, 146, NULL, NULL),
(1, 147, NULL, NULL),
(1, 148, NULL, NULL),
(1, 149, NULL, NULL),
(1, 150, NULL, NULL),
(1, 151, NULL, NULL),
(2, 16, NULL, NULL),
(2, 17, NULL, NULL),
(2, 19, NULL, NULL),
(2, 24, NULL, NULL),
(2, 25, NULL, NULL),
(2, 27, NULL, NULL),
(2, 28, NULL, NULL),
(2, 41, NULL, NULL),
(2, 42, NULL, NULL),
(2, 43, NULL, NULL),
(2, 44, NULL, NULL),
(2, 45, NULL, NULL),
(2, 46, NULL, NULL),
(2, 47, NULL, NULL),
(2, 48, NULL, NULL),
(2, 49, NULL, NULL),
(2, 50, NULL, NULL),
(2, 51, NULL, NULL),
(2, 52, NULL, NULL),
(2, 53, NULL, NULL),
(2, 54, NULL, NULL),
(2, 55, NULL, NULL),
(2, 56, NULL, NULL),
(2, 57, NULL, NULL),
(2, 58, NULL, NULL),
(2, 63, NULL, NULL),
(2, 64, NULL, NULL),
(2, 65, NULL, NULL),
(2, 66, NULL, NULL),
(2, 67, NULL, NULL),
(2, 68, NULL, NULL),
(2, 69, NULL, NULL),
(2, 70, NULL, NULL),
(2, 71, NULL, NULL),
(2, 72, NULL, NULL),
(2, 73, NULL, NULL),
(2, 74, NULL, NULL),
(2, 75, NULL, NULL),
(2, 76, NULL, NULL),
(2, 77, NULL, NULL),
(2, 78, NULL, NULL),
(2, 79, NULL, NULL),
(2, 80, NULL, NULL),
(2, 81, NULL, NULL),
(2, 82, NULL, NULL),
(2, 83, NULL, NULL),
(2, 84, NULL, NULL),
(2, 85, NULL, NULL),
(2, 88, NULL, NULL),
(2, 89, NULL, NULL),
(2, 96, NULL, NULL),
(2, 97, NULL, NULL),
(2, 98, NULL, NULL),
(2, 99, NULL, NULL),
(3, 16, NULL, NULL),
(3, 17, NULL, NULL),
(3, 18, NULL, NULL),
(3, 19, NULL, NULL),
(3, 20, NULL, NULL),
(3, 21, NULL, NULL),
(3, 22, NULL, NULL),
(3, 23, NULL, NULL),
(3, 24, NULL, NULL),
(3, 25, NULL, NULL),
(3, 26, NULL, NULL),
(3, 27, NULL, NULL),
(3, 28, NULL, NULL),
(3, 41, NULL, NULL),
(3, 42, NULL, NULL),
(3, 43, NULL, NULL),
(3, 44, NULL, NULL),
(3, 45, NULL, NULL),
(3, 46, NULL, NULL),
(3, 47, NULL, NULL),
(3, 48, NULL, NULL),
(3, 49, NULL, NULL),
(3, 50, NULL, NULL),
(3, 51, NULL, NULL),
(3, 52, NULL, NULL),
(3, 53, NULL, NULL),
(3, 54, NULL, NULL),
(3, 56, NULL, NULL),
(3, 58, NULL, NULL),
(3, 63, NULL, NULL),
(3, 64, NULL, NULL),
(3, 65, NULL, NULL),
(3, 66, NULL, NULL),
(3, 67, NULL, NULL),
(3, 68, NULL, NULL),
(3, 69, NULL, NULL),
(3, 70, NULL, NULL),
(3, 71, NULL, NULL),
(3, 72, NULL, NULL),
(3, 73, NULL, NULL),
(3, 74, NULL, NULL),
(3, 75, NULL, NULL),
(3, 76, NULL, NULL),
(3, 77, NULL, NULL),
(3, 78, NULL, NULL),
(3, 79, NULL, NULL),
(3, 80, NULL, NULL),
(3, 82, NULL, NULL),
(3, 83, NULL, NULL),
(3, 84, NULL, NULL),
(3, 85, NULL, NULL),
(3, 88, NULL, NULL),
(3, 89, NULL, NULL),
(3, 96, NULL, NULL),
(3, 97, NULL, NULL),
(3, 98, NULL, NULL),
(3, 99, NULL, NULL),
(4, 16, NULL, NULL),
(4, 17, NULL, NULL),
(4, 18, NULL, NULL),
(4, 19, NULL, NULL),
(4, 20, NULL, NULL),
(4, 21, NULL, NULL),
(4, 22, NULL, NULL),
(4, 23, NULL, NULL),
(4, 24, NULL, NULL),
(4, 25, NULL, NULL),
(4, 26, NULL, NULL),
(4, 27, NULL, NULL),
(4, 28, NULL, NULL),
(4, 29, NULL, NULL),
(4, 30, NULL, NULL),
(4, 31, NULL, NULL),
(4, 32, NULL, NULL),
(4, 33, NULL, NULL),
(4, 34, NULL, NULL),
(4, 35, NULL, NULL),
(4, 36, NULL, NULL),
(4, 37, NULL, NULL),
(4, 38, NULL, NULL),
(4, 39, NULL, NULL),
(4, 40, NULL, NULL),
(4, 41, NULL, NULL),
(4, 42, NULL, NULL),
(4, 43, NULL, NULL),
(4, 44, NULL, NULL),
(4, 45, NULL, NULL),
(4, 46, NULL, NULL),
(4, 47, NULL, NULL),
(4, 48, NULL, NULL),
(4, 49, NULL, NULL),
(4, 50, NULL, NULL),
(4, 51, NULL, NULL),
(4, 52, NULL, NULL),
(4, 53, NULL, NULL),
(4, 54, NULL, NULL),
(4, 55, NULL, NULL),
(4, 56, NULL, NULL),
(4, 57, NULL, NULL),
(4, 58, NULL, NULL),
(4, 63, NULL, NULL),
(4, 64, NULL, NULL),
(4, 65, NULL, NULL),
(4, 66, NULL, NULL),
(4, 67, NULL, NULL),
(4, 68, NULL, NULL),
(4, 69, NULL, NULL),
(4, 70, NULL, NULL),
(4, 71, NULL, NULL),
(4, 72, NULL, NULL),
(4, 73, NULL, NULL),
(4, 74, NULL, NULL),
(4, 75, NULL, NULL),
(4, 76, NULL, NULL),
(4, 77, NULL, NULL),
(4, 78, NULL, NULL),
(4, 79, NULL, NULL),
(4, 80, NULL, NULL),
(4, 81, NULL, NULL),
(4, 82, NULL, NULL),
(4, 83, NULL, NULL),
(4, 84, NULL, NULL),
(4, 85, NULL, NULL),
(4, 88, NULL, NULL),
(4, 89, NULL, NULL),
(4, 96, NULL, NULL),
(4, 97, NULL, NULL),
(4, 98, NULL, NULL),
(4, 99, NULL, NULL),
(5, 100, NULL, NULL),
(5, 101, NULL, NULL),
(5, 102, NULL, NULL),
(5, 103, NULL, NULL),
(5, 104, NULL, NULL),
(5, 105, NULL, NULL),
(5, 106, NULL, NULL),
(5, 107, NULL, NULL),
(5, 108, NULL, NULL),
(5, 109, NULL, NULL),
(5, 110, NULL, NULL),
(5, 111, NULL, NULL),
(5, 112, NULL, NULL),
(5, 113, NULL, NULL),
(5, 114, NULL, NULL),
(5, 115, NULL, NULL),
(5, 116, NULL, NULL),
(5, 117, NULL, NULL),
(5, 118, NULL, NULL),
(5, 119, NULL, NULL),
(5, 120, NULL, NULL),
(5, 121, NULL, NULL),
(5, 122, NULL, NULL),
(5, 123, NULL, NULL),
(5, 124, NULL, NULL),
(5, 125, NULL, NULL),
(5, 126, NULL, NULL),
(5, 127, NULL, NULL),
(5, 128, NULL, NULL),
(5, 129, NULL, NULL),
(5, 130, NULL, NULL),
(5, 131, NULL, NULL),
(5, 132, NULL, NULL),
(5, 133, NULL, NULL),
(5, 134, NULL, NULL),
(5, 135, NULL, NULL),
(5, 136, NULL, NULL),
(5, 137, NULL, NULL),
(5, 144, NULL, NULL),
(5, 145, NULL, NULL),
(5, 146, NULL, NULL),
(5, 147, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `special_trainings`
--

CREATE TABLE `special_trainings` (
  `id` int(11) NOT NULL,
  `jobseeker_id` int(11) NOT NULL,
  `course_title` varchar(500) NOT NULL,
  `school_name` varchar(500) NOT NULL,
  `country` varchar(50) DEFAULT NULL,
  `course_start_date` date NOT NULL,
  `course_end_date` date DEFAULT NULL,
  `topic_area` varchar(500) DEFAULT NULL,
  `training_methodology` varchar(500) DEFAULT NULL,
  `course_description` text DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `special_trainings`
--

INSERT INTO `special_trainings` (`id`, `jobseeker_id`, `course_title`, `school_name`, `country`, `course_start_date`, `course_end_date`, `topic_area`, `training_methodology`, `course_description`, `created_at`, `updated_at`) VALUES
(1, 1, 'LINUX Sys ADMIN ', 'BDNOG', '0', '2016-10-01', '2016-10-03', 'ddd uServer management, Server Security,Mailing.p', '1', '•	Networking Fundamentals •	Introduction to Linux •	Scripting Basics\r\n•	Security Essentials SSH •	DNS & DNSSEC •	Database with MariaDB\r\n•	Web Service with Apache •	Concept of Mail Protocols / Postfix\r\n•	PGP and Email Security •	Courier IMAP/Dovecot Labs •	Roundcube Lab\r\n•	SNMP •	Network Monitoring with LibreNMS\r\n', '2019-12-25 20:01:50', '2019-12-25 20:01:50'),
(2, 1, 'Advance Python 3 Programming', 'BITM And LEADS Training & Consulting Ltd. jointly Organize this Training.', '1', '2018-02-11', '2019-10-09', 'Python 3, Django web framework', '2', 'Basic Python Syntax , Language Components, Collections, Functions, Modules, Input and Output, implementing Classes and Objects…. OOP, Exceptions, Django ', '2019-12-26 00:00:00', NULL),
(3, 1, 'tu', 'tu', 'null', '2020-01-05', '2020-01-24', 'tu', '7', 'desu', '2020-01-01 08:41:46', '2020-01-01 08:41:46');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role_id` int(10) UNSIGNED NOT NULL,
  `mobile_no` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `photo` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `designation_id` int(10) UNSIGNED NOT NULL,
  `department_id` int(10) UNSIGNED DEFAULT NULL,
  `gender` tinyint(4) NOT NULL DEFAULT 0,
  `location_area_id` int(10) UNSIGNED NOT NULL,
  `national_identification_num` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `carry_leaves` int(11) NOT NULL DEFAULT 0,
  `join_date` date DEFAULT NULL,
  `supervisor_id` int(10) UNSIGNED DEFAULT NULL,
  `remember_token` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` varchar(600) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` tinyint(4) DEFAULT NULL,
  `online` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `socket_id` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_supervisor` tinyint(4) NOT NULL DEFAULT 0,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `depot_id` int(10) UNSIGNED DEFAULT NULL,
  `first_name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `middle_name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `maiden_name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `nationalities_at_birth` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `current_nationalities` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_of_b` date NOT NULL,
  `marital_status` tinyint(4) DEFAULT NULL COMMENT '1=Married,   2=Single, 3=Divorced, 4=Common Law ,5=Registered Partnership, 6=Separated, 7=Widowed  ',
  `permanent_residency` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `preferred_contact_method` tinyint(4) NOT NULL COMMENT '0=mobile,1= email',
  `p11form` varchar(2000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `coverLetter` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `email`, `password`, `role_id`, `mobile_no`, `photo`, `designation_id`, `department_id`, `gender`, `location_area_id`, `national_identification_num`, `carry_leaves`, `join_date`, `supervisor_id`, `remember_token`, `description`, `address`, `status`, `online`, `socket_id`, `is_supervisor`, `deleted_at`, `created_at`, `updated_at`, `depot_id`, `first_name`, `middle_name`, `last_name`, `maiden_name`, `nationalities_at_birth`, `current_nationalities`, `date_of_b`, `marital_status`, `permanent_residency`, `preferred_contact_method`, `p11form`, `coverLetter`) VALUES
(1, 'admin', 'ehasanshakib@gmail.com', '$2y$12$K9O3njIKNB693/IgJmXkMeNL0ZrBNRNNd2dpgZ5ylnxubSwKMen.G', 1, '01753414714', '/img/user/amimul_ehsan_shakib_300_300.jpg', 1, 3, 0, 1, '455', 0, '1997-01-10', 1, NULL, 'description', 'null', 1, NULL, NULL, 1, NULL, '2019-03-10 20:48:04', '2019-12-26 09:00:06', 2, 'Md. Amimul', 'Ehasan', 'Shakib', '', 'Bangladesh', 'Bangladesh', '2019-12-25', 1, 'Bangladesh', 0, '/img/user/Profle_photo_1577348796.pdf', '/img/user/Cover_letter_1577350806.pdf'),
(2, 'applicant', 'applicant@unhcr.org', '$2y$12$uWvYQAyUmBwq1LhTHbB1.uhKXr4N5auerGCBuJu2Br0hlzs6phG5a', 5, '01753414711', '/img/user/Profle_photo_1554024540.jpeg', 2, 3, 1, 6, '11111111111111112', 0, '2015-01-15', 1, NULL, 'descr1', 'address1', 1, NULL, NULL, 1, NULL, '2019-03-10 20:48:04', '2019-03-31 07:56:31', 1, '', '', '', '', '', '', '0000-00-00', 1, '', 0, NULL, NULL),
(3, 'rony', 'rony@unhcr.org', '$2y$10$QnJw.HnGJPO80QboIjo2NeiE3uqBkDinudOk5w7FSKHjZKjaMkezu', 5, NULL, NULL, 0, NULL, 1, 0, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, '2020-01-05 14:54:40', '2020-01-05 14:54:40', NULL, '', '', '', '', '', '', '2020-01-08', NULL, '', 0, NULL, NULL),
(4, 'one', 'one@gmail.com', '$2y$10$63A3ebSRSU.2Wxz4ExjAQuQQpxAJGwuzKiT/FehP5aJx1HEARyK66', 5, '01825687473', NULL, 0, NULL, 1, 0, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, '2020-01-14 07:37:56', '2020-01-15 18:27:17', NULL, 'Md. Amimul', 'Ehasan', 'Shakib', '', 'Bangladeshi', '', '0000-00-00', 2, '', 0, '/img/user/Profle_photo_1579112837.PNG', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `usersd`
--

CREATE TABLE `usersd` (
  `id` int(11) NOT NULL,
  `name` varchar(200) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `work_experiences`
--

CREATE TABLE `work_experiences` (
  `id` int(11) NOT NULL,
  `jobseeker_id` int(11) NOT NULL,
  `employer_name` varchar(200) NOT NULL,
  `job_title` varchar(500) NOT NULL,
  `description_of_duties` text DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `country_name` varchar(100) DEFAULT NULL,
  `type_of_business` tinyint(4) DEFAULT NULL,
  `un_experience` tinyint(4) DEFAULT NULL,
  `unhcr_experience` tinyint(4) DEFAULT NULL,
  `contract_type` tinyint(4) DEFAULT NULL,
  `un_unhcr_grade` varchar(20) DEFAULT NULL,
  `msrp_id` varchar(20) DEFAULT NULL,
  `index_id` varchar(20) DEFAULT NULL,
  `duration` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `work_experiences`
--

INSERT INTO `work_experiences` (`id`, `jobseeker_id`, `employer_name`, `job_title`, `description_of_duties`, `created_at`, `updated_at`, `start_date`, `end_date`, `country_name`, `type_of_business`, `un_experience`, `unhcr_experience`, `contract_type`, `un_unhcr_grade`, `msrp_id`, `index_id`, `duration`) VALUES
(1, 1, 'UNHCR, Coxsbazar', 'Data Management Assistant', '-support the availability of PRIMES Application( proGres v3, BIMS and the Global Distribution Tool (GDT)), Reporter Tool to registration sites along with training staff on these technologies.\r\n-SQL server and Database setup,update,backup and SQL language.\r\n- following up error by user in camp, Quality Check, and data curation.\r\n- Camp/Sites/Team management.', '2019-11-29 21:44:03', '2020-01-01 08:15:33', '2019-12-02', '2019-12-30', 'Bangladesh', 1, 1, 0, 1, 'G4', 'null', 'null', 20),
(2, 1, 'OneICT Ltd.', 'Web Developer', '-support the availability of PRIMES Application( proGres v3, BIMS and the Global Distribution Tool (GDT)), Reporter Tool to registration sites along with training staff on these technologies. -SQL server and Database setup,update,backup and SQL language. - following up error by user in camp, Quality Check, and data curation. - Camp/Sites/Team management.', '2019-11-29 21:44:36', '2019-11-29 21:44:36', '2019-10-01', '2019-11-15', 'Bangladesh', 3, 1, 0, 2, 'G4', NULL, NULL, 30);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `departments`
--
ALTER TABLE `departments`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `designations`
--
ALTER TABLE `designations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `educations`
--
ALTER TABLE `educations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `jobseeker_personal_infos`
--
ALTER TABLE `jobseeker_personal_infos`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `jobseeker_references`
--
ALTER TABLE `jobseeker_references`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `job_applieds`
--
ALTER TABLE `job_applieds`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `job_posts`
--
ALTER TABLE `job_posts`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `migrations`
--
ALTER TABLE `migrations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `password_resets`
--
ALTER TABLE `password_resets`
  ADD KEY `password_resets_email_index` (`email`);

--
-- Indexes for table `permissions`
--
ALTER TABLE `permissions`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `roles_name_unique` (`name`);

--
-- Indexes for table `role_permissions`
--
ALTER TABLE `role_permissions`
  ADD PRIMARY KEY (`role_id`,`permission_id`),
  ADD KEY `role_permissions_permission_id_foreign` (`permission_id`);

--
-- Indexes for table `special_trainings`
--
ALTER TABLE `special_trainings`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `users_email_unique` (`email`),
  ADD KEY `users_role_id_foreign` (`role_id`);

--
-- Indexes for table `usersd`
--
ALTER TABLE `usersd`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `work_experiences`
--
ALTER TABLE `work_experiences`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `departments`
--
ALTER TABLE `departments`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `designations`
--
ALTER TABLE `designations`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `educations`
--
ALTER TABLE `educations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `jobseeker_personal_infos`
--
ALTER TABLE `jobseeker_personal_infos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `jobseeker_references`
--
ALTER TABLE `jobseeker_references`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `job_applieds`
--
ALTER TABLE `job_applieds`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `job_posts`
--
ALTER TABLE `job_posts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `migrations`
--
ALTER TABLE `migrations`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `permissions`
--
ALTER TABLE `permissions`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=152;

--
-- AUTO_INCREMENT for table `roles`
--
ALTER TABLE `roles`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `special_trainings`
--
ALTER TABLE `special_trainings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `usersd`
--
ALTER TABLE `usersd`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `work_experiences`
--
ALTER TABLE `work_experiences`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `role_permissions`
--
ALTER TABLE `role_permissions`
  ADD CONSTRAINT `role_permissions_permission_id_foreign` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `role_permissions_role_id_foreign` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `users_role_id_foreign` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
