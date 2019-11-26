-- phpMyAdmin SQL Dump
-- version 4.9.0.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Nov 26, 2019 at 04:50 AM
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
-- Database: `opl`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `GetMonthlyLeaves` (IN `month_year` DATE, IN `userId` INT)  NO SQL
BEGIN
	DECLARE last_date DATE DEFAULT LAST_DAY(month_year);

    SELECT from_date, to_date, name FROM leave_applications 
    JOIN leaves on leaves.id = leave_applications.leave_id
        WHERE user_id = userId AND is_approved = 1 AND
        ((month_year BETWEEN from_date AND to_date) OR 
         (last_date BETWEEN from_date AND to_date) OR 
         (from_date >= month_year AND to_date <= last_date));
    
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `initiateMessengerGroup` ()  NO SQL
BEGIN
	INSERT INTO messenger_groups (name, location_area_id)
    SELECT name, id FROM location_areas la WHERE NOT EXISTS(SELECT * FROM messenger_groups WHERE location_area_id = la.id);
    DELETE FROM `messenger_groups` WHERE location_area_id NOT IN(SELECT id FROM location_areas);

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `MonthlyAttendanceList` (IN `month_year` DATE, IN `userId` INT)  MODIFIES SQL DATA
BEGIN

	DECLARE i DATE DEFAULT month_year;
    DECLARE n int DEFAULT DAY(LAST_DAY(month_year));
    DECLARE last_date DATE DEFAULT CASE WHEN LAST_DAY(month_year) > CURDATE() THEN CURDATE() ELSE LAST_DAY(month_year) END;
    #DECLARE last_date DATE DEFAULT CURDATE();
        

	CREATE TEMPORARY TABLE IF NOT EXISTS temp_table (
      day DATE DEFAULT NULL,
      check_in TIME DEFAULT NULL,
      check_out TIME DEFAULT NULL,
      holiday TEXT DEFAULT NULL,
      leaves TEXT DEFAULT NULL
    );
    
    WHILE i <= last_date DO
    
        INSERT INTO temp_table(day, leaves) VALUES(i,
                                   (SELECT name FROM leave_applications 
                                    JOIN leaves on leaves.id = leave_applications.leave_id
                                    WHERE user_id = userId AND is_approved = 1 AND i BETWEEN from_date AND to_date)); 
        
    SET i = DATE_ADD(i, INTERVAL 1 DAY);
  	END WHILE;
    
    UPDATE temp_table 
    JOIN user_attendances ua ON temp_table.day = ua.date AND ua.user_id = userId
    SET temp_table.check_in = ua.cin_time,
    temp_table.check_out = ua.cout_time
    WHERE YEAR(ua.date) = YEAR(month_year) AND MONTH(ua.date) = MONTH(month_year);
    
    UPDATE temp_table 
    JOIN calendar_holidays ch ON temp_table.day = ch.holiday_date
    SET temp_table.holiday = ch.holiday_name
    WHERE YEAR(ch.holiday_date) = YEAR(month_year) AND MONTH(ch.holiday_date) = MONTH(month_year);
    
    SELECT * from temp_table ORDER BY 
    CASE 
    WHEN EXTRACT(YEAR_MONTH from month_year) = EXTRACT(YEAR_MONTH from CURDATE()) 
    THEN day END DESC;
    
    	
    

	DROP TABLE temp_table;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UpdateYearlyRecurringLeave` (IN `user_id` INT)  MODIFIES SQL DATA
BEGIN
	IF NOT EXISTS(SELECT * FROM yearly_leave_calculations WHERE YEAR(calculated_at) = YEAR(NOW()))
    	THEN
       	UPDATE users 
        left join leave_applications la ON la.user_id = users.id and la.is_approved = 1 AND YEAR(la.from_date) = YEAR(NOW()) - 1
        set carry_leaves = carry_leaves +
            ifnull((select cast(
                (CASE WHEN YEAR(join_date) < (YEAR(NOW()) - 1)
                    THEN
                    SUM(total_amount) - ifnull(SUM(total_days),0)
                 	WHEN YEAR(join_date) = YEAR(NOW()) THEN 0
                    ELSE
                            (CASE WHEN MONTH(join_date) = 1 THEN SUM(jan) - ifnull(SUM(total_days),0)
                            WHEN MONTH(join_date) = 2 THEN SUM(feb) - ifnull(SUM(total_days),0)
                            WHEN MONTH(join_date) = 3 THEN sum(mar) - ifnull(SUM(total_days),0)
                            WHEN MONTH(join_date) = 4 THEN SUM(apr) - ifnull(SUM(total_days),0)
                            WHEN MONTH(join_date) = 5 THEN SUM(may) - ifnull(SUM(total_days),0)
                            WHEN MONTH(join_date) = 6 THEN SUM(jun) - ifnull(SUM(total_days),0)
                            WHEN MONTH(join_date) = 7 THEN SUM(jul) - ifnull(SUM(total_days),0)
                            WHEN MONTH(join_date) = 8 THEN SUM(aug) - ifnull(SUM(total_days),0)
                            WHEN MONTH(join_date) = 9 THEN SUM(sep) - ifnull(SUM(total_days),0)
                            WHEN MONTH(join_date) = 10 THEN SUM(oct) - ifnull(SUM(total_days),0)
                            WHEN MONTH(join_date) = 11 THEN SUM(nov) - ifnull(SUM(total_days),0)
                            ELSE SUM(leaves.dec) - ifnull(SUM(total_days),0) END) 
                END) 
                as integer) remaining_leave
                from  leaves 
            WHERE leaves.carry_forward = 1
            group by leaves.id),0);

       INSERT INTO yearly_leave_calculations (user_id, calculated_at) VALUES(user_id, NOW());
       select 1 as success;
       ELSE
       select 0 as success;
       END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UserCurrentLeaveDetails` (IN `userId` INT)  NO SQL
BEGIN
		
        SET @joining_date = (SELECT join_date from users where id = userId);
		
		select leaves.id as leave_id,
        leaves.name, 
        
        cast(ifnull(SUM(total_days),0) as integer) as leave_taken,
        cast((CASE WHEN YEAR(@joining_date) < YEAR(NOW())
                 THEN
              	 	CASE WHEN (carry_forward = 1) THEN 
                 	total_amount - ifnull(SUM(total_days),0) + (SELECT carry_leaves FROM users WHERE id = userId)
              		ELSE
              		total_amount - ifnull(SUM(total_days),0)
              		END
                 ELSE
                     (CASE WHEN MONTH(@joining_date) = 1 THEN jan - ifnull(SUM(total_days),0)
                     WHEN MONTH(@joining_date) = 2 THEN feb - ifnull(SUM(total_days),0)
                     WHEN MONTH(@joining_date) = 3 THEN mar - ifnull(SUM(total_days),0)
                     WHEN MONTH(@joining_date) = 4 THEN apr - ifnull(SUM(total_days),0)
                     WHEN MONTH(@joining_date) = 5 THEN may - ifnull(SUM(total_days),0)
                     WHEN MONTH(@joining_date) = 6 THEN jun - ifnull(SUM(total_days),0)
                     WHEN MONTH(@joining_date) = 7 THEN jul - ifnull(SUM(total_days),0)
                     WHEN MONTH(@joining_date) = 8 THEN aug - ifnull(SUM(total_days),0)
                     WHEN MONTH(@joining_date) = 9 THEN sep - ifnull(SUM(total_days),0)
                     WHEN MONTH(@joining_date) = 10 THEN oct - ifnull(SUM(total_days),0)
                     WHEN MONTH(@joining_date) = 11 THEN nov - ifnull(SUM(total_days),0)
                     ELSE leaves.dec - ifnull(SUM(total_days),0) END)  
         END) as integer) remaining_leave
         from leaves 
         left join leave_applications ON  leave_applications.leave_id = leaves.id AND leave_applications.user_id = userId AND leave_applications.is_approved = 1 AND YEAR(leave_applications.from_date) =  YEAR(NOW())    
         group by leaves.id;
         
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `calendar_holidays`
--

CREATE TABLE `calendar_holidays` (
  `id` int(10) UNSIGNED NOT NULL,
  `holiday_name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `holiday_date` date NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `calendar_holidays`
--

INSERT INTO `calendar_holidays` (`id`, `holiday_name`, `holiday_date`, `created_at`, `updated_at`) VALUES
(1, 'Weekend', '2018-12-07', NULL, NULL),
(5, 'Victory Day', '2018-12-16', NULL, NULL),
(13, 'Weekend', '2018-11-02', NULL, NULL),
(14, 'Weekend', '2018-11-09', NULL, NULL),
(15, 'Weekend', '2018-11-16', NULL, NULL),
(16, 'Weekend', '2018-11-30', NULL, NULL),
(17, 'Weekend', '2018-11-23', NULL, NULL),
(18, 'Weekend', '2018-10-05', NULL, NULL),
(19, 'Weekend', '2018-10-12', NULL, NULL),
(20, 'Weekend', '2018-10-19', NULL, NULL),
(21, 'weekend', '2018-10-26', NULL, NULL),
(22, 'Weekend', '2018-10-06', NULL, NULL),
(23, 'Weekend', '2018-10-13', NULL, NULL),
(24, 'Weekend', '2018-10-20', NULL, NULL),
(25, 'Weekend', '2018-10-27', NULL, NULL),
(26, 'Weekend', '2018-12-21', NULL, NULL),
(27, 'Christmas', '2018-12-25', NULL, NULL),
(28, 'Weekend', '2019-03-01', NULL, NULL),
(29, 'Weekend', '2019-03-08', NULL, NULL),
(30, 'Weekend', '2019-03-15', NULL, NULL),
(31, 'Weekend', '2020-05-01', NULL, NULL),
(35, 'Weekend', '2019-03-29', NULL, NULL),
(36, 'Weekend', '2023-08-01', NULL, NULL),
(37, 'Weekend', '2019-04-05', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `clients`
--

CREATE TABLE `clients` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `conatct_no` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lat_lng` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `location_area_id` int(10) UNSIGNED NOT NULL,
  `status` tinyint(4) DEFAULT NULL COMMENT '1=active,0=inactive',
  `description` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `clients`
--

INSERT INTO `clients` (`id`, `name`, `conatct_no`, `lat_lng`, `address`, `user_id`, `location_area_id`, `status`, `description`, `created_at`, `updated_at`) VALUES
(6, 'Good Smile Pharma', 'dkdk', NULL, ' Farmgate Foot Over Bridge, Holly', 5, 5, 1, '', NULL, NULL),
(7, 'Best Pharma', NULL, NULL, ' Farmgate Foot Over Bridge, Holly', 5, 5, 1, '', NULL, NULL),
(9, 'Al Raji', '33333399999', NULL, 'Farmgate Foot Over Bridge, Holly', 5, 1, 0, NULL, '2019-03-12 05:50:26', '2019-03-23 04:30:14'),
(10, 'alama', '01710551016', '23.685, 90.3563', 'Farmgate Foot Over Bridge, Hollyy', 5, 5, 1, 'des', '2019-03-12 05:51:28', '2019-03-21 01:50:59'),
(15, 'Holyyy Pharma', '01712-973839', NULL, 'Farmgate Foot Over Bridge, Holly', 5, 5, 1, NULL, NULL, '2019-03-21 01:51:28'),
(16, 'Moon Homeo Pharmacy', '01716-747098', NULL, 'Rahman Plaza, Indira Road, Farmgate', 5, 5, 0, NULL, NULL, '2019-03-23 04:30:35'),
(17, 'Moon Homeo Pharmacy', '01716-747098', NULL, 'Rahman Plaza, Indira Road, Farmgate', 1, 5, 0, NULL, NULL, '2019-03-23 04:30:35'),
(18, 'Al raji', '5885888', '23.7592827, 90.3899095', 'oictl', 73, 30, 1, NULL, '2019-03-31 13:45:04', '2019-03-31 13:45:04'),
(19, 'ma pharma', '69758', '23.766492191373995, 90.38978967815638', NULL, 73, 30, 1, NULL, '2019-03-31 13:45:45', '2019-03-31 13:45:45'),
(20, 'raju', '0712', '23.811194629648273, 90.39028756320477', 'test', 65, 25, 1, NULL, '2019-03-31 14:11:28', '2019-03-31 14:11:28'),
(21, 'Al-Raji Pharmacy', '01716212296', '23.81084586842332, 90.40773399174213', 'farmgate concord tower', 65, 25, 1, NULL, '2019-04-01 04:04:35', '2019-04-01 04:04:35'),
(22, 'M/S Janani Pharmacy', '01687099518', '23.812861738304765, 90.3922700509429', 'tejgaon', 65, 25, 1, NULL, '2019-04-01 04:05:42', '2019-04-01 04:05:42'),
(23, 'Mim Pharmacy', '01817124285', '23.7590686, 90.3900788', 'Green super Market Dhaka', 65, 25, 1, NULL, '2019-04-01 04:07:08', '2019-04-01 04:07:08'),
(24, 'Alif Pharmacy', '019165000', NULL, 'farmgate', 14, 26, 1, NULL, '2019-04-01 04:53:08', '2019-04-01 04:53:08'),
(25, 'Mina Pharmacy', '01753414710', '23.7591711, 90.3900058', 'farmgate', 14, 26, 1, NULL, '2019-04-01 04:58:00', '2019-04-01 04:58:00'),
(26, 'Mita Pharmacy', '01753414710', NULL, 'Station Road', 14, 26, 1, NULL, '2019-04-01 05:03:12', '2019-04-01 05:03:12'),
(27, 'good health', '01737366450', '23.762436888357445, 90.38990668952465', 'rajabazar', 6, 10, 1, NULL, '2019-04-01 05:20:11', '2019-04-01 05:20:11'),
(28, 'lamabaza', '01323456789', '23.757289638213233, 90.38905676454306', 'lama villege', 6, 10, 1, 'this s my second sales', '2019-04-01 05:26:52', '2019-04-01 05:26:52'),
(29, 'test pharma', '0111', '23.81103267204555, 90.39116531610489', 'test', 14, 26, 1, NULL, '2019-04-01 06:03:39', '2019-04-01 06:03:39'),
(30, 'al-helal', '01345678901', '23.764662779313092, 90.37906251847745', 'pantha nagar', 6, 10, 1, 'sales with special request', '2019-04-01 06:20:01', '2019-04-01 06:20:01'),
(31, 'Adiba Pharma', '01704164905', '23.805081203524647, 90.38895182311536', 'tejgaon', 65, 25, 1, 'Test', '2019-04-01 06:56:07', '2019-04-01 06:56:07');

-- --------------------------------------------------------

--
-- Table structure for table `collections`
--

CREATE TABLE `collections` (
  `id` int(10) UNSIGNED NOT NULL,
  `sales_id` int(10) UNSIGNED NOT NULL,
  `collection_amount` double(20,2) NOT NULL,
  `collection_date` date DEFAULT NULL,
  `collection_note` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `user_id` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `collections`
--

INSERT INTO `collections` (`id`, `sales_id`, `collection_amount`, `collection_date`, `collection_note`, `created_at`, `updated_at`, `user_id`) VALUES
(1, 1, 100.00, '2019-03-12', 'collected', NULL, NULL, 5),
(2, 1, 120.00, '2019-03-10', 'collected', NULL, NULL, 5),
(3, 1, 400.00, '2019-03-20', NULL, NULL, NULL, 5),
(4, 2, 2.00, '2019-03-10', NULL, NULL, NULL, 5),
(5, 2, 4.00, '2019-03-22', NULL, NULL, NULL, 5),
(6, 4, 100.00, '2019-03-21', NULL, NULL, NULL, 5),
(7, 4, 10.00, '2019-03-22', NULL, NULL, NULL, 5),
(8, 5, 100.00, '2019-03-23', NULL, NULL, NULL, 5),
(9, 6, 200.00, '2019-03-25', NULL, NULL, NULL, 5),
(10, 5, 50.00, '2019-03-20', NULL, NULL, NULL, 5),
(11, 7, 99.00, '2019-03-18', NULL, '2019-03-18 02:29:02', '2019-03-18 02:29:02', 5),
(12, 21, 10.00, '2019-03-25', NULL, '2019-03-18 03:34:13', '2019-03-18 03:34:13', 5),
(13, 22, 134.00, '2019-03-22', NULL, '2019-03-18 03:35:06', '2019-03-18 03:35:06', 5),
(14, 23, 56.00, '2019-03-19', NULL, '2019-03-19 06:51:06', '2019-03-19 06:51:06', 5),
(15, 1, 300.00, '2019-03-30', 'kisu', '2019-03-19 07:16:44', '2019-03-19 07:16:44', 0),
(16, 1, 20.00, '2019-03-30', 'kisu', '2019-03-19 07:17:41', '2019-03-19 07:17:41', 0),
(19, 8, 2000.00, '2019-03-30', 'kisu', '2019-03-19 07:23:21', '2019-03-19 07:23:21', 0),
(20, 1, 10.00, '2019-03-19', NULL, '2019-03-19 07:39:40', '2019-03-19 07:39:40', 0),
(21, 1, 11.00, '2019-03-19', 'Test', '2019-03-19 07:43:40', '2019-03-19 07:43:40', 0),
(22, 1, 12.00, '2019-03-19', '68ih', '2019-03-19 07:44:05', '2019-03-19 07:44:05', 0),
(23, 24, 80.00, '2019-03-20', NULL, '2019-03-20 02:27:11', '2019-03-20 02:27:11', 5),
(24, 25, 200.00, '2019-03-31', NULL, '2019-03-31 13:46:33', '2019-03-31 13:46:33', 73),
(25, 26, 200.00, '2019-04-01', NULL, '2019-03-31 14:13:44', '2019-03-31 14:13:44', 65),
(26, 27, 500.00, '2019-03-30', NULL, '2019-03-31 14:32:45', '2019-03-31 14:32:45', 65),
(27, 28, 2000.00, '2019-03-31', NULL, '2019-03-31 14:33:24', '2019-03-31 14:33:24', 65),
(28, 29, 400.00, '2019-03-26', NULL, '2019-03-31 14:49:42', '2019-03-31 14:49:42', 65),
(29, 30, 4000.00, '2019-03-21', NULL, '2019-03-31 14:51:15', '2019-03-31 14:51:15', 65),
(30, 31, 1000.00, '2019-04-01', NULL, '2019-04-01 04:08:51', '2019-04-01 04:08:51', 65),
(31, 31, 1000.00, '2019-04-01', NULL, '2019-04-01 04:14:51', '2019-04-01 04:14:51', 65),
(32, 31, 1500.00, '2019-04-01', NULL, '2019-04-01 04:15:14', '2019-04-01 04:15:14', 65),
(33, 32, 100.00, '2019-04-01', NULL, '2019-04-01 04:16:15', '2019-04-01 04:16:15', 65),
(34, 32, 1200.00, '2019-04-01', NULL, '2019-04-01 04:16:55', '2019-04-01 04:16:55', 65),
(35, 33, 2000.00, '2019-03-04', NULL, '2019-04-01 05:02:10', '2019-04-01 05:02:10', 65),
(36, 34, 1000.00, '2019-03-06', NULL, '2019-04-01 05:04:47', '2019-04-01 05:04:47', 65),
(37, 35, 100.00, '2019-03-03', NULL, '2019-04-01 05:08:15', '2019-04-01 05:08:15', 14),
(38, 35, 150.00, '2019-03-05', NULL, '2019-04-01 05:09:36', '2019-04-01 05:09:36', 14),
(39, 35, 200.00, '2019-03-06', NULL, '2019-04-01 05:10:25', '2019-04-01 05:10:25', 14),
(40, 36, 2500.00, '2019-03-09', NULL, '2019-04-01 05:15:43', '2019-04-01 05:15:43', 65),
(41, 37, 2000.00, '2019-03-16', NULL, '2019-04-01 05:16:24', '2019-04-01 05:16:24', 65),
(42, 31, 1500.00, '2019-04-01', NULL, '2019-04-01 05:17:13', '2019-04-01 05:17:13', 65),
(43, 38, 4021.00, '2019-04-01', NULL, '2019-04-01 05:21:32', '2019-04-01 05:21:32', 6),
(44, 35, 100.00, '2019-03-09', NULL, '2019-04-01 05:21:45', '2019-04-01 05:21:45', 14),
(45, 38, 500.00, '2019-04-01', NULL, '2019-04-01 05:22:39', '2019-04-01 05:22:39', 6),
(46, 39, 11501.00, '2019-04-01', NULL, '2019-04-01 05:29:25', '2019-04-01 05:29:25', 6),
(47, 40, 100.00, '2019-03-11', NULL, '2019-04-01 05:33:16', '2019-04-01 05:33:16', 14),
(48, 40, 300.00, '2019-03-12', NULL, '2019-04-01 05:34:19', '2019-04-01 05:34:19', 14),
(49, 40, 500.00, '2019-03-14', NULL, '2019-04-01 05:34:37', '2019-04-01 05:34:37', 14),
(50, 40, 1000.00, '2019-03-15', NULL, '2019-04-01 05:35:07', '2019-04-01 05:35:07', 14),
(51, 40, 100.00, '2019-04-01', NULL, '2019-04-01 06:07:03', '2019-04-01 06:07:03', 14),
(52, 41, 200.00, '2019-04-01', NULL, '2019-04-01 06:08:06', '2019-04-01 06:08:06', 14),
(53, 41, 190.00, '2019-04-01', NULL, '2019-04-01 06:09:23', '2019-04-01 06:09:23', 14),
(54, 42, 15361.00, '2019-04-01', NULL, '2019-04-01 06:22:20', '2019-04-01 06:22:20', 6),
(55, 45, 2500.00, '2019-04-01', NULL, '2019-04-01 06:57:14', '2019-04-01 06:57:14', 65),
(56, 45, 2000.00, '2019-04-01', 'Par', '2019-04-01 06:58:29', '2019-04-01 06:58:29', 65),
(57, 46, 1000.00, '2019-04-01', NULL, '2019-04-01 09:00:51', '2019-04-01 09:00:51', 65),
(58, 46, 1000.00, '2019-04-09', NULL, '2019-04-01 09:01:27', '2019-04-01 09:01:27', 65),
(59, 46, 200.00, '2019-04-11', NULL, '2019-04-01 09:02:04', '2019-04-01 09:02:04', 65),
(60, 46, 200.00, '2019-04-16', NULL, '2019-04-01 09:04:23', '2019-04-01 09:04:23', 65),
(61, 34, 500.00, '2019-04-01', NULL, '2019-04-01 09:06:28', '2019-04-01 09:06:28', 65),
(62, 47, 456.00, '2019-04-01', NULL, '2019-04-01 09:09:10', '2019-04-01 09:09:10', 65);

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
(1, 'Marketing', 'Marketing department', '2019-03-11 02:48:04', NULL),
(2, 'HR', 'HR Dept.', '2019-03-24 18:00:00', '2019-03-31 06:43:25'),
(3, 'Sales', 'Sales department', '2019-03-25 03:22:55', '2019-03-31 06:44:55'),
(4, 'Audit', 'Audit department', '2019-03-25 03:24:48', '2019-03-31 06:44:28');

-- --------------------------------------------------------

--
-- Table structure for table `depots`
--

CREATE TABLE `depots` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `depots`
--

INSERT INTO `depots` (`id`, `name`, `description`, `created_at`, `updated_at`) VALUES
(1, 'Sylhet', 'Sylhet Depot', '2019-03-30 07:25:03', '2019-03-31 06:22:34'),
(2, 'Rangpur', 'Rangpur Depot', '2019-03-30 09:26:10', '2019-03-31 06:20:37'),
(3, 'Mymensingh', 'Mymensingh Depot', '2019-03-31 06:21:00', '2019-03-31 06:21:00'),
(4, 'Chittagong', 'Chittagong Depot', '2019-03-31 06:21:57', '2019-03-31 06:21:57');

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
(1, 'GM', 'General Manager, Sales', '2019-03-11 02:48:04', '2019-03-31 06:45:21'),
(2, 'SM', 'Sales Manager', '2019-03-25 03:44:39', '2019-03-31 06:45:42'),
(3, 'RSM', 'Regional Sales Manager', '2019-03-28 02:11:33', '2019-03-31 06:46:13'),
(4, 'AM', 'Area Manager', '2019-03-31 06:46:27', '2019-03-31 06:46:27'),
(5, 'MIO', 'MIO', '2019-03-31 06:46:47', '2019-03-31 06:46:47'),
(6, 'MD', NULL, '2019-03-31 06:47:20', '2019-03-31 06:47:20');

-- --------------------------------------------------------

--
-- Table structure for table `educations`
--

CREATE TABLE `educations` (
  `id` int(11) NOT NULL,
  `jobseeker_id` int(11) DEFAULT NULL,
  `degree_title` int(11) NOT NULL,
  `begin_date` date NOT NULL,
  `end_date` date NOT NULL,
  `level_of_education` int(11) NOT NULL,
  `school_name` int(11) NOT NULL,
  `education_completed` tinyint(4) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

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
(1, 1, 'name1', 'tile', 'emp', 'a@gmail.com', 'add', '2019-11-24 12:56:37', '2019-11-24 19:01:19'),
(2, 1, 'Reference name 21', 'Title 2', 'Employer 2', 'e2@gmail.com', 'address 2', '2019-11-24 16:12:48', '2019-11-24 19:00:35'),
(3, 1, 'name 3', 't3', 'e3', 'a@gmail.com', 'add3', '2019-11-24 19:01:44', '2019-11-24 19:01:44');

-- --------------------------------------------------------

--
-- Table structure for table `leaves`
--

CREATE TABLE `leaves` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `carry_forward` tinyint(4) NOT NULL DEFAULT 0,
  `gender_specific` tinyint(4) DEFAULT NULL,
  `total_amount` int(11) NOT NULL DEFAULT 0,
  `jan` int(11) NOT NULL DEFAULT 0,
  `feb` int(11) NOT NULL DEFAULT 0,
  `mar` int(11) NOT NULL DEFAULT 0,
  `apr` int(11) NOT NULL DEFAULT 0,
  `may` int(11) NOT NULL DEFAULT 0,
  `jun` int(11) NOT NULL DEFAULT 0,
  `jul` int(11) NOT NULL DEFAULT 0,
  `aug` int(11) NOT NULL DEFAULT 0,
  `sep` int(11) NOT NULL DEFAULT 0,
  `oct` int(11) NOT NULL DEFAULT 0,
  `nov` int(11) NOT NULL DEFAULT 0,
  `dec` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `leaves`
--

INSERT INTO `leaves` (`id`, `name`, `carry_forward`, `gender_specific`, `total_amount`, `jan`, `feb`, `mar`, `apr`, `may`, `jun`, `jul`, `aug`, `sep`, `oct`, `nov`, `dec`, `created_at`, `updated_at`) VALUES
(1, 'Earned Leave', 1, NULL, 22, 20, 18, 17, 16, 14, 12, 10, 8, 6, 4, 5, 2, NULL, NULL),
(2, 'Sick Leave', 0, NULL, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, NULL, NULL),
(3, 'Casual Leave', 0, NULL, 30, 1, 3, 3, 3, 3, 3, 3, 3, 3, 5, 3, 3, NULL, '2018-11-20 06:28:53'),
(4, 'Paternal Leave', 0, 1, 12, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, '2019-01-29 05:35:52', '2019-01-29 05:35:52');

-- --------------------------------------------------------

--
-- Table structure for table `leave_applications`
--

CREATE TABLE `leave_applications` (
  `id` int(10) UNSIGNED NOT NULL,
  `reason` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remarks` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `leave_id` int(10) UNSIGNED NOT NULL,
  `fiscal_year_id` int(10) UNSIGNED DEFAULT NULL,
  `from_date` date NOT NULL,
  `to_date` date NOT NULL,
  `total_days` int(11) NOT NULL,
  `approved_by` int(10) UNSIGNED DEFAULT NULL,
  `is_approved` tinyint(4) NOT NULL DEFAULT 0,
  `file` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `leave_applications`
--

INSERT INTO `leave_applications` (`id`, `reason`, `description`, `remarks`, `user_id`, `leave_id`, `fiscal_year_id`, `from_date`, `to_date`, `total_days`, `approved_by`, `is_approved`, `file`, `created_at`, `updated_at`) VALUES
(1, 'hudai', NULL, NULL, 1, 1, NULL, '2018-11-29', '2018-12-02', 4, 56, 1, NULL, '2018-11-18 09:33:55', '2018-11-18 09:33:55'),
(2, 'hudai', NULL, NULL, 1, 2, NULL, '2018-12-20', '2018-12-25', 6, 56, 1, NULL, '2018-11-18 09:34:07', '2018-11-19 11:44:03'),
(4, 'hudai', NULL, NULL, 1, 3, NULL, '2018-12-13', '2018-12-13', 2, 56, 1, NULL, '2018-11-18 09:34:47', '2018-11-19 11:46:22'),
(5, 'hudai', NULL, NULL, 1, 2, NULL, '2018-01-01', '2018-01-02', 2, 56, 1, NULL, '2018-11-18 09:34:47', '2018-11-18 09:34:47'),
(6, 'Want to go ...', NULL, 'Ok', 5, 1, NULL, '2017-12-25', '2018-01-01', 1, 56, 1, NULL, '2018-11-18 09:34:47', '2018-11-19 11:46:22'),
(7, 'Want to go ...', NULL, 'An auditor  may come', 5, 3, NULL, '2018-01-01', '2018-01-01', 1, 56, 2, NULL, '2018-11-18 09:34:47', '2018-12-08 05:06:35');

-- --------------------------------------------------------

--
-- Table structure for table `location_areas`
--

CREATE TABLE `location_areas` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `parent_id` int(11) NOT NULL DEFAULT 0,
  `location_level_id` int(10) UNSIGNED NOT NULL,
  `lat_lng` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `map_data` longtext COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `location_areas`
--

INSERT INTO `location_areas` (`id`, `name`, `parent_id`, `location_level_id`, `lat_lng`, `map_data`, `description`, `created_at`, `updated_at`) VALUES
(1, 'One Pharma HQ', 0, 1, '{\"lat\":23.6850,\"lng\": 90.3563,\"zoom\":9}', 'https://www.dropbox.com/s/ovh99h7wtfa2uny/bangladesh.kmz?dl=1', NULL, '2019-03-11 02:48:04', NULL),
(2, 'North Zone', 1, 2, '{\\\"lat\\\":\\\"24.7240\\\",\\\"lng\\\":\\\"88.8786\\\",\\\"zoom\\\":8}', '[{\\\"lat\\\":24.674074156954287,\\\"lng\\\":88.02170527343753},{\\\"lat\\\":24.813761167171297,\\\"lng\\\":88.10959589843753},{\\\"lat\\\":24.873578919363887,\\\"lng\\\":88.15903437500003},{\\\"lat\\\":24.933367731897114,\\\"lng\\\":88.15354121093753},{\\\"lat\\\":24.968231154396594,\\\"lng\\\":88.21945917968753},{\\\"lat\\\":24.888528837587863,\\\"lng\\\":88.26889765625003},{\\\"lat\\\":24.888528837587863,\\\"lng\\\":88.34030878906253},{\\\"lat\\\":24.933367731897114,\\\"lng\\\":88.32932246093753},{\\\"lat\\\":24.968231154396594,\\\"lng\\\":88.36777460937503},{\\\"lat\\\":24.96325126982539,\\\"lng\\\":88.41171992187503},{\\\"lat\\\":25.097637329824423,\\\"lng\\\":88.44467890625003},{\\\"lat\\\":25.137427126442102,\\\"lng\\\":88.46115839843753},{\\\"lat\\\":25.202057894171094,\\\"lng\\\":88.44467890625003},{\\\"lat\\\":25.197087513283403,\\\"lng\\\":88.51609003906253},{\\\"lat\\\":25.177203961238682,\\\"lng\\\":88.56003535156253},{\\\"lat\\\":25.207028072151154,\\\"lng\\\":88.74130976562503},{\\\"lat\\\":25.16726096852795,\\\"lng\\\":88.81272089843753},{\\\"lat\\\":25.207028072151154,\\\"lng\\\":88.84567988281253},{\\\"lat\\\":25.17223256624973,\\\"lng\\\":88.95005000000003},{\\\"lat\\\":25.221937388354235,\\\"lng\\\":88.97202265625003},{\\\"lat\\\":25.276589242277154,\\\"lng\\\":88.99948847656253},{\\\"lat\\\":25.2269067544126,\\\"lng\\\":89.16428339843753},{\\\"lat\\\":25.152344959257448,\\\"lng\\\":89.21372187500003},{\\\"lat\\\":25.11256002156972,\\\"lng\\\":89.26316035156253},{\\\"lat\\\":25.11256002156972,\\\"lng\\\":89.34006464843753},{\\\"lat\\\":25.072762131415075,\\\"lng\\\":89.37851679687503},{\\\"lat\\\":25.047881879303535,\\\"lng\\\":89.54880488281253},{\\\"lat\\\":25.03295130378438,\\\"lng\\\":89.60373652343753},{\\\"lat\\\":24.853642881624296,\\\"lng\\\":89.60373652343753},{\\\"lat\\\":24.624147946786504,\\\"lng\\\":89.65866816406253},{\\\"lat\\\":24.40423604332974,\\\"lng\\\":89.74655878906253},{\\\"lat\\\":24.274107614347415,\\\"lng\\\":89.74655878906253},{\\\"lat\\\":24.033520391868528,\\\"lng\\\":89.72458613281253},{\\\"lat\\\":23.83268612236187,\\\"lng\\\":89.75205195312503},{\\\"lat\\\":23.817610972124626,\\\"lng\\\":89.63669550781253},{\\\"lat\\\":23.87790105827056,\\\"lng\\\":89.42246210937503},{\\\"lat\\\":23.958244164879513,\\\"lng\\\":89.18076289062503},{\\\"lat\\\":24.053586612693188,\\\"lng\\\":89.02695429687503},{\\\"lat\\\":24.128806992143474,\\\"lng\\\":88.97751582031253},{\\\"lat\\\":24.128806992143474,\\\"lng\\\":88.83469355468753},{\\\"lat\\\":24.219013084144738,\\\"lng\\\":88.73581660156253},{\\\"lat\\\":24.284122237091808,\\\"lng\\\":88.74130976562503},{\\\"lat\\\":24.339188539652735,\\\"lng\\\":88.68637812500003},{\\\"lat\\\":24.344193381198895,\\\"lng\\\":88.53806269531253},{\\\"lat\\\":24.379221732157642,\\\"lng\\\":88.41171992187503},{\\\"lat\\\":24.459250084900294,\\\"lng\\\":88.30185664062503}]', NULL, NULL, NULL),
(3, 'Dhaka C1', 2, 3, '{\"lat\":23.6850,\"lng\": 90.3563,\"zoom\":7}', '[{\\\"lat\\\":24.674074156954287,\\\"lng\\\":88.02170527343753},{\\\"lat\\\":24.813761167171297,\\\"lng\\\":88.10959589843753},{\\\"lat\\\":24.873578919363887,\\\"lng\\\":88.15903437500003},{\\\"lat\\\":24.933367731897114,\\\"lng\\\":88.15354121093753},{\\\"lat\\\":24.968231154396594,\\\"lng\\\":88.21945917968753},{\\\"lat\\\":24.888528837587863,\\\"lng\\\":88.26889765625003},{\\\"lat\\\":24.888528837587863,\\\"lng\\\":88.34030878906253},{\\\"lat\\\":24.933367731897114,\\\"lng\\\":88.32932246093753},{\\\"lat\\\":24.968231154396594,\\\"lng\\\":88.36777460937503},{\\\"lat\\\":24.96325126982539,\\\"lng\\\":88.41171992187503},{\\\"lat\\\":25.097637329824423,\\\"lng\\\":88.44467890625003},{\\\"lat\\\":25.137427126442102,\\\"lng\\\":88.46115839843753},{\\\"lat\\\":25.202057894171094,\\\"lng\\\":88.44467890625003},{\\\"lat\\\":25.197087513283403,\\\"lng\\\":88.51609003906253},{\\\"lat\\\":25.177203961238682,\\\"lng\\\":88.56003535156253},{\\\"lat\\\":25.207028072151154,\\\"lng\\\":88.74130976562503},{\\\"lat\\\":25.16726096852795,\\\"lng\\\":88.81272089843753},{\\\"lat\\\":25.207028072151154,\\\"lng\\\":88.84567988281253},{\\\"lat\\\":25.17223256624973,\\\"lng\\\":88.95005000000003},{\\\"lat\\\":25.221937388354235,\\\"lng\\\":88.97202265625003},{\\\"lat\\\":25.276589242277154,\\\"lng\\\":88.99948847656253},{\\\"lat\\\":25.2269067544126,\\\"lng\\\":89.16428339843753},{\\\"lat\\\":25.152344959257448,\\\"lng\\\":89.21372187500003},{\\\"lat\\\":25.11256002156972,\\\"lng\\\":89.26316035156253},{\\\"lat\\\":25.11256002156972,\\\"lng\\\":89.34006464843753},{\\\"lat\\\":25.072762131415075,\\\"lng\\\":89.37851679687503},{\\\"lat\\\":25.047881879303535,\\\"lng\\\":89.54880488281253},{\\\"lat\\\":25.03295130378438,\\\"lng\\\":89.60373652343753},{\\\"lat\\\":24.853642881624296,\\\"lng\\\":89.60373652343753},{\\\"lat\\\":24.624147946786504,\\\"lng\\\":89.65866816406253},{\\\"lat\\\":24.40423604332974,\\\"lng\\\":89.74655878906253},{\\\"lat\\\":24.274107614347415,\\\"lng\\\":89.74655878906253},{\\\"lat\\\":24.033520391868528,\\\"lng\\\":89.72458613281253},{\\\"lat\\\":23.83268612236187,\\\"lng\\\":89.75205195312503},{\\\"lat\\\":23.817610972124626,\\\"lng\\\":89.63669550781253},{\\\"lat\\\":23.87790105827056,\\\"lng\\\":89.42246210937503},{\\\"lat\\\":23.958244164879513,\\\"lng\\\":89.18076289062503},{\\\"lat\\\":24.053586612693188,\\\"lng\\\":89.02695429687503},{\\\"lat\\\":24.128806992143474,\\\"lng\\\":88.97751582031253},{\\\"lat\\\":24.128806992143474,\\\"lng\\\":88.83469355468753},{\\\"lat\\\":24.219013084144738,\\\"lng\\\":88.73581660156253},{\\\"lat\\\":24.284122237091808,\\\"lng\\\":88.74130976562503},{\\\"lat\\\":24.339188539652735,\\\"lng\\\":88.68637812500003},{\\\"lat\\\":24.344193381198895,\\\"lng\\\":88.53806269531253},{\\\"lat\\\":24.379221732157642,\\\"lng\\\":88.41171992187503},{\\\"lat\\\":24.459250084900294,\\\"lng\\\":88.30185664062503}]', NULL, NULL, NULL),
(4, 'Mawna', 3, 4, '{\"lat\":23.6850,\"lng\": 90.3563,\"zoom\":7}', '[{\\\"lat\\\":24.674074156954287,\\\"lng\\\":88.02170527343753},{\\\"lat\\\":24.813761167171297,\\\"lng\\\":88.10959589843753},{\\\"lat\\\":24.873578919363887,\\\"lng\\\":88.15903437500003},{\\\"lat\\\":24.933367731897114,\\\"lng\\\":88.15354121093753},{\\\"lat\\\":24.968231154396594,\\\"lng\\\":88.21945917968753},{\\\"lat\\\":24.888528837587863,\\\"lng\\\":88.26889765625003},{\\\"lat\\\":24.888528837587863,\\\"lng\\\":88.34030878906253},{\\\"lat\\\":24.933367731897114,\\\"lng\\\":88.32932246093753},{\\\"lat\\\":24.968231154396594,\\\"lng\\\":88.36777460937503},{\\\"lat\\\":24.96325126982539,\\\"lng\\\":88.41171992187503},{\\\"lat\\\":25.097637329824423,\\\"lng\\\":88.44467890625003},{\\\"lat\\\":25.137427126442102,\\\"lng\\\":88.46115839843753},{\\\"lat\\\":25.202057894171094,\\\"lng\\\":88.44467890625003},{\\\"lat\\\":25.197087513283403,\\\"lng\\\":88.51609003906253},{\\\"lat\\\":25.177203961238682,\\\"lng\\\":88.56003535156253},{\\\"lat\\\":25.207028072151154,\\\"lng\\\":88.74130976562503},{\\\"lat\\\":25.16726096852795,\\\"lng\\\":88.81272089843753},{\\\"lat\\\":25.207028072151154,\\\"lng\\\":88.84567988281253},{\\\"lat\\\":25.17223256624973,\\\"lng\\\":88.95005000000003},{\\\"lat\\\":25.221937388354235,\\\"lng\\\":88.97202265625003},{\\\"lat\\\":25.276589242277154,\\\"lng\\\":88.99948847656253},{\\\"lat\\\":25.2269067544126,\\\"lng\\\":89.16428339843753},{\\\"lat\\\":25.152344959257448,\\\"lng\\\":89.21372187500003},{\\\"lat\\\":25.11256002156972,\\\"lng\\\":89.26316035156253},{\\\"lat\\\":25.11256002156972,\\\"lng\\\":89.34006464843753},{\\\"lat\\\":25.072762131415075,\\\"lng\\\":89.37851679687503},{\\\"lat\\\":25.047881879303535,\\\"lng\\\":89.54880488281253},{\\\"lat\\\":25.03295130378438,\\\"lng\\\":89.60373652343753},{\\\"lat\\\":24.853642881624296,\\\"lng\\\":89.60373652343753},{\\\"lat\\\":24.624147946786504,\\\"lng\\\":89.65866816406253},{\\\"lat\\\":24.40423604332974,\\\"lng\\\":89.74655878906253},{\\\"lat\\\":24.274107614347415,\\\"lng\\\":89.74655878906253},{\\\"lat\\\":24.033520391868528,\\\"lng\\\":89.72458613281253},{\\\"lat\\\":23.83268612236187,\\\"lng\\\":89.75205195312503},{\\\"lat\\\":23.817610972124626,\\\"lng\\\":89.63669550781253},{\\\"lat\\\":23.87790105827056,\\\"lng\\\":89.42246210937503},{\\\"lat\\\":23.958244164879513,\\\"lng\\\":89.18076289062503},{\\\"lat\\\":24.053586612693188,\\\"lng\\\":89.02695429687503},{\\\"lat\\\":24.128806992143474,\\\"lng\\\":88.97751582031253},{\\\"lat\\\":24.128806992143474,\\\"lng\\\":88.83469355468753},{\\\"lat\\\":24.219013084144738,\\\"lng\\\":88.73581660156253},{\\\"lat\\\":24.284122237091808,\\\"lng\\\":88.74130976562503},{\\\"lat\\\":24.339188539652735,\\\"lng\\\":88.68637812500003},{\\\"lat\\\":24.344193381198895,\\\"lng\\\":88.53806269531253},{\\\"lat\\\":24.379221732157642,\\\"lng\\\":88.41171992187503},{\\\"lat\\\":24.459250084900294,\\\"lng\\\":88.30185664062503}]', NULL, NULL, NULL),
(5, 'Mawna-1', 4, 5, '{\"lat\":23.6850,\"lng\": 90.3563,\"zoom\":7}', '[{\\\"lat\\\":24.674074156954287,\\\"lng\\\":88.02170527343753},{\\\"lat\\\":24.813761167171297,\\\"lng\\\":88.10959589843753},{\\\"lat\\\":24.873578919363887,\\\"lng\\\":88.15903437500003},{\\\"lat\\\":24.933367731897114,\\\"lng\\\":88.15354121093753},{\\\"lat\\\":24.968231154396594,\\\"lng\\\":88.21945917968753},{\\\"lat\\\":24.888528837587863,\\\"lng\\\":88.26889765625003},{\\\"lat\\\":24.888528837587863,\\\"lng\\\":88.34030878906253},{\\\"lat\\\":24.933367731897114,\\\"lng\\\":88.32932246093753},{\\\"lat\\\":24.968231154396594,\\\"lng\\\":88.36777460937503},{\\\"lat\\\":24.96325126982539,\\\"lng\\\":88.41171992187503},{\\\"lat\\\":25.097637329824423,\\\"lng\\\":88.44467890625003},{\\\"lat\\\":25.137427126442102,\\\"lng\\\":88.46115839843753},{\\\"lat\\\":25.202057894171094,\\\"lng\\\":88.44467890625003},{\\\"lat\\\":25.197087513283403,\\\"lng\\\":88.51609003906253},{\\\"lat\\\":25.177203961238682,\\\"lng\\\":88.56003535156253},{\\\"lat\\\":25.207028072151154,\\\"lng\\\":88.74130976562503},{\\\"lat\\\":25.16726096852795,\\\"lng\\\":88.81272089843753},{\\\"lat\\\":25.207028072151154,\\\"lng\\\":88.84567988281253},{\\\"lat\\\":25.17223256624973,\\\"lng\\\":88.95005000000003},{\\\"lat\\\":25.221937388354235,\\\"lng\\\":88.97202265625003},{\\\"lat\\\":25.276589242277154,\\\"lng\\\":88.99948847656253},{\\\"lat\\\":25.2269067544126,\\\"lng\\\":89.16428339843753},{\\\"lat\\\":25.152344959257448,\\\"lng\\\":89.21372187500003},{\\\"lat\\\":25.11256002156972,\\\"lng\\\":89.26316035156253},{\\\"lat\\\":25.11256002156972,\\\"lng\\\":89.34006464843753},{\\\"lat\\\":25.072762131415075,\\\"lng\\\":89.37851679687503},{\\\"lat\\\":25.047881879303535,\\\"lng\\\":89.54880488281253},{\\\"lat\\\":25.03295130378438,\\\"lng\\\":89.60373652343753},{\\\"lat\\\":24.853642881624296,\\\"lng\\\":89.60373652343753},{\\\"lat\\\":24.624147946786504,\\\"lng\\\":89.65866816406253},{\\\"lat\\\":24.40423604332974,\\\"lng\\\":89.74655878906253},{\\\"lat\\\":24.274107614347415,\\\"lng\\\":89.74655878906253},{\\\"lat\\\":24.033520391868528,\\\"lng\\\":89.72458613281253},{\\\"lat\\\":23.83268612236187,\\\"lng\\\":89.75205195312503},{\\\"lat\\\":23.817610972124626,\\\"lng\\\":89.63669550781253},{\\\"lat\\\":23.87790105827056,\\\"lng\\\":89.42246210937503},{\\\"lat\\\":23.958244164879513,\\\"lng\\\":89.18076289062503},{\\\"lat\\\":24.053586612693188,\\\"lng\\\":89.02695429687503},{\\\"lat\\\":24.128806992143474,\\\"lng\\\":88.97751582031253},{\\\"lat\\\":24.128806992143474,\\\"lng\\\":88.83469355468753},{\\\"lat\\\":24.219013084144738,\\\"lng\\\":88.73581660156253},{\\\"lat\\\":24.284122237091808,\\\"lng\\\":88.74130976562503},{\\\"lat\\\":24.339188539652735,\\\"lng\\\":88.68637812500003},{\\\"lat\\\":24.344193381198895,\\\"lng\\\":88.53806269531253},{\\\"lat\\\":24.379221732157642,\\\"lng\\\":88.41171992187503},{\\\"lat\\\":24.459250084900294,\\\"lng\\\":88.30185664062503}]', NULL, NULL, NULL),
(6, 'South Zone', 1, 2, '{\"lat\":24.674074156954287,\"lng\": 88.02170527343753,\"zoom\":7}', '[{\\\"lat\\\":24.674074156954287,\\\"lng\\\":88.02170527343753},{\\\"lat\\\":24.813761167171297,\\\"lng\\\":88.10959589843753},{\\\"lat\\\":24.873578919363887,\\\"lng\\\":88.15903437500003},{\\\"lat\\\":24.933367731897114,\\\"lng\\\":88.15354121093753},{\\\"lat\\\":24.968231154396594,\\\"lng\\\":88.21945917968753},{\\\"lat\\\":24.888528837587863,\\\"lng\\\":88.26889765625003},{\\\"lat\\\":24.888528837587863,\\\"lng\\\":88.34030878906253},{\\\"lat\\\":24.933367731897114,\\\"lng\\\":88.32932246093753},{\\\"lat\\\":24.968231154396594,\\\"lng\\\":88.36777460937503},{\\\"lat\\\":24.96325126982539,\\\"lng\\\":88.41171992187503},{\\\"lat\\\":25.097637329824423,\\\"lng\\\":88.44467890625003},{\\\"lat\\\":25.137427126442102,\\\"lng\\\":88.46115839843753},{\\\"lat\\\":25.202057894171094,\\\"lng\\\":88.44467890625003},{\\\"lat\\\":25.197087513283403,\\\"lng\\\":88.51609003906253},{\\\"lat\\\":25.177203961238682,\\\"lng\\\":88.56003535156253},{\\\"lat\\\":25.207028072151154,\\\"lng\\\":88.74130976562503},{\\\"lat\\\":25.16726096852795,\\\"lng\\\":88.81272089843753},{\\\"lat\\\":25.207028072151154,\\\"lng\\\":88.84567988281253},{\\\"lat\\\":25.17223256624973,\\\"lng\\\":88.95005000000003},{\\\"lat\\\":25.221937388354235,\\\"lng\\\":88.97202265625003},{\\\"lat\\\":25.276589242277154,\\\"lng\\\":88.99948847656253},{\\\"lat\\\":25.2269067544126,\\\"lng\\\":89.16428339843753},{\\\"lat\\\":25.152344959257448,\\\"lng\\\":89.21372187500003},{\\\"lat\\\":25.11256002156972,\\\"lng\\\":89.26316035156253},{\\\"lat\\\":25.11256002156972,\\\"lng\\\":89.34006464843753},{\\\"lat\\\":25.072762131415075,\\\"lng\\\":89.37851679687503},{\\\"lat\\\":25.047881879303535,\\\"lng\\\":89.54880488281253},{\\\"lat\\\":25.03295130378438,\\\"lng\\\":89.60373652343753},{\\\"lat\\\":24.853642881624296,\\\"lng\\\":89.60373652343753},{\\\"lat\\\":24.624147946786504,\\\"lng\\\":89.65866816406253},{\\\"lat\\\":24.40423604332974,\\\"lng\\\":89.74655878906253},{\\\"lat\\\":24.274107614347415,\\\"lng\\\":89.74655878906253},{\\\"lat\\\":24.033520391868528,\\\"lng\\\":89.72458613281253},{\\\"lat\\\":23.83268612236187,\\\"lng\\\":89.75205195312503},{\\\"lat\\\":23.817610972124626,\\\"lng\\\":89.63669550781253},{\\\"lat\\\":23.87790105827056,\\\"lng\\\":89.42246210937503},{\\\"lat\\\":23.958244164879513,\\\"lng\\\":89.18076289062503},{\\\"lat\\\":24.053586612693188,\\\"lng\\\":89.02695429687503},{\\\"lat\\\":24.128806992143474,\\\"lng\\\":88.97751582031253},{\\\"lat\\\":24.128806992143474,\\\"lng\\\":88.83469355468753},{\\\"lat\\\":24.219013084144738,\\\"lng\\\":88.73581660156253},{\\\"lat\\\":24.284122237091808,\\\"lng\\\":88.74130976562503},{\\\"lat\\\":24.339188539652735,\\\"lng\\\":88.68637812500003},{\\\"lat\\\":24.344193381198895,\\\"lng\\\":88.53806269531253},{\\\"lat\\\":24.379221732157642,\\\"lng\\\":88.41171992187503},{\\\"lat\\\":24.459250084900294,\\\"lng\\\":88.30185664062503}]', NULL, NULL, NULL),
(7, 'Chittagong', 6, 3, NULL, NULL, NULL, NULL, NULL),
(8, 'Pekua', 7, 4, NULL, NULL, NULL, NULL, NULL),
(9, 'Pekua-3', 8, 5, NULL, NULL, NULL, NULL, NULL),
(10, 'Sylhet', 6, 3, NULL, NULL, NULL, NULL, NULL),
(11, 'Sylhet - A', 10, 4, NULL, NULL, NULL, NULL, NULL),
(12, 'Syl A2', 11, 5, NULL, NULL, NULL, NULL, NULL),
(13, 'Rangpur', 2, 3, NULL, NULL, NULL, NULL, NULL),
(14, 'Kurigram', 13, 4, '{\"lat\":\"25.8136\",\"lng\":\"89.6473\",\"zoom\":8}', '[]', NULL, '2019-03-27 22:26:05', '2019-03-27 22:26:05'),
(15, 'Kurigram 2', 14, 5, '{\"lat\":\"25.7924\",\"lng\":\"89.6247\",\"zoom\":11}', '[{\"lat\":25.73554644065048,\"lng\":89.68307394915644},{\"lat\":25.73430936294802,\"lng\":89.60548300677362},{\"lat\":25.783782424284666,\"lng\":89.50454611712519},{\"lat\":25.823964099415917,\"lng\":89.48051352435175},{\"lat\":25.845594740422573,\"lng\":89.50591940814081},{\"lat\":25.863514275562743,\"lng\":89.57733054095331},{\"lat\":25.865367865553832,\"lng\":89.67277426653925},{\"lat\":25.830144685990156,\"lng\":89.72289938860956},{\"lat\":25.786873806018637,\"lng\":89.73457236224237},{\"lat\":25.763377284326317,\"lng\":89.72770590716425},{\"lat\":25.743587131871994,\"lng\":89.69337363177362},{\"lat\":25.73616497467368,\"lng\":89.67758078509394}]', NULL, '2019-03-27 22:29:14', '2019-03-27 22:29:14'),
(16, 'Valuka', 3, 4, '{\"lat\":\"24.4084\",\"lng\":\"90.3872\",\"zoom\":11}', '[{\"lat\":25.73554644065048,\"lng\":89.68307394915644},{\"lat\":25.73430936294802,\"lng\":89.60548300677362},{\"lat\":25.783782424284666,\"lng\":89.50454611712519},{\"lat\":25.823964099415917,\"lng\":89.48051352435175},{\"lat\":25.845594740422573,\"lng\":89.50591940814081},{\"lat\":25.863514275562743,\"lng\":89.57733054095331},{\"lat\":25.865367865553832,\"lng\":89.67277426653925},{\"lat\":25.830144685990156,\"lng\":89.72289938860956},{\"lat\":25.786873806018637,\"lng\":89.73457236224237},{\"lat\":25.763377284326317,\"lng\":89.72770590716425},{\"lat\":25.743587131871994,\"lng\":89.69337363177362},{\"lat\":25.73616497467368,\"lng\":89.67758078509394},{\"lat\":24.285832790796054,\"lng\":90.38992983091384},{\"lat\":24.28520690843886,\"lng\":90.37894350278884},{\"lat\":24.29834979002052,\"lng\":90.35697084653884},{\"lat\":24.300853041745775,\"lng\":90.33637148130447},{\"lat\":24.292091444685717,\"lng\":90.30821901548416},{\"lat\":24.28395513446985,\"lng\":90.29036623228103},{\"lat\":24.296472318821888,\"lng\":90.26358705747634},{\"lat\":24.325257157555342,\"lng\":90.25191408384353},{\"lat\":24.34652870761823,\"lng\":90.2388678191951},{\"lat\":24.38030558971128,\"lng\":90.23612123716384},{\"lat\":24.42220140119707,\"lng\":90.24779421079666},{\"lat\":24.43908085770824,\"lng\":90.22719484556228},{\"lat\":24.457833159287432,\"lng\":90.21826845396072},{\"lat\":24.499078395780526,\"lng\":90.24230104673416},{\"lat\":24.499703219626955,\"lng\":90.2834997772029},{\"lat\":24.507200863562428,\"lng\":90.42840263823382},{\"lat\":24.490955403231094,\"lng\":90.46751054361869},{\"lat\":24.441581325792864,\"lng\":90.5011561735015},{\"lat\":24.407820823584537,\"lng\":90.5121425016265},{\"lat\":24.372174942272068,\"lng\":90.517635665689},{\"lat\":24.348405437593705,\"lng\":90.53686173990775},{\"lat\":24.31900013968363,\"lng\":90.52381547525931},{\"lat\":24.30961403387519,\"lng\":90.517635665689},{\"lat\":24.308988268788045,\"lng\":90.51076921061087},{\"lat\":24.315245780727835,\"lng\":90.4901698453765},{\"lat\":24.33964712640194,\"lng\":90.45583756998587},{\"lat\":24.3408983507996,\"lng\":90.4352382047515},{\"lat\":24.33276517128809,\"lng\":90.42631181314994},{\"lat\":24.315871514940184,\"lng\":90.42562516764212},{\"lat\":24.304607826741034,\"lng\":90.42081864908744},{\"lat\":24.299601422055677,\"lng\":90.4132655485015},{\"lat\":24.285832790796054,\"lng\":90.40433915689994}]', NULL, '2019-03-27 22:33:18', '2019-03-27 22:33:18'),
(17, 'valuka', 16, 5, '{\"lat\":\"24.4031\",\"lng\":\"90.3869\",\"zoom\":12}', '[{\"lat\":25.73554644065048,\"lng\":89.68307394915644},{\"lat\":25.73430936294802,\"lng\":89.60548300677362},{\"lat\":25.783782424284666,\"lng\":89.50454611712519},{\"lat\":25.823964099415917,\"lng\":89.48051352435175},{\"lat\":25.845594740422573,\"lng\":89.50591940814081},{\"lat\":25.863514275562743,\"lng\":89.57733054095331},{\"lat\":25.865367865553832,\"lng\":89.67277426653925},{\"lat\":25.830144685990156,\"lng\":89.72289938860956},{\"lat\":25.786873806018637,\"lng\":89.73457236224237},{\"lat\":25.763377284326317,\"lng\":89.72770590716425},{\"lat\":25.743587131871994,\"lng\":89.69337363177362},{\"lat\":25.73616497467368,\"lng\":89.67758078509394},{\"lat\":24.285832790796054,\"lng\":90.38992983091384},{\"lat\":24.28520690843886,\"lng\":90.37894350278884},{\"lat\":24.29834979002052,\"lng\":90.35697084653884},{\"lat\":24.300853041745775,\"lng\":90.33637148130447},{\"lat\":24.292091444685717,\"lng\":90.30821901548416},{\"lat\":24.28395513446985,\"lng\":90.29036623228103},{\"lat\":24.296472318821888,\"lng\":90.26358705747634},{\"lat\":24.325257157555342,\"lng\":90.25191408384353},{\"lat\":24.34652870761823,\"lng\":90.2388678191951},{\"lat\":24.38030558971128,\"lng\":90.23612123716384},{\"lat\":24.42220140119707,\"lng\":90.24779421079666},{\"lat\":24.43908085770824,\"lng\":90.22719484556228},{\"lat\":24.457833159287432,\"lng\":90.21826845396072},{\"lat\":24.499078395780526,\"lng\":90.24230104673416},{\"lat\":24.499703219626955,\"lng\":90.2834997772029},{\"lat\":24.507200863562428,\"lng\":90.42840263823382},{\"lat\":24.490955403231094,\"lng\":90.46751054361869},{\"lat\":24.441581325792864,\"lng\":90.5011561735015},{\"lat\":24.407820823584537,\"lng\":90.5121425016265},{\"lat\":24.372174942272068,\"lng\":90.517635665689},{\"lat\":24.348405437593705,\"lng\":90.53686173990775},{\"lat\":24.31900013968363,\"lng\":90.52381547525931},{\"lat\":24.30961403387519,\"lng\":90.517635665689},{\"lat\":24.308988268788045,\"lng\":90.51076921061087},{\"lat\":24.315245780727835,\"lng\":90.4901698453765},{\"lat\":24.33964712640194,\"lng\":90.45583756998587},{\"lat\":24.3408983507996,\"lng\":90.4352382047515},{\"lat\":24.33276517128809,\"lng\":90.42631181314994},{\"lat\":24.315871514940184,\"lng\":90.42562516764212},{\"lat\":24.304607826741034,\"lng\":90.42081864908744},{\"lat\":24.299601422055677,\"lng\":90.4132655485015},{\"lat\":24.285832790796054,\"lng\":90.40433915689994},{\"lat\":24.456849528034596,\"lng\":90.332268359375},{\"lat\":24.46122469768263,\"lng\":90.40573942871094},{\"lat\":24.44747365283918,\"lng\":90.48333037109376},{\"lat\":24.42590649297803,\"lng\":90.5073629638672},{\"lat\":24.343354638635937,\"lng\":90.48230040283204},{\"lat\":24.3396010011586,\"lng\":90.42462218017579},{\"lat\":24.346482584881215,\"lng\":90.32402861328126},{\"lat\":24.37431790157301,\"lng\":90.266350390625},{\"lat\":24.4134021029192,\"lng\":90.25261748046876},{\"lat\":24.40245974538323,\"lng\":90.3872}]', NULL, '2019-03-27 22:35:15', '2019-03-27 22:35:15'),
(18, 'Trishal', 16, 5, '{\"lat\":\"24.5855\",\"lng\":\"90.3991\",\"zoom\":9}', '[{\"lat\":24.44678239241039,\"lng\":90.43204123695068},{\"lat\":24.484281911666866,\"lng\":90.28235251624756},{\"lat\":24.565492521927965,\"lng\":90.20544821937256},{\"lat\":24.62917480875405,\"lng\":90.22879416663818},{\"lat\":24.707796378615114,\"lng\":90.40182883460693},{\"lat\":24.680346858261597,\"lng\":90.53915793616943},{\"lat\":24.530515929053575,\"lng\":90.55563742835693},{\"lat\":24.47303322852382,\"lng\":90.49521262366943}]', NULL, '2019-03-27 22:38:30', '2019-03-27 22:38:30'),
(19, 'Mawna-3', 4, 5, '{\"lat\":\"24.2264\",\"lng\":\"90.4094\",\"zoom\":11}', '[{\"lat\":24.44678239241039,\"lng\":90.43204123695068},{\"lat\":24.484281911666866,\"lng\":90.28235251624756},{\"lat\":24.565492521927965,\"lng\":90.20544821937256},{\"lat\":24.62917480875405,\"lng\":90.22879416663818},{\"lat\":24.707796378615114,\"lng\":90.40182883460693},{\"lat\":24.680346858261597,\"lng\":90.53915793616943},{\"lat\":24.530515929053575,\"lng\":90.55563742835693},{\"lat\":24.47303322852382,\"lng\":90.49521262366943},{\"lat\":24.1036606986084,\"lng\":90.43046495479507},{\"lat\":24.114942161901443,\"lng\":90.33021471065445},{\"lat\":24.12058252072775,\"lng\":90.25743028682632},{\"lat\":24.261510581303718,\"lng\":90.21348497432632},{\"lat\":24.284670494487447,\"lng\":90.26017686885757},{\"lat\":24.323469528755858,\"lng\":90.38857957881851},{\"lat\":24.2176829872977,\"lng\":90.61817879833382},{\"lat\":24.201400323646396,\"lng\":90.6119989887635},{\"lat\":24.16945521208985,\"lng\":90.56118722118538},{\"lat\":24.12747595501036,\"lng\":90.52891488231819},{\"lat\":24.10992830094122,\"lng\":90.50488228954475},{\"lat\":24.1036606986084,\"lng\":90.48290963329475},{\"lat\":24.10178035808802,\"lng\":90.44514413036507}]', NULL, '2019-03-27 22:40:56', '2019-03-27 22:40:56'),
(20, 'Nageswari', 14, 5, '{\"lat\":\"25.9884\",\"lng\":\"89.7057\",\"zoom\":11}', '[{\"lat\":24.44678239241039,\"lng\":90.43204123695068},{\"lat\":24.484281911666866,\"lng\":90.28235251624756},{\"lat\":24.565492521927965,\"lng\":90.20544821937256},{\"lat\":24.62917480875405,\"lng\":90.22879416663818},{\"lat\":24.707796378615114,\"lng\":90.40182883460693},{\"lat\":24.680346858261597,\"lng\":90.53915793616943},{\"lat\":24.530515929053575,\"lng\":90.55563742835693},{\"lat\":24.47303322852382,\"lng\":90.49521262366943},{\"lat\":24.1036606986084,\"lng\":90.43046495479507},{\"lat\":24.114942161901443,\"lng\":90.33021471065445},{\"lat\":24.12058252072775,\"lng\":90.25743028682632},{\"lat\":24.261510581303718,\"lng\":90.21348497432632},{\"lat\":24.284670494487447,\"lng\":90.26017686885757},{\"lat\":24.323469528755858,\"lng\":90.38857957881851},{\"lat\":24.2176829872977,\"lng\":90.61817879833382},{\"lat\":24.201400323646396,\"lng\":90.6119989887635},{\"lat\":24.16945521208985,\"lng\":90.56118722118538},{\"lat\":24.12747595501036,\"lng\":90.52891488231819},{\"lat\":24.10992830094122,\"lng\":90.50488228954475},{\"lat\":24.1036606986084,\"lng\":90.48290963329475},{\"lat\":24.10178035808802,\"lng\":90.44514413036507},{\"lat\":25.903143933092487,\"lng\":89.69610455792213},{\"lat\":25.932170420493318,\"lng\":89.64597943585181},{\"lat\":25.95625080227578,\"lng\":89.60752728741431},{\"lat\":25.986498658619805,\"lng\":89.58349469464088},{\"lat\":25.99760816204424,\"lng\":89.58280804913306},{\"lat\":26.022909220331588,\"lng\":89.58143475811744},{\"lat\":26.03710010939647,\"lng\":89.58624127667213},{\"lat\":26.051906163157888,\"lng\":89.60409405987525},{\"lat\":26.061158997111484,\"lng\":89.634306462219},{\"lat\":26.0568410988558,\"lng\":89.70983746807838},{\"lat\":26.048821722823266,\"lng\":89.78330853741431},{\"lat\":26.034632252000442,\"lng\":89.79635480206275},{\"lat\":25.996373824641438,\"lng\":89.82794049542213},{\"lat\":25.972918950630056,\"lng\":89.86295941632056},{\"lat\":25.958102935360383,\"lng\":89.84167340557838},{\"lat\":25.938345346743574,\"lng\":89.81626752178931},{\"lat\":25.915496503275875,\"lng\":89.77300885479713}]', NULL, '2019-03-27 22:44:31', '2019-03-27 22:44:31'),
(21, 'Gaibandha', 13, 4, '{\"lat\":\"25.3263\",\"lng\":\"89.5378\",\"zoom\":9}', '[{\"lat\":24.44678239241039,\"lng\":90.43204123695068},{\"lat\":24.484281911666866,\"lng\":90.28235251624756},{\"lat\":24.565492521927965,\"lng\":90.20544821937256},{\"lat\":24.62917480875405,\"lng\":90.22879416663818},{\"lat\":24.707796378615114,\"lng\":90.40182883460693},{\"lat\":24.680346858261597,\"lng\":90.53915793616943},{\"lat\":24.530515929053575,\"lng\":90.55563742835693},{\"lat\":24.47303322852382,\"lng\":90.49521262366943},{\"lat\":24.1036606986084,\"lng\":90.43046495479507},{\"lat\":24.114942161901443,\"lng\":90.33021471065445},{\"lat\":24.12058252072775,\"lng\":90.25743028682632},{\"lat\":24.261510581303718,\"lng\":90.21348497432632},{\"lat\":24.284670494487447,\"lng\":90.26017686885757},{\"lat\":24.323469528755858,\"lng\":90.38857957881851},{\"lat\":24.2176829872977,\"lng\":90.61817879833382},{\"lat\":24.201400323646396,\"lng\":90.6119989887635},{\"lat\":24.16945521208985,\"lng\":90.56118722118538},{\"lat\":24.12747595501036,\"lng\":90.52891488231819},{\"lat\":24.10992830094122,\"lng\":90.50488228954475},{\"lat\":24.1036606986084,\"lng\":90.48290963329475},{\"lat\":24.10178035808802,\"lng\":90.44514413036507},{\"lat\":25.903143933092487,\"lng\":89.69610455792213},{\"lat\":25.932170420493318,\"lng\":89.64597943585181},{\"lat\":25.95625080227578,\"lng\":89.60752728741431},{\"lat\":25.986498658619805,\"lng\":89.58349469464088},{\"lat\":25.99760816204424,\"lng\":89.58280804913306},{\"lat\":26.022909220331588,\"lng\":89.58143475811744},{\"lat\":26.03710010939647,\"lng\":89.58624127667213},{\"lat\":26.051906163157888,\"lng\":89.60409405987525},{\"lat\":26.061158997111484,\"lng\":89.634306462219},{\"lat\":26.0568410988558,\"lng\":89.70983746807838},{\"lat\":26.048821722823266,\"lng\":89.78330853741431},{\"lat\":26.034632252000442,\"lng\":89.79635480206275},{\"lat\":25.996373824641438,\"lng\":89.82794049542213},{\"lat\":25.972918950630056,\"lng\":89.86295941632056},{\"lat\":25.958102935360383,\"lng\":89.84167340557838},{\"lat\":25.938345346743574,\"lng\":89.81626752178931},{\"lat\":25.915496503275875,\"lng\":89.77300885479713},{\"lat\":25.080223975817088,\"lng\":89.64769476350398},{\"lat\":25.050368885596978,\"lng\":89.54332464631648},{\"lat\":25.122506225374817,\"lng\":89.32634466584773},{\"lat\":25.117532601879596,\"lng\":89.26042669709773},{\"lat\":25.241812389875697,\"lng\":89.16429632600398},{\"lat\":25.3882992055828,\"lng\":89.05168646272273},{\"lat\":25.494948985572485,\"lng\":89.12309759553523},{\"lat\":25.613888171227696,\"lng\":89.25493353303523},{\"lat\":25.594073174930568,\"lng\":89.44719427522273},{\"lat\":25.522216306297008,\"lng\":89.59276312287898},{\"lat\":25.48999062576345,\"lng\":89.67790716584773},{\"lat\":25.35603767224151,\"lng\":89.77678411897273},{\"lat\":25.179688337787194,\"lng\":89.72459906037898}]', NULL, '2019-03-27 22:46:23', '2019-03-27 22:46:23'),
(22, 'Bonarpara', 21, 5, '{\"lat\":\"25.4525\",\"lng\":\"89.6053\",\"zoom\":9}', '[{\"lat\":24.44678239241039,\"lng\":90.43204123695068},{\"lat\":24.484281911666866,\"lng\":90.28235251624756},{\"lat\":24.565492521927965,\"lng\":90.20544821937256},{\"lat\":24.62917480875405,\"lng\":90.22879416663818},{\"lat\":24.707796378615114,\"lng\":90.40182883460693},{\"lat\":24.680346858261597,\"lng\":90.53915793616943},{\"lat\":24.530515929053575,\"lng\":90.55563742835693},{\"lat\":24.47303322852382,\"lng\":90.49521262366943},{\"lat\":24.1036606986084,\"lng\":90.43046495479507},{\"lat\":24.114942161901443,\"lng\":90.33021471065445},{\"lat\":24.12058252072775,\"lng\":90.25743028682632},{\"lat\":24.261510581303718,\"lng\":90.21348497432632},{\"lat\":24.284670494487447,\"lng\":90.26017686885757},{\"lat\":24.323469528755858,\"lng\":90.38857957881851},{\"lat\":24.2176829872977,\"lng\":90.61817879833382},{\"lat\":24.201400323646396,\"lng\":90.6119989887635},{\"lat\":24.16945521208985,\"lng\":90.56118722118538},{\"lat\":24.12747595501036,\"lng\":90.52891488231819},{\"lat\":24.10992830094122,\"lng\":90.50488228954475},{\"lat\":24.1036606986084,\"lng\":90.48290963329475},{\"lat\":24.10178035808802,\"lng\":90.44514413036507},{\"lat\":25.903143933092487,\"lng\":89.69610455792213},{\"lat\":25.932170420493318,\"lng\":89.64597943585181},{\"lat\":25.95625080227578,\"lng\":89.60752728741431},{\"lat\":25.986498658619805,\"lng\":89.58349469464088},{\"lat\":25.99760816204424,\"lng\":89.58280804913306},{\"lat\":26.022909220331588,\"lng\":89.58143475811744},{\"lat\":26.03710010939647,\"lng\":89.58624127667213},{\"lat\":26.051906163157888,\"lng\":89.60409405987525},{\"lat\":26.061158997111484,\"lng\":89.634306462219},{\"lat\":26.0568410988558,\"lng\":89.70983746807838},{\"lat\":26.048821722823266,\"lng\":89.78330853741431},{\"lat\":26.034632252000442,\"lng\":89.79635480206275},{\"lat\":25.996373824641438,\"lng\":89.82794049542213},{\"lat\":25.972918950630056,\"lng\":89.86295941632056},{\"lat\":25.958102935360383,\"lng\":89.84167340557838},{\"lat\":25.938345346743574,\"lng\":89.81626752178931},{\"lat\":25.915496503275875,\"lng\":89.77300885479713},{\"lat\":25.080223975817088,\"lng\":89.64769476350398},{\"lat\":25.050368885596978,\"lng\":89.54332464631648},{\"lat\":25.122506225374817,\"lng\":89.32634466584773},{\"lat\":25.117532601879596,\"lng\":89.26042669709773},{\"lat\":25.241812389875697,\"lng\":89.16429632600398},{\"lat\":25.3882992055828,\"lng\":89.05168646272273},{\"lat\":25.494948985572485,\"lng\":89.12309759553523},{\"lat\":25.613888171227696,\"lng\":89.25493353303523},{\"lat\":25.594073174930568,\"lng\":89.44719427522273},{\"lat\":25.522216306297008,\"lng\":89.59276312287898},{\"lat\":25.48999062576345,\"lng\":89.67790716584773},{\"lat\":25.35603767224151,\"lng\":89.77678411897273},{\"lat\":25.179688337787194,\"lng\":89.72459906037898},{\"lat\":25.64829549292413,\"lng\":89.55312654398472},{\"lat\":25.554172113036785,\"lng\":89.82229158304722},{\"lat\":25.24651905446955,\"lng\":89.83877107523472},{\"lat\":25.142136580974302,\"lng\":89.48720857523472},{\"lat\":25.3508119310453,\"lng\":89.33339998148472},{\"lat\":25.489729263211448,\"lng\":89.31692048929722}]', NULL, '2019-03-27 22:53:11', '2019-03-27 22:53:11'),
(23, 'Beanibazar-1', 11, 5, '{\"lat\":\"24.7848\",\"lng\":\"92.1265\",\"zoom\":11}', '[{\"lat\":24.68818517657159,\"lng\":92.23222880969763},{\"lat\":24.725612486004266,\"lng\":92.28166728626013},{\"lat\":24.75991096611011,\"lng\":92.27892070422888},{\"lat\":24.788589698040283,\"lng\":92.27754741321326},{\"lat\":24.83221852779379,\"lng\":92.2576346934867},{\"lat\":24.842811782187173,\"lng\":92.23840861926794},{\"lat\":24.857765421242988,\"lng\":92.23154216418982},{\"lat\":24.873963156715014,\"lng\":92.22261577258826},{\"lat\":24.90759782333331,\"lng\":92.13266521106482},{\"lat\":24.900124244767763,\"lng\":92.04134135852576},{\"lat\":24.88268413508814,\"lng\":91.99121623645544},{\"lat\":24.85402718093692,\"lng\":91.95139079700232},{\"lat\":24.786719547927095,\"lng\":91.93491130481482},{\"lat\":24.739956637841228,\"lng\":91.93491130481482},{\"lat\":24.70877158880995,\"lng\":91.95413737903357},{\"lat\":24.691304548594672,\"lng\":92.06743388782263},{\"lat\":24.679450519586563,\"lng\":92.16356425891638},{\"lat\":24.679450519586563,\"lng\":92.23978191028357}]', NULL, '2019-03-28 00:05:06', '2019-03-28 00:05:06'),
(24, 'Hobigonj', 10, 4, '{\"lat\":\"24.3812\",\"lng\":\"91.4190\",\"zoom\":10}', '[{\"lat\":24.113207667755585,\"lng\":91.3915307890702},{\"lat\":24.093150774183282,\"lng\":91.4684350859452},{\"lat\":24.074344584509053,\"lng\":91.5508325468827},{\"lat\":24.090643441653146,\"lng\":91.59340456836708},{\"lat\":24.109447239493978,\"lng\":91.64284304492958},{\"lat\":24.147046549597658,\"lng\":91.6387231718827},{\"lat\":24.189645732193576,\"lng\":91.6497095000077},{\"lat\":24.219707181533153,\"lng\":91.65245608203895},{\"lat\":24.233482975642726,\"lng\":91.67030886524208},{\"lat\":24.174612349623583,\"lng\":91.68129519336708},{\"lat\":24.160830193287563,\"lng\":91.70601443164833},{\"lat\":24.14078076549645,\"lng\":91.76094607227333},{\"lat\":24.253517833078575,\"lng\":91.74446658008583},{\"lat\":24.217202331586044,\"lng\":91.81175783985145},{\"lat\":24.22722143580773,\"lng\":91.8474634062577},{\"lat\":24.1833820380477,\"lng\":91.85707644336708},{\"lat\":24.154565085045665,\"lng\":91.88454226367958},{\"lat\":24.143287115993846,\"lng\":91.89964846485145},{\"lat\":24.170853727256304,\"lng\":91.91200808399208},{\"lat\":24.263534078476265,\"lng\":91.93947390430458},{\"lat\":24.338630746207034,\"lng\":91.91612795703895},{\"lat\":24.4999377761805,\"lng\":91.81725100391395},{\"lat\":24.529925612040945,\"lng\":91.37779787891395},{\"lat\":24.35990005032322,\"lng\":91.1553247343827},{\"lat\":24.18087647428046,\"lng\":91.24733523242958}]', NULL, '2019-03-28 00:07:59', '2019-03-28 00:07:59'),
(25, 'Shaistagonj', 24, 5, '{\"lat\":\"24.2795\",\"lng\":\"91.4612\",\"zoom\":10}', '[{\"lat\":24.163050939176728,\"lng\":91.37746126706384},{\"lat\":24.145508166818708,\"lng\":91.46672518307946},{\"lat\":24.136735877512596,\"lng\":91.55873568112634},{\"lat\":24.163050939176728,\"lng\":91.62465364987634},{\"lat\":24.215664794398876,\"lng\":91.62602694089196},{\"lat\":24.283279259179615,\"lng\":91.64937288815759},{\"lat\":24.337094678051,\"lng\":91.60542757565759},{\"lat\":24.364619313662875,\"lng\":91.51204378659509},{\"lat\":24.35836424019179,\"lng\":91.41316683347009},{\"lat\":24.294544840606004,\"lng\":91.30879671628259},{\"lat\":24.243215766665053,\"lng\":91.30330355222009},{\"lat\":24.195623980185736,\"lng\":91.32390291745446}]', NULL, '2019-03-28 00:10:14', '2019-03-28 00:10:14'),
(26, 'Hobigonj-3', 24, 5, '{\"lat\":\"24.3637\",\"lng\":\"91.3805\",\"zoom\":10}', '[{\"lat\":24.163050939176728,\"lng\":91.37746126706384},{\"lat\":24.145508166818708,\"lng\":91.46672518307946},{\"lat\":24.136735877512596,\"lng\":91.55873568112634},{\"lat\":24.163050939176728,\"lng\":91.62465364987634},{\"lat\":24.215664794398876,\"lng\":91.62602694089196},{\"lat\":24.283279259179615,\"lng\":91.64937288815759},{\"lat\":24.337094678051,\"lng\":91.60542757565759},{\"lat\":24.364619313662875,\"lng\":91.51204378659509},{\"lat\":24.35836424019179,\"lng\":91.41316683347009},{\"lat\":24.294544840606004,\"lng\":91.30879671628259},{\"lat\":24.243215766665053,\"lng\":91.30330355222009},{\"lat\":24.195623980185736,\"lng\":91.32390291745446},{\"lat\":24.527461079326226,\"lng\":91.36269506835936},{\"lat\":24.44622588458872,\"lng\":91.25832495117186},{\"lat\":24.35743219104724,\"lng\":91.14846166992186},{\"lat\":24.259812331597328,\"lng\":91.21575292968748},{\"lat\":24.16712927182427,\"lng\":91.25695166015623},{\"lat\":24.262316342954836,\"lng\":91.37230810546873},{\"lat\":24.30863165233708,\"lng\":91.46981176757811},{\"lat\":24.381199999999996,\"lng\":91.52611669921873},{\"lat\":24.48122593801793,\"lng\":91.51925024414061},{\"lat\":24.50247122283945,\"lng\":91.47942480468748},{\"lat\":24.527461079326226,\"lng\":91.37230810546873}]', NULL, '2019-03-28 00:17:21', '2019-03-28 00:17:21'),
(27, 'Prem Bazar', 8, 5, '{\"lat\":\"22.3559\",\"lng\":\"91.9306\",\"zoom\":10}', '[{\"lat\":22.405011885522107,\"lng\":91.74249284730763},{\"lat\":22.474823701897314,\"lng\":91.850982837542},{\"lat\":22.493857187510553,\"lng\":91.99792497621388},{\"lat\":22.411359865425162,\"lng\":92.06384294496388},{\"lat\":22.294510673513862,\"lng\":92.12426774965138},{\"lat\":22.20172377823069,\"lng\":91.982818775042},{\"lat\":22.205538148840514,\"lng\":91.80291765199513}]', NULL, '2019-03-28 00:20:48', '2019-03-28 00:20:48'),
(28, 'Eidgah', 7, 4, '{\"lat\":\"22.6422\",\"lng\":\"91.9475\",\"zoom\":9}', '[{\"lat\":22.62955351798313,\"lng\":91.59316129027582},{\"lat\":22.854994221417858,\"lng\":91.69203824340082},{\"lat\":22.94860708192471,\"lng\":91.96669644652582},{\"lat\":22.756251374083806,\"lng\":92.45833463011957},{\"lat\":22.56616072064671,\"lng\":92.30727261840082},{\"lat\":22.39104548687125,\"lng\":92.24410123168207},{\"lat\":22.319921182182103,\"lng\":91.94472379027582},{\"lat\":22.307216594722032,\"lng\":91.76070279418207},{\"lat\":22.53318493765811,\"lng\":91.69203824340082}]', NULL, '2019-03-28 00:22:38', '2019-03-28 00:22:38'),
(29, 'Cox Bazar-6', 28, 5, '{\"lat\":\"22.5078\",\"lng\":\"91.9393\",\"zoom\":9}', '[{\"lat\":22.614313331199693,\"lng\":91.69756103515624},{\"lat\":22.634595106006113,\"lng\":91.89256835937499},{\"lat\":22.652339203715854,\"lng\":92.12602783203124},{\"lat\":22.454489999985178,\"lng\":92.23314453124999},{\"lat\":22.38339813695337,\"lng\":92.13152099609374},{\"lat\":22.342757890703634,\"lng\":91.99144531249999},{\"lat\":22.41387053410391,\"lng\":91.75798583984374},{\"lat\":22.50778499045159,\"lng\":91.71404052734374},{\"lat\":22.548376917035757,\"lng\":91.70854736328124}]', NULL, '2019-03-31 06:02:40', '2019-03-31 06:02:40'),
(30, 'Eidgah-1', 28, 5, '{\"lat\":\"22.7385\",\"lng\":\"91.8788\",\"zoom\":9}', '[{\"lat\":22.614313331199693,\"lng\":91.69756103515624},{\"lat\":22.634595106006113,\"lng\":91.89256835937499},{\"lat\":22.652339203715854,\"lng\":92.12602783203124},{\"lat\":22.454489999985178,\"lng\":92.23314453124999},{\"lat\":22.38339813695337,\"lng\":92.13152099609374},{\"lat\":22.342757890703634,\"lng\":91.99144531249999},{\"lat\":22.41387053410391,\"lng\":91.75798583984374},{\"lat\":22.50778499045159,\"lng\":91.71404052734374},{\"lat\":22.548376917035757,\"lng\":91.70854736328124},{\"lat\":22.64726969543483,\"lng\":91.76073242187499},{\"lat\":22.741025268656077,\"lng\":91.72502685546874},{\"lat\":22.794209318262354,\"lng\":91.72502685546874},{\"lat\":22.842310351686024,\"lng\":91.81566406249999},{\"lat\":22.865089118502848,\"lng\":91.90904785156249},{\"lat\":22.794209318262354,\"lng\":92.12328124999999},{\"lat\":22.629524942830226,\"lng\":92.00243164062499},{\"lat\":22.601635702920202,\"lng\":91.83214355468749}]', NULL, '2019-03-31 06:07:55', '2019-03-31 06:07:55'),
(31, 'Sundorgonj-2', 21, 5, '{\"lat\":\"25.5532\",\"lng\":\"89.5021\",\"zoom\":10}', '[{\"lat\":22.614313331199693,\"lng\":91.69756103515624},{\"lat\":22.634595106006113,\"lng\":91.89256835937499},{\"lat\":22.652339203715854,\"lng\":92.12602783203124},{\"lat\":22.454489999985178,\"lng\":92.23314453124999},{\"lat\":22.38339813695337,\"lng\":92.13152099609374},{\"lat\":22.342757890703634,\"lng\":91.99144531249999},{\"lat\":22.41387053410391,\"lng\":91.75798583984374},{\"lat\":22.50778499045159,\"lng\":91.71404052734374},{\"lat\":22.548376917035757,\"lng\":91.70854736328124},{\"lat\":22.64726969543483,\"lng\":91.76073242187499},{\"lat\":22.741025268656077,\"lng\":91.72502685546874},{\"lat\":22.794209318262354,\"lng\":91.72502685546874},{\"lat\":22.842310351686024,\"lng\":91.81566406249999},{\"lat\":22.865089118502848,\"lng\":91.90904785156249},{\"lat\":22.794209318262354,\"lng\":92.12328124999999},{\"lat\":22.629524942830226,\"lng\":92.00243164062499},{\"lat\":22.601635702920202,\"lng\":91.83214355468749},{\"lat\":25.43052416332574,\"lng\":89.50758759765631},{\"lat\":25.454086195474925,\"lng\":89.39909760742194},{\"lat\":25.503675397224455,\"lng\":89.33867280273444},{\"lat\":25.56315542123945,\"lng\":89.30022065429694},{\"lat\":25.60279237307851,\"lng\":89.31670014648444},{\"lat\":25.63994008639562,\"lng\":89.36888520507819},{\"lat\":25.648606223757028,\"lng\":89.50484101562506},{\"lat\":25.611461205885714,\"lng\":89.58723847656256},{\"lat\":25.538375662684828,\"lng\":89.62294404296881},{\"lat\":25.482602485546582,\"lng\":89.60509125976569},{\"lat\":25.440445580804628,\"lng\":89.55015961914069}]', NULL, '2019-03-31 06:10:05', '2019-03-31 06:10:05');

-- --------------------------------------------------------

--
-- Table structure for table `location_levels`
--

CREATE TABLE `location_levels` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `location_levels`
--

INSERT INTO `location_levels` (`id`, `name`, `created_at`, `updated_at`) VALUES
(1, 'HQ', '2019-03-11 02:48:04', NULL),
(2, '	\r\nZone', '2019-03-11 02:48:04', NULL),
(3, 'Region', '2019-03-11 02:48:04', NULL),
(4, 'Area', '2019-03-11 02:48:04', NULL),
(5, 'Territory', '2019-03-11 02:48:04', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `meetings`
--

CREATE TABLE `meetings` (
  `id` int(10) UNSIGNED NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `from_date` datetime NOT NULL,
  `to_date` datetime NOT NULL,
  `agenda` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `repeat` tinyint(4) NOT NULL DEFAULT 0,
  `published` tinyint(4) NOT NULL DEFAULT 0,
  `meeting_type` tinyint(4) NOT NULL DEFAULT 0,
  `meeting_status` tinyint(4) NOT NULL DEFAULT 0,
  `address` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lat_lng` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `image` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remarks` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_by` int(10) UNSIGNED NOT NULL,
  `created_for` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `meetings`
--

INSERT INTO `meetings` (`id`, `title`, `from_date`, `to_date`, `agenda`, `repeat`, `published`, `meeting_type`, `meeting_status`, `address`, `lat_lng`, `file`, `image`, `remarks`, `created_by`, `created_for`, `created_at`, `updated_at`) VALUES
(1, 'title', '2019-03-05 00:00:00', '2019-03-05 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-03-11 03:07:30', '2019-03-11 03:07:30'),
(2, 'title', '2019-03-06 00:00:00', '2019-03-06 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-03-11 03:07:30', '2019-03-11 03:07:30'),
(3, 'title', '2019-03-07 00:00:00', '2019-03-07 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-03-11 03:07:30', '2019-03-11 03:07:30'),
(4, '1st March meeting', '2019-03-31 19:23:00', '2019-03-31 22:23:00', 'Test', 0, 1, 0, 0, NULL, '23.7592041, 90.390069', NULL, 'meeting/img_5ca0bfa9f41bc.png', NULL, 1, 1, '2019-03-31 13:24:58', '2019-03-31 13:24:58'),
(5, '54', '2019-03-01 00:00:00', '2019-03-01 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(6, '54', '2019-03-02 00:00:00', '2019-03-02 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(7, '54', '2019-03-03 00:00:00', '2019-03-03 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(8, '54', '2019-03-04 00:00:00', '2019-03-04 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(9, '54', '2019-03-05 00:00:00', '2019-03-05 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(10, '54', '2019-03-06 00:00:00', '2019-03-06 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(11, '54', '2019-03-07 00:00:00', '2019-03-07 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(12, '54', '2019-03-08 00:00:00', '2019-03-08 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(13, '54', '2019-03-09 00:00:00', '2019-03-09 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(14, '54', '2019-03-10 00:00:00', '2019-03-10 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(15, '54', '2019-03-11 00:00:00', '2019-03-11 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(16, '54', '2019-03-12 00:00:00', '2019-03-12 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(17, '54', '2019-03-13 00:00:00', '2019-03-13 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(18, '54', '2019-03-14 00:00:00', '2019-03-14 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(19, '54', '2019-03-15 00:00:00', '2019-03-15 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(20, '54', '2019-03-16 00:00:00', '2019-03-16 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(21, '54', '2019-03-17 00:00:00', '2019-03-17 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(22, '54', '2019-03-18 00:00:00', '2019-03-18 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(23, '54', '2019-03-19 00:00:00', '2019-03-19 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(24, '54', '2019-03-20 00:00:00', '2019-03-20 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(25, '54', '2019-03-21 00:00:00', '2019-03-21 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(26, '54', '2019-03-22 00:00:00', '2019-03-22 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(27, '54', '2019-03-23 00:00:00', '2019-03-23 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(28, '54', '2019-03-24 00:00:00', '2019-03-24 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(29, '54', '2019-03-25 00:00:00', '2019-03-25 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(30, '54', '2019-03-26 00:00:00', '2019-03-26 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(31, '54', '2019-03-27 00:00:00', '2019-03-27 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(32, '54', '2019-03-28 00:00:00', '2019-03-28 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18'),
(33, '54', '2019-03-29 00:00:00', '2019-03-29 00:00:00', NULL, 1, 1, 0, 1, NULL, NULL, NULL, NULL, NULL, 1, 1, '2019-04-02 03:49:18', '2019-04-02 03:49:18');

-- --------------------------------------------------------

--
-- Table structure for table `meeting_participants`
--

CREATE TABLE `meeting_participants` (
  `id` int(10) UNSIGNED NOT NULL,
  `meeting_id` int(10) UNSIGNED NOT NULL,
  `user_email` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `accept_status` tinyint(4) NOT NULL DEFAULT 0,
  `attended` tinyint(4) NOT NULL DEFAULT 0,
  `is_owner` tinyint(4) NOT NULL DEFAULT 0,
  `comment` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `meeting_participants`
--

INSERT INTO `meeting_participants` (`id`, `meeting_id`, `user_email`, `name`, `accept_status`, `attended`, `is_owner`, `comment`, `created_at`, `updated_at`) VALUES
(1, 1, 'user1@user1.com', 'user1', 1, 0, 1, NULL, NULL, NULL),
(2, 2, 'user1@user1.com', 'user1', 1, 0, 1, NULL, NULL, NULL),
(3, 3, 'user1@user1.com', 'user1', 1, 0, 1, NULL, NULL, NULL),
(4, 4, 'admin@onepharmaltd.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(5, 4, 'miarul@opl.com', 'Miarul RSM', 0, 0, 0, NULL, NULL, NULL),
(6, 5, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(7, 6, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(8, 7, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(9, 8, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(10, 9, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(11, 10, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(12, 11, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(13, 12, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(14, 13, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(15, 14, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(16, 15, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(17, 16, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(18, 17, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(19, 18, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(20, 19, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(21, 20, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(22, 21, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(23, 22, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(24, 23, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(25, 24, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(26, 25, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(27, 26, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(28, 27, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(29, 28, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(30, 29, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(31, 30, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(32, 31, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(33, 32, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL),
(34, 33, 'gm@opl.com', 'admin', 1, 0, 1, NULL, NULL, NULL);

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
(111, 'destroy', 106, NULL, NULL);

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
(1, 'Super Admin', 'Level1', 1, 0, '2019-03-11 02:48:04', NULL),
(2, 'Level5', 'Level5', 1, 1, '2019-03-20 06:00:59', '2019-03-20 06:00:59'),
(3, 'Level4\r\n', 'Level4', 1, 1, '2019-03-20 07:11:38', '2019-03-20 07:11:38'),
(4, 'Level3', 'Level3', 1, 1, '2019-03-31 06:16:43', '2019-03-31 06:16:43'),
(5, 'Level2', 'Level2', 1, 1, '2019-03-31 06:17:14', '2019-03-31 06:17:14');

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
(5, 16, NULL, NULL),
(5, 17, NULL, NULL),
(5, 18, NULL, NULL),
(5, 19, NULL, NULL),
(5, 20, NULL, NULL),
(5, 21, NULL, NULL),
(5, 22, NULL, NULL),
(5, 23, NULL, NULL),
(5, 24, NULL, NULL),
(5, 25, NULL, NULL),
(5, 26, NULL, NULL),
(5, 27, NULL, NULL),
(5, 28, NULL, NULL),
(5, 29, NULL, NULL),
(5, 30, NULL, NULL),
(5, 31, NULL, NULL),
(5, 32, NULL, NULL),
(5, 33, NULL, NULL),
(5, 34, NULL, NULL),
(5, 35, NULL, NULL),
(5, 36, NULL, NULL),
(5, 37, NULL, NULL),
(5, 38, NULL, NULL),
(5, 39, NULL, NULL),
(5, 40, NULL, NULL),
(5, 41, NULL, NULL),
(5, 42, NULL, NULL),
(5, 43, NULL, NULL),
(5, 44, NULL, NULL),
(5, 45, NULL, NULL),
(5, 46, NULL, NULL),
(5, 47, NULL, NULL),
(5, 48, NULL, NULL),
(5, 49, NULL, NULL),
(5, 50, NULL, NULL),
(5, 51, NULL, NULL),
(5, 52, NULL, NULL),
(5, 53, NULL, NULL),
(5, 54, NULL, NULL),
(5, 55, NULL, NULL),
(5, 56, NULL, NULL),
(5, 57, NULL, NULL),
(5, 58, NULL, NULL),
(5, 63, NULL, NULL),
(5, 64, NULL, NULL),
(5, 65, NULL, NULL),
(5, 66, NULL, NULL),
(5, 67, NULL, NULL),
(5, 68, NULL, NULL),
(5, 69, NULL, NULL),
(5, 70, NULL, NULL),
(5, 71, NULL, NULL),
(5, 72, NULL, NULL),
(5, 73, NULL, NULL),
(5, 74, NULL, NULL),
(5, 75, NULL, NULL),
(5, 76, NULL, NULL),
(5, 77, NULL, NULL),
(5, 78, NULL, NULL),
(5, 79, NULL, NULL),
(5, 80, NULL, NULL),
(5, 81, NULL, NULL),
(5, 82, NULL, NULL),
(5, 83, NULL, NULL),
(5, 84, NULL, NULL),
(5, 85, NULL, NULL),
(5, 88, NULL, NULL),
(5, 89, NULL, NULL),
(5, 96, NULL, NULL),
(5, 97, NULL, NULL),
(5, 98, NULL, NULL),
(5, 99, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `sales`
--

CREATE TABLE `sales` (
  `id` int(10) UNSIGNED NOT NULL,
  `client_id` int(10) UNSIGNED NOT NULL,
  `invoice_no` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sales_amount` double(20,2) NOT NULL,
  `sales_date` date NOT NULL,
  `user_id` int(10) UNSIGNED DEFAULT NULL,
  `sales_note` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payment_status` tinyint(4) DEFAULT NULL COMMENT '0=unpaid,1=paid,2=partial paid',
  `edit_status` tinyint(4) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `location_area_id` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sales`
--

INSERT INTO `sales` (`id`, `client_id`, `invoice_no`, `sales_amount`, `sales_date`, `user_id`, `sales_note`, `payment_status`, `edit_status`, `created_at`, `updated_at`, `location_area_id`) VALUES
(1, 6, '1', 1000.00, '2019-03-10', 5, 'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industrys standard dummy text ever since the 1500s, when an unknown printer took a galley o', 2, 0, '2019-03-11 18:00:00', NULL, 5),
(2, 7, '2', 500.00, '2019-03-04', 5, 'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industrys standard dummy text ever since the 1500s, when an unknown printer took a galley o', 2, 0, NULL, NULL, 5),
(4, 15, '8', 200.00, '2019-03-20', 5, 'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industrys standard dummy text ever since the 1500s, when an unknown printer took a galley o', 2, 0, NULL, NULL, 5),
(5, 16, '9', 8000.00, '2019-03-20', 5, 'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industrys standard dummy text ever since the 1500s, when an unknown printer took a galley o', 2, 0, NULL, NULL, 5),
(6, 7, '897', 1000.00, '2019-03-13', 5, 'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industrys standard dummy text ever since the 1500s, when an unknown printer took a galley o', 2, 0, NULL, NULL, 5),
(7, 6, '321', 3999.00, '2019-03-18', 6, NULL, 2, 0, '2019-03-18 02:29:02', '2019-03-18 02:29:02', 5),
(8, 6, '890', 3000.00, '2019-03-18', 5, NULL, 2, 0, '2019-03-18 03:15:34', '2019-03-18 03:15:34', 5),
(9, 6, '899', 3000.00, '2019-03-18', 5, NULL, 2, 0, '2019-03-18 03:16:49', '2019-03-18 03:16:49', 5),
(10, 6, '25', 100.00, '2019-03-18', 5, NULL, 2, 0, '2019-03-18 03:20:57', '2019-03-18 03:20:57', 5),
(11, 6, '456', 360.00, '2019-03-18', 5, NULL, 2, 0, '2019-03-18 03:23:10', '2019-03-18 03:23:10', 5),
(12, 6, '256', 1800.00, '2019-03-18', 5, NULL, 2, 0, '2019-03-18 03:25:48', '2019-03-18 03:25:48', 5),
(14, 6, '747785', 1800.00, '2019-03-18', 5, NULL, 2, 0, '2019-03-18 03:26:20', '2019-03-18 03:26:20', 5),
(15, 16, '95426', 100.00, '2019-03-19', 5, NULL, 2, 0, '2019-03-18 03:27:35', '2019-03-18 03:27:35', 5),
(16, 6, '56543', 9663.00, '2019-03-18', 5, NULL, 2, 0, '2019-03-18 03:29:48', '2019-03-18 03:29:48', 5),
(17, 6, '12222222222222', 100.00, '2019-03-25', 5, NULL, NULL, 0, '2019-03-18 03:32:04', '2019-03-18 03:32:04', 5),
(19, 6, '122222222222', 100.00, '2019-03-25', 5, NULL, 2, 0, '2019-03-18 03:32:35', '2019-03-18 03:32:35', 5),
(21, 6, '12222222', 100.00, '2019-03-25', 5, NULL, 2, 0, '2019-03-18 03:34:13', '2019-03-18 03:34:13', 5),
(22, 6, '1846774', 1000.00, '2019-03-22', 5, NULL, 2, 0, '2019-03-18 03:35:06', '2019-03-18 03:35:06', 5),
(23, 6, '568', 963258.00, '2019-03-19', 5, NULL, 2, 0, '2019-03-19 06:51:06', '2019-03-19 06:51:06', 5),
(24, 16, '654', 580.00, '2019-03-20', 5, NULL, 2, 0, '2019-03-20 02:27:11', '2019-03-20 02:27:11', 5),
(25, 18, '45666', 500.00, '2019-03-31', 73, NULL, 2, 0, '2019-03-31 13:46:33', '2019-03-31 13:46:33', 30),
(26, 20, '789', 5000.00, '2019-04-01', 65, 'Test', 2, 0, '2019-03-31 14:13:44', '2019-03-31 14:13:44', 25),
(27, 20, '5679', 5898.00, '2019-03-30', 65, NULL, 2, 0, '2019-03-31 14:32:45', '2019-03-31 14:32:45', 25),
(28, 20, '88766', 6000.00, '2019-03-31', 65, NULL, 2, 0, '2019-03-31 14:33:24', '2019-03-31 14:33:24', 25),
(29, 20, '8887', 600.00, '2019-03-26', 65, NULL, 2, 0, '2019-03-31 14:49:41', '2019-03-31 14:49:41', 25),
(30, 20, '8644', 8000.00, '2019-03-21', 65, NULL, 2, 0, '2019-03-31 14:51:15', '2019-03-31 14:51:15', 25),
(31, 23, 'mim0156', 5000.00, '2019-04-01', 65, 'azikil 500', 2, 0, '2019-04-01 04:08:51', '2019-04-01 04:08:51', 25),
(32, 22, 'janani1234', 2000.00, '2019-04-01', 65, 'airway 10', 2, 0, '2019-04-01 04:16:15', '2019-04-01 04:16:15', 25),
(33, 22, '98877', 5000.00, '2019-03-04', 65, NULL, 2, 0, '2019-04-01 05:02:09', '2019-04-01 05:02:09', 25),
(34, 21, '6555', 3000.00, '2019-03-06', 65, NULL, 2, 0, '2019-04-01 05:04:45', '2019-04-01 05:04:45', 25),
(35, 26, 'mita1234', 2000.00, '2019-03-03', 14, 'azikil 100', 2, 0, '2019-04-01 05:08:15', '2019-04-01 05:08:15', 26),
(36, 23, '8654', 3500.00, '2019-03-09', 65, NULL, 2, 0, '2019-04-01 05:15:43', '2019-04-01 05:15:43', 25),
(37, 21, '8765', 2200.00, '2019-03-16', 65, NULL, 2, 0, '2019-04-01 05:16:24', '2019-04-01 05:16:24', 25),
(38, 27, '#6151', 8500.00, '2019-04-01', 6, 'their is my first salea', 2, 0, '2019-04-01 05:21:32', '2019-04-01 05:21:32', 10),
(39, 28, 'lama shop', 11501.00, '2019-04-01', 6, 'this is my second sales', 2, 0, '2019-04-01 05:29:25', '2019-04-01 05:29:25', 10),
(40, 25, 'mina 12334', 3000.00, '2019-03-11', 14, 'azikil 200', 2, 0, '2019-04-01 05:33:16', '2019-04-01 05:33:16', 26),
(41, 25, '120 gg', 5000.00, '2019-04-01', 14, 'New', 2, 0, '2019-04-01 06:08:06', '2019-04-01 06:08:06', 25),
(42, 30, '245', 15361.00, '2019-04-01', 6, 'spacial sale', 2, 0, '2019-04-01 06:22:20', '2019-04-01 06:22:20', 10),
(45, 31, '12345', 5900.00, '2019-04-01', 65, 'Partial collection', 2, 0, '2019-04-01 06:57:14', '2019-04-01 06:57:14', 25),
(46, 21, 'alraji1234', 3000.00, '2019-04-01', 65, NULL, 2, 0, '2019-04-01 09:00:51', '2019-04-01 09:00:51', 25),
(47, 23, '123458', 4568.00, '2019-04-01', 65, NULL, 2, 0, '2019-04-01 09:09:10', '2019-04-01 09:09:10', 25);

-- --------------------------------------------------------

--
-- Table structure for table `targets`
--

CREATE TABLE `targets` (
  `id` int(10) UNSIGNED NOT NULL,
  `created_by` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `type` tinyint(4) NOT NULL,
  `from_date` datetime NOT NULL,
  `to_date` datetime NOT NULL,
  `target_amount` double(20,2) NOT NULL,
  `note` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `targets`
--

INSERT INTO `targets` (`id`, `created_by`, `user_id`, `type`, `from_date`, `to_date`, `target_amount`, `note`, `created_at`, `updated_at`) VALUES
(1, 1, 5, 1, '2019-03-01 00:00:00', '2019-03-31 00:00:00', 4589.00, 'fill target', NULL, '2019-03-23 04:12:29'),
(2, 1, 5, 1, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 10023.00, NULL, NULL, '2019-04-01 05:53:12'),
(3, 1, 5, 1, '2019-05-01 00:00:00', '2019-05-31 00:00:00', 5000.00, NULL, NULL, NULL),
(6, 1, 6, 1, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 100000.00, NULL, NULL, '2019-04-01 05:59:15'),
(9, 1, 6, 1, '2019-06-01 00:00:00', '2019-06-30 00:00:00', 1000.00, 'kisu', '2019-03-20 23:27:43', '2019-03-20 23:27:43'),
(10, 5, 5, 1, '2019-06-01 00:00:00', '2019-06-30 00:00:00', 100000.00, NULL, '2019-03-20 23:28:26', '2019-03-20 23:28:26'),
(11, 1, 5, 1, '2019-07-01 00:00:00', '2019-07-31 00:00:00', 1020000.00, 'Testing', '2019-03-20 23:30:53', '2019-03-20 23:30:53'),
(12, 1, 5, 0, '2019-03-01 00:00:00', '2019-03-31 00:00:00', 4571.00, 'fill target', NULL, '2019-03-23 04:13:00'),
(13, 1, 5, 0, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 4253.00, 'Nxjxj', '2019-03-22 22:31:57', '2019-04-01 05:52:59'),
(14, 1, 5, 0, '2019-06-01 00:00:00', '2019-06-30 00:00:00', 100.00, '100', NULL, NULL),
(15, 1, 5, 1, '2019-08-01 00:00:00', '2019-08-31 00:00:00', 5000.00, NULL, '2019-03-31 13:38:03', '2019-03-31 13:38:03'),
(16, 1, 5, 0, '2019-07-01 00:00:00', '2019-07-31 00:00:00', 4000.00, NULL, '2019-03-31 13:39:25', '2019-03-31 13:39:25'),
(17, 5, 69, 0, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 5000.00, 'Na', '2019-03-31 14:00:58', '2019-03-31 14:00:58'),
(18, 13, 65, 0, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 1666.00, 'Parbona', '2019-03-31 14:09:11', '2019-03-31 14:09:11'),
(19, 70, 73, 0, '2019-03-01 00:00:00', '2019-03-31 00:00:00', 6000.00, NULL, '2019-03-31 14:12:29', '2019-03-31 14:12:29'),
(20, 70, 73, 1, '2019-03-01 00:00:00', '2019-03-31 00:00:00', 4000.00, NULL, '2019-03-31 14:13:42', '2019-03-31 14:13:42'),
(21, 70, 73, 0, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 6500.00, NULL, '2019-03-31 14:14:02', '2019-03-31 14:14:02'),
(22, 70, 73, 1, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 6000.00, NULL, '2019-03-31 14:14:20', '2019-03-31 14:14:20'),
(23, 70, 72, 0, '2019-03-01 00:00:00', '2019-03-31 00:00:00', 7000.00, NULL, '2019-03-31 14:14:43', '2019-03-31 14:14:43'),
(24, 70, 72, 1, '2019-03-01 00:00:00', '2019-03-31 00:00:00', 5000.00, NULL, '2019-03-31 14:15:09', '2019-03-31 14:15:09'),
(25, 70, 72, 1, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 7000.00, NULL, '2019-03-31 14:16:04', '2019-03-31 14:16:04'),
(26, 1, 5, 0, '2019-08-01 00:00:00', '2019-08-31 00:00:00', 10000.00, 'Test', '2019-03-31 14:20:07', '2019-03-31 14:20:07'),
(27, 1, 5, 1, '2019-09-01 00:00:00', '2019-09-30 00:00:00', 15000.00, 'Test', '2019-03-31 14:20:30', '2019-03-31 14:20:30'),
(28, 5, 6, 0, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 100000.00, 'Test', '2019-03-31 14:22:35', '2019-04-01 05:58:57'),
(29, 5, 6, 1, '2019-07-01 00:00:00', '2019-07-31 00:00:00', 10000.00, 'Nd', '2019-03-31 14:23:09', '2019-03-31 14:23:09'),
(30, 13, 65, 0, '2019-03-01 00:00:00', '2019-03-31 00:00:00', 200000.00, NULL, '2019-03-31 14:37:27', '2019-03-31 14:37:27'),
(31, 13, 65, 1, '2019-03-01 00:00:00', '2019-03-31 00:00:00', 100000.00, NULL, '2019-03-31 14:37:47', '2019-03-31 14:37:47'),
(32, 13, 65, 1, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 90000.00, NULL, '2019-03-31 14:38:34', '2019-03-31 14:38:34'),
(33, 6, 13, 0, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 10000.00, 'sales targets', '2019-04-01 03:42:44', '2019-04-01 03:42:44'),
(34, 6, 13, 1, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 10000.00, 'collection target', '2019-04-01 03:53:18', '2019-04-01 03:53:18'),
(35, 1, 5, 0, '2019-09-01 00:00:00', '2019-09-30 00:00:00', 150000.00, 'Sahadat', '2019-04-01 04:19:09', '2019-04-01 04:19:09'),
(36, 5, 6, 0, '2019-09-01 00:00:00', '2019-09-30 00:00:00', 75000.00, NULL, '2019-04-01 04:21:24', '2019-04-01 04:21:24'),
(37, 5, 6, 1, '2019-09-01 00:00:00', '2019-09-30 00:00:00', 7500.00, NULL, '2019-04-01 04:22:01', '2019-04-01 04:22:01'),
(38, 6, 13, 0, '2019-08-01 00:00:00', '2019-08-31 00:00:00', 40000.00, NULL, '2019-04-01 04:24:14', '2019-04-01 04:24:14'),
(39, 6, 13, 0, '2019-09-01 00:00:00', '2019-09-30 00:00:00', 40000.00, NULL, '2019-04-01 04:24:51', '2019-04-01 04:24:51'),
(40, 6, 13, 1, '2019-09-01 00:00:00', '2019-09-30 00:00:00', 30000.00, NULL, '2019-04-01 04:26:03', '2019-04-01 04:26:03'),
(41, 13, 14, 0, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 10000.00, 'teka de', '2019-04-01 04:27:10', '2019-04-01 09:32:11'),
(42, 13, 14, 1, '2019-04-01 00:00:00', '2019-04-30 00:00:00', 150000.00, 'collect koren', '2019-04-01 04:27:34', '2019-04-01 04:27:34'),
(43, 1, 5, 0, '2019-05-01 00:00:00', '2019-05-31 00:00:00', 1000.00, 'Test', '2019-04-01 05:52:02', '2019-04-01 05:52:02'),
(44, 5, 6, 0, '2019-08-01 00:00:00', '2019-08-31 00:00:00', 10000.00, 'Test', '2019-04-01 05:56:23', '2019-04-01 05:56:23'),
(45, 5, 6, 1, '2019-08-01 00:00:00', '2019-08-31 00:00:00', 10000.00, 'Test', '2019-04-01 05:57:05', '2019-04-01 05:57:05'),
(46, 1, 5, 0, '2019-10-01 00:00:00', '2019-10-31 00:00:00', 50000.00, NULL, '2019-04-01 10:37:12', '2019-04-01 10:37:12'),
(47, 1, 5, 1, '2019-10-01 00:00:00', '2019-10-31 00:00:00', 40000.00, NULL, '2019-04-01 10:37:31', '2019-04-01 10:37:31');

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
  `depot_id` int(10) UNSIGNED DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `email`, `password`, `role_id`, `mobile_no`, `photo`, `designation_id`, `department_id`, `gender`, `location_area_id`, `national_identification_num`, `carry_leaves`, `join_date`, `supervisor_id`, `remember_token`, `description`, `address`, `status`, `online`, `socket_id`, `is_supervisor`, `deleted_at`, `created_at`, `updated_at`, `depot_id`) VALUES
(1, 'admin', 'level1@unhcr.org', '$2y$12$bB4oOGz4h3UqFNk8L7ojv.9iwj4bm9Fi5qKhNqqZG.nPcbPfFylbG', 1, '01753414714', '/img/user/Profle_photo_1554014544.jpg', 1, 3, 0, 1, '455', 0, '1997-01-10', 1, NULL, 'description', 'null', 1, NULL, NULL, 1, NULL, '2019-03-11 02:48:04', '2019-11-24 02:58:48', 2),
(5, 'SM1', 'sm1@unhcr.org', '$2y$10$oGgV3IJvSyrDkjISmGk6JOtt3JvusBu7p21.AMYauoqQkxauwX8OC', 5, '01753414711', '/img/user/Profle_photo_1554024540.jpeg', 2, 3, 1, 6, '11111111111111112', 0, '2015-01-15', 1, NULL, 'descr1', 'address1', 1, NULL, NULL, 1, NULL, '2019-03-11 02:48:04', '2019-03-31 13:56:31', 1),
(6, 'RSM1', 'rsm1@unhcr.org', '$2y$10$oGgV3IJvSyrDkjISmGk6JOtt3JvusBu7p21.AMYauoqQkxauwX8OC', 4, '01753414710', '/img/user/Profle_photo_1554024818.jpg', 3, 3, 1, 10, '1111111111111111', 0, '2015-01-17', 5, NULL, 'des', 'add', 1, NULL, NULL, 1, NULL, '2019-03-11 02:48:04', '2019-03-31 12:45:32', 1),
(12, 'Al Mamun', 'mamun@unhcr.org', '$2y$10$76LHT78sxgq0b50lbCQRAe0QfaxEtLInRjWVLBg8Z/X9Bx3klMX1S', 2, '01679526964', '/img/user/Profle_photo_1553510982.jpg', 1, 1, 1, 3, '23423423423423423', 0, '2019-03-23', 3, NULL, 'test descr', '5,1212', 2, NULL, NULL, 1, '2019-03-25 06:17:02', '2019-03-23 00:54:04', '2019-03-25 06:17:02', NULL),
(13, 'hasan', 'am1@unhcr.org', '$2y$10$iBiLNh424DozwYYh.FcQF.riQF.5XJIVylIdezGZVpBz4iGw/jwe2', 3, '01753414710', '/img/user/Profle_photo_1554034756.jpg', 4, 3, 1, 24, '11111111111111111111', 0, '2019-03-15', 6, NULL, 'ddddddddddddddddd', 'ddddddddddd', 1, NULL, NULL, 1, NULL, '2019-03-23 03:19:28', '2019-03-31 14:05:10', 1),
(14, 'Rupom', 'mio2@unhcr.org', '$2y$10$oGgV3IJvSyrDkjISmGk6JOtt3JvusBu7p21.AMYauoqQkxauwX8OC', 2, '01753414710', '/img/user/Profle_photo_1554034918.jpeg', 5, 3, 1, 26, '111111111111111', 0, '2017-01-01', 13, NULL, 'ddddddddddddddddd', 'ddddddddddddd', 1, NULL, NULL, 0, NULL, '2019-03-23 03:21:30', '2019-03-31 14:05:41', 1),
(65, 'Shakib MIO', 'mio3@unhcr.org', '$2y$10$2Q3ohzpvoR/tFFXlPnuQkurfKNN3sby.ywrQzGodx2aCN06fE.JVi', 2, '01753414710', '/img/user/Profle_photo_1554036450.jpg', 5, 3, 1, 25, 'null', 0, '2019-03-15', 13, NULL, 'null', 'null', 1, NULL, NULL, 0, NULL, NULL, '2019-03-31 14:06:00', 1),
(66, 'Mukitul AM', 'am2@unhcr.org', '$2y$10$gK.qFF2hupEpQZqtULQDkOD7tmX7wpt8Y6/0fam7sVq8WkI0yEu1W', 3, '01753414710', '/img/user/Profle_photo_1554036646.jpeg', 4, 3, 1, 11, 'null', 0, '2019-03-15', 6, NULL, 'null', 'null', 1, NULL, NULL, 1, NULL, NULL, '2019-03-31 14:07:23', 1),
(67, 'Kabir MIO', 'mio5@unhcr.org', '$2y$10$N6zXEpdgFYp61Pay2PPlhuk8xgwIf3mFyghdbw0pe.0XscPxuhzPK', 2, '01753414710', NULL, 5, 3, 1, 23, 'null', 0, '2019-03-15', 66, NULL, 'null', 'null', 1, NULL, NULL, 0, NULL, NULL, '2019-03-31 14:08:07', 1),
(68, 'Alamin MIO', 'mio6@unhcr.org', '$2y$10$SdNUUP18WEp0duwGidvkRuutrs6.318glL5TkuccWkWS/GMYRzkVq', 2, '01753414710', '/img/user/Profle_photo_1554037272.jpg', 5, 3, 1, 12, 'null', 0, '2019-03-15', 66, NULL, 'null', 'null', 1, NULL, NULL, 0, NULL, NULL, '2019-03-31 14:09:06', 1),
(69, 'Miarul RSM', 'rsm2@unhcr.org', '$2y$10$gxN45zOxiJwG4zkDuscmzOSBbLOaIW32PyvbuPQKYsIJ6L/q3LZNS', 4, '01753414710', '/img/user/Profle_photo_1554037925.jpg', 3, 3, 1, 7, 'null', 0, '2019-03-15', 5, NULL, 'null', 'null', 1, NULL, NULL, 1, NULL, NULL, '2019-03-31 14:04:34', 4),
(70, 'Ashif AM', 'am3@unhcr.org', '$2y$10$LT5g6123.k5pf5HIlRxO7ekfCkg9.oAxBTsSBxyxAILhtYHYjbYqm', 3, '01753414710', '/img/user/Profle_photo_1554037401.jpg', 4, 3, 1, 28, 'null', 0, '2019-03-15', 69, NULL, 'null', 'null', 1, NULL, NULL, 1, NULL, NULL, '2019-03-31 14:10:14', 4),
(71, 'Farial AM', 'am4@unhcr.org', '$2y$10$funGRo6g0QHeOWNDHICsIuzZB2XcOGR9ptK./HJZAS.TSsIHlCUdm', 3, '01753414710', '/img/user/Profle_photo_1554037689.jpg', 4, 3, 1, 8, 'null', 0, '2019-03-15', 69, NULL, 'null', 'null', 1, NULL, NULL, 1, NULL, NULL, '2019-03-31 14:10:39', 4),
(72, 'Rijvi MIO', 'mio1@unhcr.org', '$2y$10$0rKhQ5W8knPTwwIVyeBNEe7lz0ncHUQqR0uCS8I.fYymPZMVlNEGy', 2, '01753414710', '/img/user/Profle_photo_1554037846.jpg', 5, 3, 1, 29, 'null', 0, '2019-03-15', 70, NULL, 'null', 'null', 1, NULL, NULL, 0, NULL, NULL, '2019-03-31 14:04:06', 4),
(73, 'A. Karim MIO', 'mio4@unhcr.org', '$2y$10$NsUZI46xr468WRH/EGiDx.4OpDSiFPjhm4vzmbqh2Xfbaz/y0GXoK', 2, '01753414710', '/img/user/Profle_photo_1554038472.jpg', 5, 3, 1, 30, 'null', 0, '2019-03-15', 70, NULL, 'null', 'null', 1, NULL, NULL, 0, NULL, NULL, '2019-03-31 14:06:42', 4);

-- --------------------------------------------------------

--
-- Table structure for table `user_attendances`
--

CREATE TABLE `user_attendances` (
  `id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `date` date NOT NULL,
  `cin_time` time DEFAULT NULL,
  `cout_time` time DEFAULT NULL,
  `cin_latlng` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cout_latlng` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cin_area` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cout_area` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remarks` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `locations` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `user_attendances`
--

INSERT INTO `user_attendances` (`id`, `user_id`, `date`, `cin_time`, `cout_time`, `cin_latlng`, `cout_latlng`, `cin_area`, `cout_area`, `remarks`, `locations`, `created_at`, `updated_at`) VALUES
(2, 1, '2018-10-07', '16:02:47', '16:02:51', NULL, NULL, NULL, NULL, NULL, NULL, '2018-10-07 10:02:47', '2018-10-07 10:02:51'),
(3, 5, '2018-10-07', '16:59:53', '17:03:22', NULL, NULL, NULL, NULL, NULL, NULL, '2018-10-07 10:59:53', '2018-10-07 11:03:22'),
(4, 1, '2018-10-11', '15:08:30', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2018-10-11 09:08:30', '2018-10-11 09:08:30'),
(5, 5, '2018-10-13', '10:59:25', '11:02:01', '23.7483995,90.3918209', '23.7483995,90.3918209', '111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh', '111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh', NULL, NULL, '2018-10-13 04:59:25', '2018-10-13 05:02:01'),
(6, 1, '2018-10-13', '15:41:03', '15:41:42', NULL, NULL, NULL, NULL, NULL, NULL, '2018-10-13 09:41:03', '2018-10-13 09:41:42'),
(7, 1, '2018-10-14', '09:50:10', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2018-10-14 03:50:10', '2018-10-14 03:50:10'),
(8, 5, '2018-10-14', '09:50:32', NULL, NULL, NULL, NULL, NULL, NULL, '[{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka\",\"time\":\"10:30:20\"},{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka 2\",\"time\":\"10:30:27\"},{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka 2\",\"time\":\"10:30:32\"},{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka 2\",\"time\":\"10:30:46\"},{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka 2\",\"time\":\"10:30:49\"},{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka 2\",\"time\":\"10:30:52\"},{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka 2\",\"time\":\"10:31:01\"},{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka 2\",\"time\":\"10:31:12\"},{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka 2\",\"time\":\"10:32:13\"},{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka 2\",\"time\":\"10:32:43\"},{\"latlng\":\"12.4556,67.345345\",\"area\":\"dhaka 2\",\"time\":\"10:32:50\"}]', '2018-10-14 03:50:32', '2018-10-14 04:32:50'),
(9, 5, '2018-10-15', '12:57:03', NULL, '23.7481542,90.3918368', NULL, '111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh\nDhaka - 1205\nDhaka Division\nBangladesh', NULL, NULL, '[{\"latlng\":\"23.25,90.235\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh.\",\"time\":\"12:57:47\"},{\"latlng\":\"23.25,90.235\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh.\",\"time\":\"12:57:50\"},{\"latlng\":\"23.25,90.235\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh.\",\"time\":\"12:58:27\"},{\"latlng\":\"23.74842,90.3917687\",\"area\":\"Principal park DN (6th Floor), 11\\/7G, Free School Street, Kathalbagan, East Dhanmondi, Dhaka-1205, Bangladesh\\nTejgaon Circle\\nDhaka Division\\nBangladesh\",\"time\":\"13:10:12\"},{\"latlng\":\"23.74842,90.3917687\",\"area\":\"Principal park DN (6th Floor), 11\\/7G, Free School Street, Kathalbagan, East Dhanmondi, Dhaka-1205, Bangladesh\\nTejgaon Circle\\nDhaka Division\\nBangladesh\",\"time\":\"13:11:53\"},{\"latlng\":\"23.74842,90.3917687\",\"area\":\"Principal park DN (6th Floor), 11\\/7G, Free School Street, Kathalbagan, East Dhanmondi, Dhaka-1205, Bangladesh\\nTejgaon Circle\\nDhaka Division\\nBangladesh\",\"time\":\"13:16:35\"},{\"latlng\":\"23.7481737,90.3918966\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"13:28:22\"},{\"latlng\":\"23.7481737,90.3918966\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"13:28:23\"},{\"latlng\":\"23.7481938,90.3918514\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"13:46:30\"},{\"latlng\":\"23.7481938,90.3918514\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"13:46:30\"},{\"latlng\":\"23.7482386,90.391809\",\"area\":\"8,9 & 10\\/3, Free School Street, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"14:03:10\"},{\"latlng\":\"23.7482386,90.391809\",\"area\":\"8,9 & 10\\/3, Free School Street, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"14:03:10\"},{\"latlng\":\"23.7482386,90.391809\",\"area\":\"8,9 & 10\\/3, Free School Street, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"14:19:50\"},{\"latlng\":\"23.7482386,90.391809\",\"area\":\"8,9 & 10\\/3, Free School Street, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"14:19:50\"},{\"latlng\":\"23.7483004,90.3918858\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"18:09:52\"},{\"latlng\":\"23.7482803,90.3917283\",\"area\":\"8,9 & 10\\/3, Free School Street, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"18:11:00\"},{\"latlng\":\"23.7482328,90.3918895\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"18:12:06\"}]', '2018-10-15 06:57:03', '2018-10-15 12:12:06'),
(10, 5, '2018-10-16', '10:31:37', NULL, '23.7481863,90.3927015', NULL, 'National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh\nDhaka - 1205\nDhaka Division\nBangladesh', NULL, NULL, '[{\"latlng\":\"23.7481863,90.3927015\",\"area\":\"National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"10:31:39\"}]', '2018-10-16 04:31:37', '2018-10-16 04:31:39'),
(11, 5, '2018-10-17', '18:20:40', NULL, '23.7482334,90.3919229', NULL, '111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh\nDhaka - 1205\nDhaka Division\nBangladesh', NULL, NULL, NULL, '2018-10-17 12:20:40', '2018-10-17 12:20:40'),
(12, 5, '2018-11-11', '18:25:18', NULL, '23.7483124,90.3918917', NULL, '111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh\nDhaka - 1205\nDhaka Division\nBangladesh', NULL, NULL, NULL, '2018-11-11 12:25:18', '2018-11-11 12:25:18'),
(13, 1, '2018-11-20', '10:46:03', '10:50:54', '23.7484228,90.3918439', '23.7484228,90.3918439', '11/7H, Free School St, Dhaka 1205, Bangladesh', '11/7H, Free School St, Dhaka 1205, Bangladesh', 'first time', '[{\"latlng\":\"23.748398,90.3918465\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nBangladesh\",\"time\":\"10:46:24\"},{\"latlng\":\"23.748398,90.3918465\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nBangladesh\",\"time\":\"10:46:48\"},{\"latlng\":\"23.7496482,90.3914575\",\"area\":\"Samarai Convention Center, Samarai Convention Center, 23\\/G\\/6 Panthapath, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"10:55:13\"},{\"latlng\":\"23.7496482,90.3914575\",\"area\":\"Samarai Convention Center, Samarai Convention Center, 23\\/G\\/6 Panthapath, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"10:55:14\"},{\"latlng\":\"23.7496482,90.3914575\",\"area\":\"Samarai Convention Center, Samarai Convention Center, 23\\/G\\/6 Panthapath, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"10:55:14\"},{\"latlng\":\"23.7484125,90.3918326\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nBangladesh\",\"time\":\"11:00:42\"},{\"latlng\":\"23.7484125,90.3918326\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nBangladesh\",\"time\":\"11:00:42\"},{\"latlng\":\"23.7484125,90.3918326\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nBangladesh\",\"time\":\"11:00:43\"},{\"latlng\":\"23.7483714,90.3918364\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nBangladesh\",\"time\":\"11:11:46\"},{\"latlng\":\"23.7483714,90.3918364\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nBangladesh\",\"time\":\"11:11:46\"},{\"latlng\":\"23.7483714,90.3918364\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nBangladesh\",\"time\":\"11:11:46\"}]', '2018-11-20 04:46:03', '2018-11-20 05:11:46'),
(14, 1, '2018-12-01', '09:00:00', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(15, 1, '2017-11-21', '07:00:00', '20:00:00', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(23, 1, '2018-12-02', '16:58:04', '17:46:39', '23.7482934,90.3921314', '23.7483338,90.3918312', 'Tropical Home Park View, 1st Floor, B-1, 9/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, '[{\"latlng\":\"23.7482934,90.3921314\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:58:11\"},{\"latlng\":\"23.7485049,90.3920826\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:59:06\"},{\"latlng\":\"23.7485049,90.3920826\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:59:06\"},{\"latlng\":\"23.7485184,90.3920968\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:00:15\"},{\"latlng\":\"23.7485184,90.3920968\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:00:15\"},{\"latlng\":\"23.7485327,90.3921192\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:01:22\"},{\"latlng\":\"23.7485327,90.3921192\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:01:22\"},{\"latlng\":\"23.7483216,90.3918539\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:02:30\"},{\"latlng\":\"23.7483216,90.3918539\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:02:30\"},{\"latlng\":\"23.748512,90.3920926\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:03:39\"},{\"latlng\":\"23.748512,90.3920926\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:03:39\"},{\"latlng\":\"23.748512,90.3920926\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:03:50\"},{\"latlng\":\"23.748512,90.3920926\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:04:53\"},{\"latlng\":\"23.7485268,90.3920892\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:06:04\"},{\"latlng\":\"23.7485217,90.3920211\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:06:39\"},{\"latlng\":\"23.748298,90.3918078\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:07:39\"},{\"latlng\":\"23.7483617,90.3918478\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:08:40\"},{\"latlng\":\"23.7483134,90.3918495\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:09:40\"},{\"latlng\":\"23.7483134,90.3918495\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:10:00\"},{\"latlng\":\"23.7483237,90.3918011\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:10:57\"},{\"latlng\":\"23.748524,90.392091\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:12:00\"},{\"latlng\":\"23.7483225,90.3919847\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:12:22\"},{\"latlng\":\"23.7484996,90.3918824\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:13:11\"},{\"latlng\":\"23.7484996,90.3918824\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:13:11\"},{\"latlng\":\"23.7485293,90.3920937\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:14:16\"},{\"latlng\":\"23.7485293,90.3920937\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:14:16\"},{\"latlng\":\"23.748505,90.3920795\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:15:30\"},{\"latlng\":\"23.748505,90.3920795\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:15:31\"},{\"latlng\":\"23.7484933,90.3920693\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:16:37\"},{\"latlng\":\"23.7484933,90.3920693\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:16:37\"},{\"latlng\":\"23.7483825,90.3921492\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:17:44\"},{\"latlng\":\"23.7483825,90.3921492\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:17:45\"},{\"latlng\":\"23.748287,90.3918486\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:18:49\"},{\"latlng\":\"23.748287,90.3918486\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:18:50\"},{\"latlng\":\"23.7484754,90.3920752\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:19:58\"},{\"latlng\":\"23.7484754,90.3920752\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:19:58\"},{\"latlng\":\"23.7484633,90.3920694\",\"area\":\"11\\/7 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:21:08\"},{\"latlng\":\"23.7484633,90.3920694\",\"area\":\"11\\/7 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:21:08\"},{\"latlng\":\"23.7486298,90.3918167\",\"area\":\"11\\/7\\/G Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:22:16\"},{\"latlng\":\"23.7486298,90.3918167\",\"area\":\"11\\/7\\/G Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:22:16\"},{\"latlng\":\"23.7483268,90.3918211\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:31:38\"},{\"latlng\":\"23.7483268,90.3918211\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:31:38\"},{\"latlng\":\"23.7483268,90.3918211\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:31:38\"},{\"latlng\":\"23.7481884,90.3923629\",\"area\":\"Anchor Tower, 108, Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:36:16\"},{\"latlng\":\"23.7481884,90.3923629\",\"area\":\"Anchor Tower, 108, Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:36:20\"},{\"latlng\":\"23.7484057,90.3918117\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:36:41\"},{\"latlng\":\"23.7484057,90.3918117\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:36:41\"},{\"latlng\":\"23.7484057,90.3918117\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:36:41\"},{\"latlng\":\"23.7481596,90.3920716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:37:19\"},{\"latlng\":\"23.7481596,90.3920716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:37:19\"},{\"latlng\":\"23.7482474,90.392069\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:38:29\"},{\"latlng\":\"23.7482474,90.392069\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:38:30\"},{\"latlng\":\"23.7482474,90.392069\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:38:30\"},{\"latlng\":\"23.7482474,90.392069\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:38:30\"},{\"latlng\":\"23.7482474,90.392069\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:38:30\"},{\"latlng\":\"23.7483575,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:39:38\"},{\"latlng\":\"23.7483575,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:39:38\"},{\"latlng\":\"23.7483575,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:39:38\"},{\"latlng\":\"23.7483575,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:39:39\"},{\"latlng\":\"23.7483575,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:39:39\"},{\"latlng\":\"23.748419,90.3918636\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:40:06\"},{\"latlng\":\"23.7483876,90.3918312\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:41:10\"},{\"latlng\":\"23.7483963,90.3917893\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"17:42:11\"},{\"latlng\":\"23.7483379,90.3918347\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:43:11\"},{\"latlng\":\"23.7484032,90.3918443\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:44:11\"},{\"latlng\":\"23.7483443,90.3918383\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:12\"},{\"latlng\":\"23.7483338,90.3918312\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:46:13\"}]', '2018-12-02 10:58:04', '2018-12-02 11:46:39');
INSERT INTO `user_attendances` (`id`, `user_id`, `date`, `cin_time`, `cout_time`, `cin_latlng`, `cout_latlng`, `cin_area`, `cout_area`, `remarks`, `locations`, `created_at`, `updated_at`) VALUES
(24, 1, '2018-12-03', '09:54:28', '13:33:33', '23.7487941,90.3925153', '23.7486094,90.3918412', 'Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, ঢাকা 1205, Bangladesh,ঢাকা - 1205,ঢাকা বিভাগ,Bangladesh', 'Holding No-11/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, '[{\"latlng\":\"23.7488534,90.3928896\",\"area\":\"37 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:54:51\"},{\"latlng\":\"23.7475776,90.3916081\",\"area\":\"282 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:55:53\"},{\"latlng\":\"23.7475776,90.3916081\",\"area\":\"282 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:55:53\"},{\"latlng\":\"23.7475776,90.3916081\",\"area\":\"282 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:55:53\"},{\"latlng\":\"23.7475776,90.3916081\",\"area\":\"282 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:55:54\"},{\"latlng\":\"23.7489304,90.3920438\",\"area\":\"111 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:56:53\"},{\"latlng\":\"23.7489304,90.3920438\",\"area\":\"111 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:56:53\"},{\"latlng\":\"23.7489304,90.3920438\",\"area\":\"111 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:56:53\"},{\"latlng\":\"23.7489304,90.3920438\",\"area\":\"111 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:56:53\"},{\"latlng\":\"23.7490383,90.3924969\",\"area\":\"Opposite Sonargaon Hotel, 112 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:57:53\"},{\"latlng\":\"23.7490383,90.3924969\",\"area\":\"Opposite Sonargaon Hotel, 112 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:57:53\"},{\"latlng\":\"23.7490383,90.3924969\",\"area\":\"Opposite Sonargaon Hotel, 112 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:57:53\"},{\"latlng\":\"23.7490383,90.3924969\",\"area\":\"Opposite Sonargaon Hotel, 112 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:57:53\"},{\"latlng\":\"23.7488318,90.3923292\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:58:56\"},{\"latlng\":\"23.7488318,90.3923292\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:58:56\"},{\"latlng\":\"23.7488318,90.3923292\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:58:57\"},{\"latlng\":\"23.7488318,90.3923292\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:58:57\"},{\"latlng\":\"23.7484122,90.3924238\",\"area\":\"109, 3rd Floor, National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:59:54\"},{\"latlng\":\"23.7484122,90.3924238\",\"area\":\"109, 3rd Floor, National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:59:54\"},{\"latlng\":\"23.7484122,90.3924238\",\"area\":\"109, 3rd Floor, National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:59:54\"},{\"latlng\":\"23.7484122,90.3924238\",\"area\":\"109, 3rd Floor, National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"09:59:55\"},{\"latlng\":\"23.7485185,90.3923741\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:00:56\"},{\"latlng\":\"23.7485185,90.3923741\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:00:56\"},{\"latlng\":\"23.7485185,90.3923741\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:00:57\"},{\"latlng\":\"23.7485185,90.3923741\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:00:57\"},{\"latlng\":\"23.7483528,90.3918499\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:02:01\"},{\"latlng\":\"23.7483528,90.3918499\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:02:01\"},{\"latlng\":\"23.7483528,90.3918499\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:02:02\"},{\"latlng\":\"23.7483528,90.3918499\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:02:02\"},{\"latlng\":\"23.748443,90.392148\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:03:09\"},{\"latlng\":\"23.748443,90.392148\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:03:09\"},{\"latlng\":\"23.748443,90.392148\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:03:09\"},{\"latlng\":\"23.748443,90.392148\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:03:09\"},{\"latlng\":\"23.7484189,90.3922006\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:04:17\"},{\"latlng\":\"23.7484189,90.3922006\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:04:17\"},{\"latlng\":\"23.7484189,90.3922006\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:04:18\"},{\"latlng\":\"23.7484189,90.3922006\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:04:18\"},{\"latlng\":\"23.7483174,90.3918309\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:10:14\"},{\"latlng\":\"23.7483174,90.3918309\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:10:14\"},{\"latlng\":\"23.7483174,90.3918309\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:10:14\"},{\"latlng\":\"23.7483174,90.3918309\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:10:15\"},{\"latlng\":\"23.7483889,90.3917319\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"10:11:25\"},{\"latlng\":\"23.7483889,90.3917319\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"10:11:25\"},{\"latlng\":\"23.7483889,90.3917319\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"10:11:25\"},{\"latlng\":\"23.7483889,90.3917319\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"10:11:25\"},{\"latlng\":\"23.7484698,90.391655\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"10:21:26\"},{\"latlng\":\"23.7484698,90.391655\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"10:21:27\"},{\"latlng\":\"23.7484698,90.391655\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"10:21:27\"},{\"latlng\":\"23.7484698,90.391655\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"10:21:27\"},{\"latlng\":\"23.7484769,90.3917257\",\"area\":\"Principal park DN (6th Floor), 11\\/7G, Free School Street, Kathalbagan, East Dhanmondi, Dhaka-1205, Bangladesh,Tejgaon Circle,Dhaka Division,Bangladesh\",\"time\":\"10:40:46\"},{\"latlng\":\"23.7484769,90.3917257\",\"area\":\"Principal park DN (6th Floor), 11\\/7G, Free School Street, Kathalbagan, East Dhanmondi, Dhaka-1205, Bangladesh,Tejgaon Circle,Dhaka Division,Bangladesh\",\"time\":\"10:40:46\"},{\"latlng\":\"23.7484769,90.3917257\",\"area\":\"Principal park DN (6th Floor), 11\\/7G, Free School Street, Kathalbagan, East Dhanmondi, Dhaka-1205, Bangladesh,Tejgaon Circle,Dhaka Division,Bangladesh\",\"time\":\"10:40:46\"},{\"latlng\":\"23.7484769,90.3917257\",\"area\":\"Principal park DN (6th Floor), 11\\/7G, Free School Street, Kathalbagan, East Dhanmondi, Dhaka-1205, Bangladesh,Tejgaon Circle,Dhaka Division,Bangladesh\",\"time\":\"10:40:46\"},{\"latlng\":\"23.7483188,90.3918128\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:52:33\"},{\"latlng\":\"23.7483051,90.3918235\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:54:29\"},{\"latlng\":\"23.7484288,90.391884\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"10:55:29\"},{\"latlng\":\"23.7484131,90.3918512\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"10:56:29\"},{\"latlng\":\"23.7484087,90.3918864\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"10:57:36\"},{\"latlng\":\"23.7484116,90.3919041\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"10:58:53\"},{\"latlng\":\"23.748359,90.3918666\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:59:28\"},{\"latlng\":\"23.748359,90.3918666\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:59:46\"},{\"latlng\":\"23.7483323,90.3920184\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:00:51\"},{\"latlng\":\"23.7484541,90.3920249\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:01:57\"},{\"latlng\":\"23.7484541,90.3920249\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:03:16\"},{\"latlng\":\"23.7484401,90.3918433\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:03:48\"},{\"latlng\":\"23.7483212,90.3918348\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:06:39\"},{\"latlng\":\"23.7483407,90.3918461\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:07:19\"},{\"latlng\":\"23.7483442,90.3917956\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:08:19\"},{\"latlng\":\"23.7483968,90.3918664\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:09:20\"},{\"latlng\":\"23.7483255,90.3918449\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:10:20\"},{\"latlng\":\"23.7483962,90.3918693\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:11:21\"},{\"latlng\":\"23.748304,90.391804\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:11:55\"},{\"latlng\":\"23.7483454,90.3917941\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:12:56\"},{\"latlng\":\"23.7483184,90.3918432\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:13:56\"},{\"latlng\":\"23.7483957,90.3918913\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:14:56\"},{\"latlng\":\"23.7482968,90.3918177\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:15:57\"},{\"latlng\":\"23.7482967,90.3918362\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:16:58\"},{\"latlng\":\"23.7483355,90.3918275\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:17:58\"},{\"latlng\":\"23.7483176,90.3918439\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:18:59\"},{\"latlng\":\"23.7484137,90.3920293\",\"area\":\"11\\/7 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:20:00\"},{\"latlng\":\"23.7489202,90.3923743\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:21:01\"},{\"latlng\":\"23.7484798,90.3920729\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:22:00\"},{\"latlng\":\"23.7484819,90.3920815\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:23:15\"},{\"latlng\":\"23.7483194,90.3917737\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:25:00\"},{\"latlng\":\"23.7483263,90.3918176\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:27:51\"},{\"latlng\":\"23.7483331,90.3918151\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:28:51\"},{\"latlng\":\"23.7483727,90.3918373\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:29:51\"},{\"latlng\":\"23.7483438,90.3918345\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:30:52\"},{\"latlng\":\"23.7483327,90.3918175\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:31:53\"},{\"latlng\":\"23.7484224,90.3920105\",\"area\":\"11\\/7 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:32:46\"},{\"latlng\":\"23.7482965,90.3918058\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:33:35\"},{\"latlng\":\"23.7482917,90.3918112\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:34:35\"},{\"latlng\":\"23.7482993,90.3918188\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:35:36\"},{\"latlng\":\"23.7483031,90.3918216\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:36:36\"},{\"latlng\":\"23.7483196,90.3918386\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:37:37\"},{\"latlng\":\"23.7483528,90.3918327\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:38:38\"},{\"latlng\":\"23.7483299,90.3918317\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:39:38\"},{\"latlng\":\"23.7483397,90.3918033\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:40:39\"},{\"latlng\":\"23.748846,90.3919809\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:41:40\"},{\"latlng\":\"23.7488259,90.3919876\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:42:42\"},{\"latlng\":\"23.7483581,90.3918466\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:43:46\"},{\"latlng\":\"23.7485456,90.3921123\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:44:54\"},{\"latlng\":\"23.748342,90.3918439\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:45:54\"},{\"latlng\":\"23.7485758,90.3921125\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:46:03\"},{\"latlng\":\"23.7483974,90.3918945\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:46:38\"},{\"latlng\":\"23.7485989,90.3921026\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:47:08\"},{\"latlng\":\"23.7483344,90.3918717\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:47:39\"},{\"latlng\":\"23.7486332,90.3921093\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:48:15\"},{\"latlng\":\"23.7487508,90.392095\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:48:41\"},{\"latlng\":\"23.7486647,90.3920957\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:49:23\"},{\"latlng\":\"23.7486807,90.3920643\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:50:34\"},{\"latlng\":\"23.7486807,90.3920643\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:50:34\"},{\"latlng\":\"23.7483723,90.3918517\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:51:40\"},{\"latlng\":\"23.7483723,90.3918517\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:51:41\"},{\"latlng\":\"23.748369,90.3918563\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:52:40\"},{\"latlng\":\"23.748369,90.3918563\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:52:41\"},{\"latlng\":\"23.7489893,90.3918859\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:53:42\"},{\"latlng\":\"23.7489893,90.3918859\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:53:42\"},{\"latlng\":\"23.7489893,90.3918859\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:53:42\"},{\"latlng\":\"23.7483178,90.3921982\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:53:51\"},{\"latlng\":\"23.7483178,90.3921982\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:53:59\"},{\"latlng\":\"23.7486636,90.3919832\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:54:54\"},{\"latlng\":\"23.7486636,90.3919832\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:54:54\"},{\"latlng\":\"23.7486636,90.3919832\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:54:54\"},{\"latlng\":\"23.7486636,90.3919832\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:54:54\"},{\"latlng\":\"23.7486636,90.3919832\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"11:54:54\"},{\"latlng\":\"23.7486749,90.3919728\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:56:03\"},{\"latlng\":\"23.7486749,90.3919728\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:56:04\"},{\"latlng\":\"23.7486749,90.3919728\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:56:04\"},{\"latlng\":\"23.7486749,90.3919728\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:56:04\"},{\"latlng\":\"23.7486749,90.3919728\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:56:04\"},{\"latlng\":\"23.748644,90.3919654\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:57:17\"},{\"latlng\":\"23.748644,90.3919654\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:57:17\"},{\"latlng\":\"23.748644,90.3919654\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:57:18\"},{\"latlng\":\"23.748644,90.3919654\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:57:18\"},{\"latlng\":\"23.748644,90.3919654\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:57:18\"},{\"latlng\":\"23.7486564,90.3919484\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:58:25\"},{\"latlng\":\"23.7486564,90.3919484\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:58:25\"},{\"latlng\":\"23.7486564,90.3919484\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:58:25\"},{\"latlng\":\"23.7486564,90.3919484\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:58:25\"},{\"latlng\":\"23.7486564,90.3919484\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:58:25\"},{\"latlng\":\"23.7486711,90.3919257\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:59:33\"},{\"latlng\":\"23.7486711,90.3919257\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:59:33\"},{\"latlng\":\"23.7486711,90.3919257\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:59:33\"},{\"latlng\":\"23.7486711,90.3919257\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:59:33\"},{\"latlng\":\"23.7486711,90.3919257\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:59:34\"},{\"latlng\":\"23.7486973,90.3919283\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:00:39\"},{\"latlng\":\"23.7486973,90.3919283\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:00:40\"},{\"latlng\":\"23.7486973,90.3919283\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:00:40\"},{\"latlng\":\"23.7486973,90.3919283\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:00:40\"},{\"latlng\":\"23.7486973,90.3919283\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:00:42\"},{\"latlng\":\"23.748409,90.3918358\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:01:46\"},{\"latlng\":\"23.748409,90.3918358\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:01:47\"},{\"latlng\":\"23.748409,90.3918358\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:01:47\"},{\"latlng\":\"23.748409,90.3918358\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:01:47\"},{\"latlng\":\"23.748409,90.3918358\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:01:47\"},{\"latlng\":\"23.7487207,90.3919174\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:02:53\"},{\"latlng\":\"23.7487207,90.3919174\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:02:53\"},{\"latlng\":\"23.7487207,90.3919174\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:02:54\"},{\"latlng\":\"23.7487207,90.3919174\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:02:54\"},{\"latlng\":\"23.7487207,90.3919174\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:02:54\"},{\"latlng\":\"23.7487013,90.3919113\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:04:00\"},{\"latlng\":\"23.7487013,90.3919113\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:04:00\"},{\"latlng\":\"23.7487013,90.3919113\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:04:00\"},{\"latlng\":\"23.7487013,90.3919113\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:04:00\"},{\"latlng\":\"23.7487013,90.3919113\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:04:01\"},{\"latlng\":\"23.7487194,90.3919245\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:05:07\"},{\"latlng\":\"23.7487194,90.3919245\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:05:08\"},{\"latlng\":\"23.7487194,90.3919245\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:05:08\"},{\"latlng\":\"23.7487194,90.3919245\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:05:08\"},{\"latlng\":\"23.7487194,90.3919245\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:05:08\"},{\"latlng\":\"23.74825,90.3918002\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:20:31\"},{\"latlng\":\"23.7482701,90.3918132\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:21:32\"},{\"latlng\":\"23.7482927,90.3918281\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:22:33\"},{\"latlng\":\"23.7482655,90.3918018\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:23:34\"},{\"latlng\":\"23.7485331,90.392098\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:25:06\"},{\"latlng\":\"23.7485936,90.3921247\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:26:13\"},{\"latlng\":\"23.7485524,90.3920891\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:27:26\"},{\"latlng\":\"23.7485453,90.3921582\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:28:37\"},{\"latlng\":\"23.7484548,90.392016\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:29:47\"},{\"latlng\":\"23.7482669,90.3918108\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:40:37\"},{\"latlng\":\"23.7482991,90.3918144\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:41:37\"},{\"latlng\":\"23.7482663,90.391809\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:42:37\"},{\"latlng\":\"23.7482865,90.3918172\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:43:38\"},{\"latlng\":\"23.7482699,90.3918011\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:44:12\"},{\"latlng\":\"23.7483037,90.3918195\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:45:12\"},{\"latlng\":\"23.7482701,90.3917999\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:46:13\"},{\"latlng\":\"23.7490146,90.3923085\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:47:35\"},{\"latlng\":\"23.7486437,90.392276\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:48:42\"},{\"latlng\":\"23.7489605,90.3923565\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:49:48\"},{\"latlng\":\"23.7489018,90.3924014\",\"area\":\"111, Bir Uttam CR Dutta Road (Sonargaon Road)), Dhaka, Bangladesh,Dhaka,Dhaka Division,Bangladesh\",\"time\":\"12:50:57\"},{\"latlng\":\"23.7492534,90.3916715\",\"area\":\"23\\/G\\/6 Panthapath, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:51:09\"},{\"latlng\":\"23.7483921,90.3918469\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:51:24\"},{\"latlng\":\"23.7489103,90.3924703\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:52:13\"},{\"latlng\":\"23.7487684,90.3926116\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:52:18\"},{\"latlng\":\"23.7483142,90.3918413\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:53:17\"},{\"latlng\":\"23.7482914,90.3918225\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:54:17\"},{\"latlng\":\"23.7483188,90.3918375\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:55:18\"},{\"latlng\":\"23.7482944,90.391803\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:56:03\"},{\"latlng\":\"23.7483026,90.3918064\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:56:59\"},{\"latlng\":\"23.7482975,90.3918127\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:57:41\"},{\"latlng\":\"23.7483234,90.3918297\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:58:59\"},{\"latlng\":\"23.7482896,90.3918204\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:59:56\"},{\"latlng\":\"23.7484001,90.3919562\",\"area\":\"11\\/7 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:00:01\"},{\"latlng\":\"23.7483197,90.3918691\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:00:29\"},{\"latlng\":\"23.7482797,90.3918203\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:00:56\"},{\"latlng\":\"23.7487421,90.3923777\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"13:01:12\"},{\"latlng\":\"23.7487421,90.3923777\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"13:01:12\"},{\"latlng\":\"23.7483118,90.3918262\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:01:56\"},{\"latlng\":\"23.7487168,90.3923114\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:02:48\"},{\"latlng\":\"23.7487168,90.3923114\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:02:48\"},{\"latlng\":\"23.7488667,90.3916145\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:02:57\"},{\"latlng\":\"23.7483494,90.3918413\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:03:25\"},{\"latlng\":\"23.7483424,90.3918531\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:04:25\"},{\"latlng\":\"23.7483651,90.3918519\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:05:26\"},{\"latlng\":\"23.7488146,90.3920609\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:06:27\"},{\"latlng\":\"23.7487348,90.3922577\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:07:28\"},{\"latlng\":\"23.7487198,90.3922435\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:08:40\"},{\"latlng\":\"23.748334,90.3918578\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:10:17\"},{\"latlng\":\"23.7483566,90.3918406\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:11:17\"},{\"latlng\":\"23.7484015,90.3919025\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:12:37\"},{\"latlng\":\"23.7483612,90.3918454\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:12:45\"},{\"latlng\":\"23.7484196,90.3919114\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"13:13:46\"},{\"latlng\":\"23.7484196,90.3919114\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"13:13:46\"},{\"latlng\":\"23.7483748,90.3918718\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:14:45\"},{\"latlng\":\"23.7483748,90.3918718\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:14:46\"},{\"latlng\":\"23.7483595,90.3918557\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:15:46\"},{\"latlng\":\"23.7483595,90.3918557\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:15:46\"},{\"latlng\":\"23.7483222,90.3917859\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:16:47\"},{\"latlng\":\"23.7483222,90.3917859\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:16:47\"},{\"latlng\":\"23.7483594,90.3918318\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:17:41\"},{\"latlng\":\"23.7483704,90.3918476\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:18:22\"},{\"latlng\":\"23.7486535,90.3919914\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:18:39\"},{\"latlng\":\"23.7486535,90.3919914\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:18:43\"},{\"latlng\":\"23.7483108,90.3918336\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:19:22\"},{\"latlng\":\"23.748399,90.3918917\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:19:33\"},{\"latlng\":\"23.748399,90.3918917\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:19:33\"},{\"latlng\":\"23.7483305,90.3918142\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:20:22\"},{\"latlng\":\"23.748656,90.3920609\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:20:55\"},{\"latlng\":\"23.748656,90.3920609\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:20:55\"},{\"latlng\":\"23.7483438,90.3918399\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:21:23\"},{\"latlng\":\"23.7486409,90.3919956\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:22:13\"},{\"latlng\":\"23.7486409,90.3919956\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:22:13\"},{\"latlng\":\"23.7490143,90.3916013\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:22:30\"},{\"latlng\":\"23.7483651,90.3918399\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:23:43\"},{\"latlng\":\"23.7483249,90.3918423\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:24:33\"},{\"latlng\":\"23.7483445,90.3918366\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:25:43\"},{\"latlng\":\"23.7486318,90.3919164\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:26:52\"},{\"latlng\":\"23.7484123,90.3918596\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:27:54\"},{\"latlng\":\"23.7486305,90.3918278\",\"area\":\"11\\/7\\/G Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:29:04\"},{\"latlng\":\"23.7486205,90.3918055\",\"area\":\"11\\/7\\/G Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:30:24\"},{\"latlng\":\"23.7484173,90.3918748\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:31:34\"},{\"latlng\":\"23.749115,90.3920673\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:32:01\"},{\"latlng\":\"23.7484066,90.3918821\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:33:04\"},{\"latlng\":\"23.7484342,90.391875\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"13:33:05\"},{\"latlng\":\"23.7485259,90.391821\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:33:11\"},{\"latlng\":\"23.7486094,90.3918412\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:33:18\"},{\"latlng\":\"23.7486094,90.3918412\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:33:21\"},{\"latlng\":\"23.7486094,90.3918412\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:33:25\"},{\"latlng\":\"23.7486094,90.3918412\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:33:29\"}]', '2018-12-03 03:54:29', '2018-12-03 07:33:33');
INSERT INTO `user_attendances` (`id`, `user_id`, `date`, `cin_time`, `cout_time`, `cin_latlng`, `cout_latlng`, `cin_area`, `cout_area`, `remarks`, `locations`, `created_at`, `updated_at`) VALUES
(25, 5, '2018-12-02', '10:31:37', '16:00:00', '23.7481863,90.3927015', NULL, 'National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh\r\nDhaka - 1205\r\nDhaka Division\r\nBangladesh', NULL, NULL, '[{\"latlng\":\"23.7481863,90.3927015\",\"area\":\"National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh\\nDhaka - 1205\\nDhaka Division\\nBangladesh\",\"time\":\"10:31:39\"}]', '2018-10-16 04:31:37', '2018-10-16 04:31:39');
INSERT INTO `user_attendances` (`id`, `user_id`, `date`, `cin_time`, `cout_time`, `cin_latlng`, `cout_latlng`, `cin_area`, `cout_area`, `remarks`, `locations`, `created_at`, `updated_at`) VALUES
(26, 1, '2018-12-04', '13:16:32', NULL, '23.749327,90.3922793', NULL, '1/C Panthapath, (1st Floor), 1/C পান্থপথ, ঢাকা 1215, Bangladesh,ঢাকা - 1215,ঢাকা বিভাগ,Bangladesh', NULL, NULL, '[{\"latlng\":\"23.7506955,90.3947026\",\"area\":\"3 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"17:50:57\"},{\"latlng\":\"23.7482769,90.3919191\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:51:56\"},{\"latlng\":\"23.7482769,90.3919191\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:51:56\"},{\"latlng\":\"23.7482769,90.3919191\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:51:57\"},{\"latlng\":\"23.7482769,90.3919191\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:51:57\"},{\"latlng\":\"23.7482769,90.3919191\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:51:57\"},{\"latlng\":\"23.7482769,90.3919191\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:52:11\"},{\"latlng\":\"23.7484464,90.391701\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"17:52:39\"},{\"latlng\":\"23.7486035,90.3922931\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:54:04\"},{\"latlng\":\"23.7486035,90.3922931\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:54:04\"},{\"latlng\":\"23.7486646,90.3929557\",\"area\":\"C R, 185 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"17:55:12\"},{\"latlng\":\"23.7483713,90.3930589\",\"area\":\"37 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:55:41\"},{\"latlng\":\"23.7483502,90.3930929\",\"area\":\"110-111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:55:56\"},{\"latlng\":\"23.7483736,90.3918352\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:56:08\"},{\"latlng\":\"23.748366,90.3918351\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:56:55\"},{\"latlng\":\"23.7486009,90.3923987\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:57:07\"},{\"latlng\":\"23.7486009,90.3923987\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:57:07\"},{\"latlng\":\"23.7486009,90.3923987\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:57:07\"},{\"latlng\":\"23.7485286,90.3927065\",\"area\":\"National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:57:57\"},{\"latlng\":\"23.7485821,90.3923745\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:58:15\"},{\"latlng\":\"23.7485821,90.3923745\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:58:15\"},{\"latlng\":\"23.7485821,90.3923745\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:58:15\"},{\"latlng\":\"23.7484393,90.391862\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:58:56\"},{\"latlng\":\"23.7484725,90.3918676\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:59:21\"},{\"latlng\":\"23.7484725,90.3918676\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:59:21\"},{\"latlng\":\"23.7484725,90.3918676\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:59:22\"},{\"latlng\":\"23.7484725,90.3918676\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:59:22\"},{\"latlng\":\"23.748263,90.3919479\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:59:37\"},{\"latlng\":\"23.7483562,90.3918232\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:00:20\"},{\"latlng\":\"23.7483562,90.3918232\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:00:22\"},{\"latlng\":\"23.7485632,90.3923516\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:00:39\"},{\"latlng\":\"23.7485632,90.3923516\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:00:39\"},{\"latlng\":\"23.7485632,90.3923516\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:00:39\"},{\"latlng\":\"23.7485632,90.3923516\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:00:39\"},{\"latlng\":\"23.7485632,90.3923516\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:00:39\"},{\"latlng\":\"23.7482374,90.3923798\",\"area\":\"Anchor Tower, 108, Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:01:21\"},{\"latlng\":\"23.7482374,90.3923798\",\"area\":\"Anchor Tower, 108, Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:01:22\"},{\"latlng\":\"23.7485368,90.3923537\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:01:51\"},{\"latlng\":\"23.7485368,90.3923537\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:01:51\"},{\"latlng\":\"23.7485368,90.3923537\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:01:51\"},{\"latlng\":\"23.7485368,90.3923537\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:01:52\"},{\"latlng\":\"23.7485368,90.3923537\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:01:52\"},{\"latlng\":\"23.748291,90.3918821\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:02:22\"},{\"latlng\":\"23.748291,90.3918821\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:02:22\"},{\"latlng\":\"23.7485436,90.3923657\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:03:00\"},{\"latlng\":\"23.7485436,90.3923657\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:03:01\"},{\"latlng\":\"23.7485436,90.3923657\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:03:01\"},{\"latlng\":\"23.7485436,90.3923657\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:03:01\"},{\"latlng\":\"23.7485436,90.3923657\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:03:01\"},{\"latlng\":\"23.7485235,90.3919439\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:03:23\"},{\"latlng\":\"23.7485235,90.3919439\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:03:23\"},{\"latlng\":\"23.7485235,90.3919439\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:03:35\"},{\"latlng\":\"23.7484256,90.3918663\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:04:00\"},{\"latlng\":\"23.7484534,90.3920119\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:04:02\"},{\"latlng\":\"23.7484534,90.3920119\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:04:02\"},{\"latlng\":\"23.7484534,90.3920119\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:04:03\"},{\"latlng\":\"23.7484534,90.3920119\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:04:03\"},{\"latlng\":\"23.7484534,90.3920119\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:04:03\"},{\"latlng\":\"23.7484534,90.3920119\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:04:04\"},{\"latlng\":\"23.7485035,90.3924846\",\"area\":\"National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:04:08\"},{\"latlng\":\"23.7485035,90.3924846\",\"area\":\"National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:04:10\"},{\"latlng\":\"23.7485035,90.3924846\",\"area\":\"National Plaza, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:04:13\"},{\"latlng\":\"23.7483883,90.3918614\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"18:04:30\"},{\"latlng\":\"23.7483883,90.3918614\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"18:04:30\"},{\"latlng\":\"23.7483883,90.3918614\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"18:04:30\"},{\"latlng\":\"23.7484141,90.3922196\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:04\"},{\"latlng\":\"23.7484141,90.3922196\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:05\"},{\"latlng\":\"23.7484141,90.3922196\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:05\"},{\"latlng\":\"23.7484141,90.3922196\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:05\"},{\"latlng\":\"23.7484141,90.3922196\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:05\"},{\"latlng\":\"23.7484141,90.3922196\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:05\"},{\"latlng\":\"23.7484141,90.3922196\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:05\"},{\"latlng\":\"23.7484154,90.3922086\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:09\"},{\"latlng\":\"23.7484154,90.3922086\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:09\"},{\"latlng\":\"23.7484154,90.3922086\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:09\"},{\"latlng\":\"23.7484021,90.3921833\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:34\"},{\"latlng\":\"23.7484021,90.3921833\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:35\"},{\"latlng\":\"23.7484021,90.3921833\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:05:35\"},{\"latlng\":\"23.7483774,90.3921613\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:09\"},{\"latlng\":\"23.7483774,90.3921613\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:09\"},{\"latlng\":\"23.7483774,90.3921613\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:09\"},{\"latlng\":\"23.7483774,90.3921613\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:10\"},{\"latlng\":\"23.7483774,90.3921613\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:10\"},{\"latlng\":\"23.7483774,90.3921613\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:10\"},{\"latlng\":\"23.7483774,90.3921613\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:10\"},{\"latlng\":\"23.7483774,90.3921613\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:10\"},{\"latlng\":\"23.7483774,90.3921613\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:10\"},{\"latlng\":\"23.7483774,90.3921613\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:11\"},{\"latlng\":\"23.7483573,90.3920793\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:39\"},{\"latlng\":\"23.7483573,90.3920793\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:40\"},{\"latlng\":\"23.7483573,90.3920793\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:06:40\"},{\"latlng\":\"23.7483553,90.3920691\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:14\"},{\"latlng\":\"23.7483553,90.3920691\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:14\"},{\"latlng\":\"23.7483553,90.3920691\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:14\"},{\"latlng\":\"23.7483553,90.3920691\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:15\"},{\"latlng\":\"23.7483553,90.3920691\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:15\"},{\"latlng\":\"23.7483553,90.3920691\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:15\"},{\"latlng\":\"23.7483553,90.3920691\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:15\"},{\"latlng\":\"23.7483553,90.3920691\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:15\"},{\"latlng\":\"23.7483553,90.3920691\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:16\"},{\"latlng\":\"23.7483553,90.3920691\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:16\"},{\"latlng\":\"23.7483639,90.3921272\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:44\"},{\"latlng\":\"23.7483639,90.3921272\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:44\"},{\"latlng\":\"23.7483639,90.3921272\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:07:44\"},{\"latlng\":\"23.7484446,90.3921629\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:19\"},{\"latlng\":\"23.7484446,90.3921629\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:19\"},{\"latlng\":\"23.7484446,90.3921629\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:19\"},{\"latlng\":\"23.7484446,90.3921629\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:20\"},{\"latlng\":\"23.7484446,90.3921629\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:20\"},{\"latlng\":\"23.7484446,90.3921629\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:20\"},{\"latlng\":\"23.7484446,90.3921629\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:20\"},{\"latlng\":\"23.7484446,90.3921629\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:20\"},{\"latlng\":\"23.7484446,90.3921629\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:20\"},{\"latlng\":\"23.7484446,90.3921629\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:21\"},{\"latlng\":\"23.7487816,90.3923371\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:49\"},{\"latlng\":\"23.7487816,90.3923371\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:50\"},{\"latlng\":\"23.7487816,90.3923371\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:08:50\"},{\"latlng\":\"23.7487691,90.3924237\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:19\"},{\"latlng\":\"23.7487691,90.3924237\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:19\"},{\"latlng\":\"23.7487691,90.3924237\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:19\"},{\"latlng\":\"23.7487691,90.3924237\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:20\"},{\"latlng\":\"23.7487691,90.3924237\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:20\"},{\"latlng\":\"23.7487691,90.3924237\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:20\"},{\"latlng\":\"23.7487691,90.3924237\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:20\"},{\"latlng\":\"23.7487691,90.3924237\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:20\"},{\"latlng\":\"23.7487691,90.3924237\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:21\"},{\"latlng\":\"23.7487691,90.3924237\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:21\"},{\"latlng\":\"23.7487699,90.392429\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:49\"},{\"latlng\":\"23.7487699,90.392429\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:49\"},{\"latlng\":\"23.7487699,90.392429\",\"area\":\"Monem Business District, Level-10 111 Bir Uttam C R Dutta Road, Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:09:49\"},{\"latlng\":\"23.7487578,90.3921873\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:10:24\"},{\"latlng\":\"23.7487578,90.3921873\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:10:25\"},{\"latlng\":\"23.7487578,90.3921873\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:10:25\"},{\"latlng\":\"23.7487578,90.3921873\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:10:26\"},{\"latlng\":\"23.7487578,90.3921873\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:10:26\"},{\"latlng\":\"23.7487578,90.3921873\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:10:26\"},{\"latlng\":\"23.7487578,90.3921873\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:10:26\"},{\"latlng\":\"23.7487578,90.3921873\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:10:27\"},{\"latlng\":\"23.7487578,90.3921873\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:10:27\"},{\"latlng\":\"23.7487578,90.3921873\",\"area\":\"111, Bir Uttom C. R. Dutta Road (Sonargoan Road), Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:10:27\"},{\"latlng\":\"23.7485574,90.3919634\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:10:55\"},{\"latlng\":\"23.7485574,90.3919634\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:10:56\"},{\"latlng\":\"23.7485574,90.3919634\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:10:56\"},{\"latlng\":\"23.7484594,90.391842\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:26\"},{\"latlng\":\"23.7484594,90.391842\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:27\"},{\"latlng\":\"23.7484594,90.391842\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:27\"},{\"latlng\":\"23.7484594,90.391842\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:27\"},{\"latlng\":\"23.7484594,90.391842\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:27\"},{\"latlng\":\"23.7484594,90.391842\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:27\"},{\"latlng\":\"23.7484594,90.391842\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:28\"},{\"latlng\":\"23.7484594,90.391842\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:28\"},{\"latlng\":\"23.7484594,90.391842\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:28\"},{\"latlng\":\"23.7484594,90.391842\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:28\"},{\"latlng\":\"23.7484276,90.3918683\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:57\"},{\"latlng\":\"23.7484276,90.3918683\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:57\"},{\"latlng\":\"23.7484276,90.3918683\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:11:57\"},{\"latlng\":\"23.7485603,90.3918076\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:27\"},{\"latlng\":\"23.7485603,90.3918076\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:27\"},{\"latlng\":\"23.7485603,90.3918076\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:27\"},{\"latlng\":\"23.7485603,90.3918076\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:28\"},{\"latlng\":\"23.7485603,90.3918076\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:28\"},{\"latlng\":\"23.7485603,90.3918076\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:28\"},{\"latlng\":\"23.7485603,90.3918076\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:28\"},{\"latlng\":\"23.7485603,90.3918076\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:28\"},{\"latlng\":\"23.7485603,90.3918076\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:29\"},{\"latlng\":\"23.7485603,90.3918076\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:29\"},{\"latlng\":\"23.7482298,90.3921819\",\"area\":\"Anchor Tower, 108, Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:12:59\"},{\"latlng\":\"23.7482298,90.3921819\",\"area\":\"Anchor Tower, 108, Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:00\"},{\"latlng\":\"23.7482298,90.3921819\",\"area\":\"Anchor Tower, 108, Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:00\"},{\"latlng\":\"23.7483856,90.3921687\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:29\"},{\"latlng\":\"23.7483856,90.3921687\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:29\"},{\"latlng\":\"23.7483856,90.3921687\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:29\"},{\"latlng\":\"23.7483856,90.3921687\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:30\"},{\"latlng\":\"23.7483856,90.3921687\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:30\"},{\"latlng\":\"23.7483856,90.3921687\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:30\"},{\"latlng\":\"23.7483856,90.3921687\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:30\"},{\"latlng\":\"23.7483856,90.3921687\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:31\"},{\"latlng\":\"23.7483856,90.3921687\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:31\"},{\"latlng\":\"23.7483856,90.3921687\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:13:31\"},{\"latlng\":\"23.7483758,90.3921791\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:14:01\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:01\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:01\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:02\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:02\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:02\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:02\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:02\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:03\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:03\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:03\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:03\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:03\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:04\"},{\"latlng\":\"23.7471938,90.3910835\",\"area\":\"251 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:15:04\"},{\"latlng\":\"23.7481428,90.392022\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:16:00\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:16:59\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:00\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:00\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:00\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:00\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:00\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:01\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:01\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:01\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:01\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:01\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:02\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:02\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:02\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:02\"},{\"latlng\":\"23.7483066,90.3922802\",\"area\":\"SGS Bangladesh Limited, Noor Tower, 110 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:02\"},{\"latlng\":\"23.7483339,90.3922848\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:15\"},{\"latlng\":\"23.7482783,90.3918496\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:17:34\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:09\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:09\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:09\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:09\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:10\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:10\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:10\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:10\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:10\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:10\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:11\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:11\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:11\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:11\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:11\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:12\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:12\"},{\"latlng\":\"23.7483042,90.3918869\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:12\"},{\"latlng\":\"23.7485197,90.3919415\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:18:36\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:27\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:27\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:27\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:28\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:28\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:28\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:28\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:28\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:29\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:29\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:29\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:29\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:30\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:30\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:30\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:30\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:30\"},{\"latlng\":\"23.7481967,90.3918671\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:31\"},{\"latlng\":\"23.7482103,90.3918651\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:19:37\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:30\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:30\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:30\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:31\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:31\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:31\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:31\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:31\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:32\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:32\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:32\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:32\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:32\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:33\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:33\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:33\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:33\"},{\"latlng\":\"23.7482829,90.3920363\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:33\"},{\"latlng\":\"23.7483251,90.3921737\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:40\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:30\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:30\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:30\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:31\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:31\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:31\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:31\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:31\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:32\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:32\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:32\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:32\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:32\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:33\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:33\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:33\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:33\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:33\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:21:40\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:31\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:31\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:31\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:31\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:31\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:32\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:32\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:32\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:32\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:32\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:33\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:33\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:33\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:33\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:33\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:34\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:34\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:34\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:45\"},{\"latlng\":\"23.7483282,90.3921818\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:22:54\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:54\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:55\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:55\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:55\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:55\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:56\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:56\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:56\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:56\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:56\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:56\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:57\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:57\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:57\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:57\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:58\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:58\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:58\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:58\"},{\"latlng\":\"23.7482928,90.3921082\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:23:58\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:01\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:01\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:01\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:01\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:02\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:02\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:02\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:02\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:03\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:03\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:03\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:03\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:03\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:04\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:04\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:04\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:04\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:04\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:05\"},{\"latlng\":\"23.7484508,90.3918841\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"18:25:05\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:06\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:06\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:06\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:06\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:07\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:07\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:07\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:07\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:08\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:08\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:08\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:08\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:08\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:09\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:09\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:09\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:09\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:10\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:10\"},{\"latlng\":\"23.7482899,90.3918783\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:26:10\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:11\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:11\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:12\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:12\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:12\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:12\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:12\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:13\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:13\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:13\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:13\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:13\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:14\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:14\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:14\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:14\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:14\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:15\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:15\"},{\"latlng\":\"23.748256,90.3920577\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:27:15\"}]', '2018-12-04 07:16:32', '2018-12-04 12:27:15');
INSERT INTO `user_attendances` (`id`, `user_id`, `date`, `cin_time`, `cout_time`, `cin_latlng`, `cout_latlng`, `cin_area`, `cout_area`, `remarks`, `locations`, `created_at`, `updated_at`) VALUES
(27, 1, '2018-12-05', '12:07:46', '17:02:44', '23.7482879,90.3918759', '23.7483536,90.3918479', 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, '[{\"latlng\":\"23.7482879,90.3918759\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:07:57\"},{\"latlng\":\"23.7483296,90.3918581\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:08:30\"},{\"latlng\":\"23.7483296,90.3918581\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:12:02\"},{\"latlng\":\"23.7484081,90.3918408\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:26:01\"},{\"latlng\":\"23.7489319,90.3920875\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:41:31\"},{\"latlng\":\"23.7489543,90.3920514\",\"area\":\"111 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:44:39\"},{\"latlng\":\"23.7489543,90.3920514\",\"area\":\"111 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:45:53\"},{\"latlng\":\"23.7489543,90.3920514\",\"area\":\"111 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:47:20\"},{\"latlng\":\"23.7489543,90.3920514\",\"area\":\"111 Sonargaon Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:47:26\"},{\"latlng\":\"23.7483663,90.3917749\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:49:02\"},{\"latlng\":\"23.7483663,90.3917749\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:49:02\"},{\"latlng\":\"23.7483663,90.3917749\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:49:03\"},{\"latlng\":\"23.7483663,90.3917749\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:49:03\"},{\"latlng\":\"23.7483663,90.3917749\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:49:03\"},{\"latlng\":\"23.7477244,90.3915043\",\"area\":\"4, Free School St, Second Floor, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:49:58\"},{\"latlng\":\"23.7484106,90.3918345\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:58:08\"},{\"latlng\":\"23.7491149,90.3921886\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:58:57\"},{\"latlng\":\"23.7491149,90.3921886\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:01:46\"},{\"latlng\":\"23.7491149,90.3921886\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:02:49\"},{\"latlng\":\"23.7484711,90.3918924\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"13:07:46\"},{\"latlng\":\"23.7494523,90.3919657\",\"area\":\"1\\/C Panthapath, (1st Floor), 1\\/C \\u09aa\\u09be\\u09a8\\u09cd\\u09a5\\u09aa\\u09a5, \\u09a2\\u09be\\u0995\\u09be 1215, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1215,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:09:02\"},{\"latlng\":\"23.7483552,90.391877\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:22:42\"},{\"latlng\":\"23.7483552,90.391877\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:25:00\"},{\"latlng\":\"23.748407,90.3918575\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:40:29\"},{\"latlng\":\"23.7483915,90.391852\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"13:57:10\"},{\"latlng\":\"23.7483245,90.3918722\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:00:29\"},{\"latlng\":\"23.7483883,90.3918258\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:08:00\"},{\"latlng\":\"23.7483883,90.3918258\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:08:00\"},{\"latlng\":\"23.7483883,90.3918258\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:08:07\"},{\"latlng\":\"23.7483883,90.3918258\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:08:12\"},{\"latlng\":\"23.7487367,90.392027\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:08:19\"},{\"latlng\":\"23.7487367,90.392027\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:08:26\"},{\"latlng\":\"23.7487367,90.392027\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:10:26\"},{\"latlng\":\"23.7487367,90.392027\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:11:00\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:22:57\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:23:19\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:23:22\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:23:31\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:23:33\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:23:36\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:23:38\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:23:40\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:23:42\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:25:30\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:25:35\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:25:38\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:25:44\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:25:47\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:25:49\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:28:23\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:28:30\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:28:58\"},{\"latlng\":\"23.7482192,90.3918584\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:29:07\"},{\"latlng\":\"23.7482784,90.3918479\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:35:01\"},{\"latlng\":\"23.7485222,90.3921032\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:36:33\"},{\"latlng\":\"23.7485222,90.3921032\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:38:07\"},{\"latlng\":\"23.7485222,90.3921032\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:38:54\"},{\"latlng\":\"23.7485222,90.3921032\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:39:07\"},{\"latlng\":\"23.7485222,90.3921032\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:41:10\"},{\"latlng\":\"23.7482499,90.3919125\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:42:49\"},{\"latlng\":\"23.7482499,90.3919125\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:43:29\"},{\"latlng\":\"23.7482499,90.3919125\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:43:38\"},{\"latlng\":\"23.7482499,90.3919125\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:46:38\"},{\"latlng\":\"23.7483663,90.3918256\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:49:39\"},{\"latlng\":\"23.7482634,90.3915271\",\"area\":\"8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"14:49:53\"},{\"latlng\":\"23.7482634,90.3915271\",\"area\":\"8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"14:54:49\"},{\"latlng\":\"23.7482634,90.3915271\",\"area\":\"8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"14:55:03\"},{\"latlng\":\"23.7482634,90.3915271\",\"area\":\"8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"14:55:54\"},{\"latlng\":\"23.7482582,90.3919033\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:57:14\"},{\"latlng\":\"23.7483138,90.3917644\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:57:30\"},{\"latlng\":\"23.7483138,90.3917644\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:59:10\"},{\"latlng\":\"23.7483138,90.3917644\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:00:27\"},{\"latlng\":\"23.7482691,90.3918568\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:04:10\"},{\"latlng\":\"23.7482691,90.3918568\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:04:10\"},{\"latlng\":\"23.7482691,90.3918568\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:04:11\"},{\"latlng\":\"23.7482691,90.3918568\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:04:11\"},{\"latlng\":\"23.7482691,90.3918568\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:04:11\"},{\"latlng\":\"23.7482632,90.3919492\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:06:24\"},{\"latlng\":\"23.7482632,90.3919492\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:08:06\"},{\"latlng\":\"23.7482595,90.3918499\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:08:47\"},{\"latlng\":\"23.7482595,90.3918499\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:08:47\"},{\"latlng\":\"23.7483971,90.3918578\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:18:11\"},{\"latlng\":\"23.748263,90.3918844\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:20:14\"},{\"latlng\":\"23.748263,90.3918844\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:20:53\"},{\"latlng\":\"23.748263,90.3918844\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:21:36\"},{\"latlng\":\"23.748263,90.3918844\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:21:48\"},{\"latlng\":\"23.7484532,90.3918362\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:25:21\"},{\"latlng\":\"23.7484532,90.3918362\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:25:21\"},{\"latlng\":\"23.7484532,90.3918362\",\"area\":\"Holding No-11\\/7-G-17, Free School Street, Box Culvert, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:26:20\"},{\"latlng\":\"23.7483099,90.3918429\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:32:22\"},{\"latlng\":\"23.7480819,90.3918498\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:38:02\"},{\"latlng\":\"23.7483892,90.3918336\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:40:28\"},{\"latlng\":\"23.7483746,90.3920384\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:41:41\"},{\"latlng\":\"23.7483746,90.3920384\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:43:34\"},{\"latlng\":\"23.7483746,90.3920384\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:45:30\"},{\"latlng\":\"23.7483746,90.3920384\",\"area\":\"Tropical Home Park View, 1st Floor, B-1, 9\\/1-4 Free School School Street, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:46:28\"},{\"latlng\":\"23.7483968,90.3918271\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:47:42\"},{\"latlng\":\"23.748418,90.3918368\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:48:29\"},{\"latlng\":\"23.748418,90.3918368\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:49:26\"},{\"latlng\":\"23.748418,90.3918368\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:50:32\"},{\"latlng\":\"23.748418,90.3918368\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:52:35\"},{\"latlng\":\"23.748418,90.3918368\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:54:17\"},{\"latlng\":\"23.7483421,90.3917697\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:56:20\"},{\"latlng\":\"23.7483421,90.3917697\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:56:21\"},{\"latlng\":\"23.7486068,90.3920438\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:58:02\"},{\"latlng\":\"23.7486068,90.3920438\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:59:04\"},{\"latlng\":\"23.7486068,90.3920438\",\"area\":\"9\\/1, 9\\/2 Culvert Road, \\u09a2\\u09be\\u0995\\u09be, Bangladesh,\\u09a2\\u09be\\u0995\\u09be,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:59:07\"},{\"latlng\":\"23.7484551,90.3918863\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"16:13:08\"},{\"latlng\":\"23.7484551,90.3918863\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"16:13:08\"},{\"latlng\":\"23.7484551,90.3918863\",\"area\":\"11\\/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Bangladesh\",\"time\":\"16:13:09\"},{\"latlng\":\"23.7482733,90.3918387\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:30:30\"},{\"latlng\":\"23.7482733,90.3918387\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:30:30\"},{\"latlng\":\"23.7482733,90.3918387\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:30:30\"},{\"latlng\":\"23.7482733,90.3918387\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:33:00\"},{\"latlng\":\"23.7482733,90.3918387\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:33:49\"},{\"latlng\":\"23.7482733,90.3918387\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:34:17\"},{\"latlng\":\"23.7482733,90.3918387\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:34:42\"},{\"latlng\":\"23.7482613,90.3918519\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:45:30\"},{\"latlng\":\"23.7482613,90.3918519\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:51:00\"},{\"latlng\":\"23.7483863,90.3918364\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:54:51\"},{\"latlng\":\"23.7483863,90.3918364\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:55:39\"},{\"latlng\":\"23.7483863,90.3918364\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:55:45\"},{\"latlng\":\"23.7483863,90.3918364\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:56:04\"},{\"latlng\":\"23.7483863,90.3918364\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:56:47\"},{\"latlng\":\"23.7483863,90.3918364\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:58:08\"},{\"latlng\":\"23.7483536,90.3918479\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:58:21\"},{\"latlng\":\"23.7483536,90.3918479\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:58:32\"}]', '2018-12-05 06:07:46', '2018-12-05 11:02:44'),
(28, 1, '2018-12-06', '10:17:40', '12:52:40', '23.7483296,90.3918128', '23.7486867,90.3922574', 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', '111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, '[{\"latlng\":\"23.7483423,90.3917912\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:18:15\"},{\"latlng\":\"23.7483449,90.3917604\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:27:21\"},{\"latlng\":\"23.7487749,90.3919952\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"10:28:30\"},{\"latlng\":\"23.7487749,90.3919952\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"10:28:55\"},{\"latlng\":\"23.7482631,90.3918624\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:45:29\"},{\"latlng\":\"23.7482631,90.3918624\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:45:29\"}]', '2018-12-06 04:17:41', '2018-12-06 06:52:40'),
(29, 1, '2018-12-08', '10:26:23', NULL, '23.748351,90.3917812', NULL, 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, '[{\"latlng\":\"23.7484048,90.3917746\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"10:28:55\"},{\"latlng\":\"23.7491049,90.3921256\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:33:17\"},{\"latlng\":\"23.7491049,90.3921256\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:33:23\"},{\"latlng\":\"23.7483777,90.3918103\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:35:16\"},{\"latlng\":\"23.7483777,90.3918103\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:35:16\"},{\"latlng\":\"23.7483502,90.3917983\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:35:43\"},{\"latlng\":\"23.7483502,90.3917983\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:40:01\"},{\"latlng\":\"23.7483502,90.3917983\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:40:04\"},{\"latlng\":\"23.7484059,90.3918186\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"10:52:11\"},{\"latlng\":\"23.7484059,90.3918186\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"10:52:11\"},{\"latlng\":\"23.7484059,90.3918186\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"10:52:11\"},{\"latlng\":\"23.7484059,90.3918186\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"10:52:12\"},{\"latlng\":\"23.7484059,90.3918186\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"10:52:12\"},{\"latlng\":\"23.7483042,90.3918727\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:55:53\"},{\"latlng\":\"23.7483091,90.3918118\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:06:49\"},{\"latlng\":\"23.7483091,90.3918118\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:06:50\"},{\"latlng\":\"23.7500127,90.389822\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:12:42\"},{\"latlng\":\"23.7484028,90.3918438\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:23:29\"},{\"latlng\":\"23.7484028,90.3918438\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:23:30\"},{\"latlng\":\"23.7484028,90.3918438\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:23:30\"},{\"latlng\":\"23.7482814,90.3918345\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:40:32\"},{\"latlng\":\"23.7482814,90.3918345\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:40:32\"},{\"latlng\":\"23.7482814,90.3918345\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:40:32\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:57:11\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:57:11\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:57:11\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:14:20\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:14:21\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:14:21\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:31:14\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:31:14\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:31:14\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:50:14\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:50:14\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"13:50:14\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:10:00\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:10:01\"},{\"latlng\":\"23.7482561,90.3919029\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:10:01\"},{\"latlng\":\"23.7484223,90.3918368\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:41:57\"},{\"latlng\":\"23.7484223,90.3918368\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:41:57\"},{\"latlng\":\"23.7484223,90.3918368\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"14:41:58\"},{\"latlng\":\"23.7483403,90.3918442\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:42:06\"},{\"latlng\":\"23.7483197,90.391851\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:50:05\"},{\"latlng\":\"23.7482146,90.3918283\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:53:31\"},{\"latlng\":\"23.7482146,90.3918283\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:54:51\"},{\"latlng\":\"23.7482146,90.3918283\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:55:02\"},{\"latlng\":\"23.7481886,90.3918875\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:29:34\"},{\"latlng\":\"23.7482327,90.3918647\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:30:32\"},{\"latlng\":\"23.7482327,90.3918647\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:30:33\"},{\"latlng\":\"23.7482327,90.3918647\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:30:33\"},{\"latlng\":\"23.7482327,90.3918647\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:30:33\"},{\"latlng\":\"23.7482327,90.3918647\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:30:34\"},{\"latlng\":\"23.7482327,90.3918647\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:30:35\"},{\"latlng\":\"23.7484105,90.3918742\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:41:30\"},{\"latlng\":\"23.7484105,90.3918742\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:41:30\"},{\"latlng\":\"23.7484105,90.3918742\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:41:30\"},{\"latlng\":\"23.7484105,90.3918742\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:41:30\"},{\"latlng\":\"23.7484105,90.3918742\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:41:30\"},{\"latlng\":\"23.7484105,90.3918742\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:41:31\"},{\"latlng\":\"23.7484105,90.3918742\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:41:31\"},{\"latlng\":\"23.7483878,90.3917781\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"16:43:36\"},{\"latlng\":\"23.7483878,90.3917781\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"16:43:37\"},{\"latlng\":\"23.7483878,90.3917781\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"16:43:37\"},{\"latlng\":\"23.7483878,90.3917781\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"16:43:37\"},{\"latlng\":\"23.7483878,90.3917781\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"16:43:37\"},{\"latlng\":\"23.7483878,90.3917781\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"16:43:39\"},{\"latlng\":\"23.7483878,90.3917781\",\"area\":\"8 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Mymensingh Division,Bangladesh\",\"time\":\"16:43:39\"},{\"latlng\":\"23.7482349,90.3918532\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:02:05\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:57\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:57\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:57\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:57\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:58\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:58\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:58\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:58\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:58\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:59\"},{\"latlng\":\"23.7483745,90.3918364\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:42:59\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:31\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:31\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:31\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:32\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:32\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:32\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:32\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:32\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:33\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:33\"},{\"latlng\":\"23.7483406,90.3918807\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"17:45:33\"}]', '2018-12-08 04:26:24', '2018-12-08 11:45:33'),
(31, 1, '2018-12-09', '12:09:41', NULL, '23.7484051,90.3917673', NULL, 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, '[{\"latlng\":\"23.7484051,90.3917673\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:09:47\"},{\"latlng\":\"23.7490723,90.3922306\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:21:58\"},{\"latlng\":\"23.7490723,90.3922306\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:21:58\"},{\"latlng\":\"23.7490723,90.3922306\",\"area\":\"Road, Sonargaon, 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"12:21:58\"},{\"latlng\":\"23.7482205,90.3918631\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:59:39\"},{\"latlng\":\"23.7482205,90.3918631\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:01:16\"}]', '2018-12-09 06:09:41', '2018-12-09 09:01:16'),
(32, 1, '2018-12-10', '11:46:01', NULL, '23.7502294,90.3910303', NULL, '129 Bir Uttam Kazi Nuruzzaman Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, '[{\"latlng\":\"23.7502294,90.3910303\",\"area\":\"129 Bir Uttam Kazi Nuruzzaman Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:50:51\"},{\"latlng\":\"23.7502294,90.3910303\",\"area\":\"129 Bir Uttam Kazi Nuruzzaman Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:50:57\"},{\"latlng\":\"23.7483708,90.3918524\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:41:36\"},{\"latlng\":\"23.7483442,90.3918576\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:44:37\"},{\"latlng\":\"23.7484763,90.391886\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:46:57\"}]', '2018-12-10 05:46:01', '2018-12-10 10:46:57'),
(33, 5, '2018-12-10', '16:54:30', NULL, '23.7483401,90.3918925', NULL, 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, 'ami asi', NULL, '2018-12-10 10:54:30', '2018-12-10 10:54:30'),
(34, 1, '2018-12-11', '11:34:22', NULL, '23.7483531,90.3918874', NULL, 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, '[{\"latlng\":\"23.7482528,90.3918659\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:48:30\"},{\"latlng\":\"23.7482528,90.3918659\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:48:30\"},{\"latlng\":\"23.7482795,90.3918273\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:05:32\"},{\"latlng\":\"23.7482795,90.3918273\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:05:32\"},{\"latlng\":\"23.7484231,90.3918613\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:19:49\"},{\"latlng\":\"23.7484231,90.3918613\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:19:49\"},{\"latlng\":\"23.7487457,90.3919688\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:22:18\"},{\"latlng\":\"23.7487457,90.3919688\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:22:18\"},{\"latlng\":\"23.7484002,90.3918437\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:25:23\"},{\"latlng\":\"23.7484002,90.3918437\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"16:25:23\"},{\"latlng\":\"23.7483624,90.3918743\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:40:51\"},{\"latlng\":\"23.7483624,90.3918743\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:40:51\"}]', '2018-12-11 05:34:22', '2018-12-11 10:40:51'),
(36, 5, '2018-12-11', '15:16:55', '15:18:29', '23.7483277,90.3918755', '23.7481696,90.3920206', 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', '111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', 'jhhsj', '[{\"latlng\":\"23.7481696,90.3920206\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:17:46\"}]', '2018-12-11 09:16:55', '2018-12-11 09:18:30'),
(40, 5, '2018-12-11', '15:50:32', '15:50:35', '23.7481777,90.3915982', '23.7481777,90.3915982', '8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', '8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, '2018-12-11 09:50:32', '2018-12-11 09:50:35');
INSERT INTO `user_attendances` (`id`, `user_id`, `date`, `cin_time`, `cout_time`, `cin_latlng`, `cout_latlng`, `cin_area`, `cout_area`, `remarks`, `locations`, `created_at`, `updated_at`) VALUES
(41, 5, '2018-12-12', '15:24:00', NULL, '23.74834,90.3918479', NULL, 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, '[{\"latlng\":\"23.7483377,90.3918553\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:40:37\"},{\"latlng\":\"23.7483231,90.391852\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"16:33:46\"},{\"latlng\":\"23.7483813,90.391865\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"18:09:24\"},{\"latlng\":\"23.7482939,90.3918279\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"18:20:51\"}]', '2018-12-12 09:24:00', '2018-12-12 12:20:51'),
(42, 5, '2018-12-13', '10:30:50', '14:05:09', '23.7484742,90.3919386', '23.7482107,90.3918659', '11/7H, Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', 'check out today', '[{\"latlng\":\"23.7481857,90.391879\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:35:12\"},{\"latlng\":\"23.7481857,90.391879\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:37:12\"},{\"latlng\":\"23.7481857,90.391879\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:39:12\"},{\"latlng\":\"23.7481857,90.391879\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:41:27\"},{\"latlng\":\"23.7481857,90.391879\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:43:34\"},{\"latlng\":\"23.7481857,90.391879\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:45:35\"},{\"latlng\":\"23.7481857,90.391879\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:48:01\"},{\"latlng\":\"23.7481857,90.391879\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:53:01\"},{\"latlng\":\"23.7482265,90.3918658\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"10:54:42\"},{\"latlng\":\"23.7482115,90.3918726\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:11:22\"},{\"latlng\":\"23.748224,90.3918562\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:25:28\"},{\"latlng\":\"23.7481654,90.3919263\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:32:04\"},{\"latlng\":\"23.7482212,90.3918467\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:48:44\"},{\"latlng\":\"23.7482502,90.391842\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"11:55:57\"},{\"latlng\":\"23.7484624,90.39186\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:02:07\"},{\"latlng\":\"23.7482181,90.3918594\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:19:12\"},{\"latlng\":\"23.748276,90.3918777\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:25:46\"},{\"latlng\":\"23.7481986,90.3918692\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:32:04\"},{\"latlng\":\"23.7482385,90.391863\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:40:23\"},{\"latlng\":\"23.7481867,90.3918667\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:42:29\"},{\"latlng\":\"23.7481821,90.3918961\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"12:55:17\"},{\"latlng\":\"23.7481586,90.391875\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:00:49\"},{\"latlng\":\"23.7481586,90.391875\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:04:33\"},{\"latlng\":\"23.7482107,90.3918659\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:04:41\"},{\"latlng\":\"23.7482107,90.3918659\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:04:41\"}]', '2018-12-13 04:30:50', '2018-12-13 08:05:09'),
(43, 6, '2018-12-13', '14:03:45', '14:17:42', '23.7481657,90.3919221', '23.7482076,90.3918707', '111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', '111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, '[{\"latlng\":\"23.7482199,90.3918666\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:04:00\"},{\"latlng\":\"23.7482199,90.3918666\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:04:40\"},{\"latlng\":\"23.7482077,90.3918716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:04:57\"},{\"latlng\":\"23.7482077,90.3918716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:06:57\"},{\"latlng\":\"23.7482077,90.3918716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:06:57\"},{\"latlng\":\"23.7482077,90.3918716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:07:29\"},{\"latlng\":\"23.7482077,90.3918716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:08:57\"},{\"latlng\":\"23.7482077,90.3918716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:08:57\"},{\"latlng\":\"23.7482077,90.3918716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:08:57\"},{\"latlng\":\"23.7482077,90.3918716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:10:57\"},{\"latlng\":\"23.7482077,90.3918716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:10:57\"},{\"latlng\":\"23.7482077,90.3918716\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:10:57\"},{\"latlng\":\"23.7482076,90.3918707\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:12:46\"},{\"latlng\":\"23.7482076,90.3918707\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:12:46\"},{\"latlng\":\"23.7482076,90.3918707\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:14:46\"},{\"latlng\":\"23.7482076,90.3918707\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:14:46\"},{\"latlng\":\"23.7482076,90.3918707\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:14:46\"},{\"latlng\":\"23.7482076,90.3918707\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:16:46\"},{\"latlng\":\"23.7482076,90.3918707\",\"area\":\"111 Bir Uttam CR Dutta Rd, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:16:46\"}]', '2018-12-13 08:03:45', '2018-12-13 08:17:42'),
(44, 6, '2018-12-17', '11:34:52', NULL, '23.7482114,90.3918622', NULL, NULL, NULL, NULL, NULL, '2018-12-17 05:34:52', '2018-12-17 05:34:52'),
(45, 6, '2018-12-18', '10:06:54', NULL, '23.7483565,90.3918759', NULL, 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, NULL, '2018-12-18 04:06:55', '2018-12-18 04:06:55'),
(46, 6, '2018-12-18', '12:17:35', NULL, '23.7483648,90.3917667', NULL, 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, NULL, '2018-12-18 06:17:35', '2018-12-18 06:17:35'),
(47, 1, '2018-12-18', '14:42:31', NULL, '23.7483006,90.3917691', NULL, 'Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, '[{\"latlng\":\"23.7483006,90.3917691\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:42:45\"},{\"latlng\":\"23.7483006,90.3917691\",\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:42:57\"},{\"latlng\":\"23.748381,90.3918121\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:00:01\"},{\"latlng\":\"23.7483975,90.3918218\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:17:57\"},{\"latlng\":\"23.7483975,90.3918218\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:17:57\"},{\"latlng\":\"23.7483975,90.3918218\",\"area\":\"Samsung R&D Institute Bangladesh Ltd., 111 Bir Uttam CR Dutta Rd, \\u09a2\\u09be\\u0995\\u09be 1205, Bangladesh,\\u09a2\\u09be\\u0995\\u09be - 1205,\\u09a2\\u09be\\u0995\\u09be \\u09ac\\u09bf\\u09ad\\u09be\\u0997,Bangladesh\",\"time\":\"15:17:57\"},{\"latlng\":\"23.7482553,90.3917229\",\"area\":\"8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:34:37\"},{\"latlng\":\"23.7482553,90.3917229\",\"area\":\"8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:34:37\"},{\"latlng\":\"23.7482553,90.3917229\",\"area\":\"8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:34:37\"}]', '2018-12-18 08:42:31', '2018-12-18 09:34:38'),
(48, 1, '2018-12-24', '11:50:59', NULL, '23.7482252,90.3916885', NULL, '8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, '[{\\\"latlng\\\":[23.748518,90.391321],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:43:11\\\"},{\\\"latlng\\\":[23.745921,90.39248],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:43:36\\\"},{\\\"latlng\\\":[23.741438,90.39174],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:43:52\\\"},{\\\"latlng\\\":[23.738423,90.390715],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:44:10\\\"},{\\\"latlng\\\":[23.732795,90.387153],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:44:44\\\"},{\\\"latlng\\\":[23.732358,90.391171],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:44:58\\\"},{\\\"latlng\\\":[23.732982,90.395699],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:45:15\\\"},{\\\"latlng\\\":[23.727516,90.399936],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:45:34\\\"},{\\\"latlng\\\":[23.729593,90.405156],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:45:49\\\"},{\\\"latlng\\\":[23.734759,90.400661],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:46:08\\\"},{\\\"latlng\\\":[23.736709,90.39763],\\\"area\\\":\\\"noor tower\\\",\\\"time\\\":\\\"11:46:28\\\"}]', '2018-12-26 05:50:59', '2018-12-26 09:12:57'),
(49, 5, '2018-12-27', '15:58:48', NULL, '23.7482216,90.3917115', NULL, '8,9 & 10, 3 Free School St, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh', NULL, NULL, NULL, '2018-12-27 09:58:48', '2018-12-27 09:58:48'),
(50, 1, '2019-03-23', '19:22:00', '19:25:05', '23.7590243,90.390071', '23.7590348,90.3900719', '19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', '19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', NULL, '[{\"latlng\":[23.7589853,90.3900746],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"19:23:23\"},{\"latlng\":[23.7590348,90.3900719],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"19:24:41\"}]', '2019-03-23 13:22:00', '2019-03-23 13:25:05'),
(51, 5, '2019-03-24', '09:31:58', NULL, '23.7591479,90.3900206', NULL, 'Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', NULL, NULL, '[{\"latlng\":[23.7591479,90.3900206],\"area\":\"Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"09:32:14\"},{\"latlng\":[23.7591074,90.3900362],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"09:33:00\"},{\"latlng\":[23.7590196,90.3900743],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"09:34:14\"},{\"latlng\":[23.7590196,90.3900743],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"09:34:14\"}]', '2019-03-24 03:31:58', '2019-03-24 03:34:14'),
(52, 65, '2019-03-31', '09:31:58', '09:34:14', '23.7590455,90.3900805', '23.7590455,90.3900805', '19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', '19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', NULL, '[{\"latlng\":[23.7591479,90.3900206],\"area\":\"Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"09:32:14\"},{\"latlng\":[23.7591074,90.3900362],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"09:33:00\"},{\"latlng\":[23.7590196,90.3900743],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"09:34:14\"},{\"latlng\":[23.7590196,90.3900743],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"09:34:14\"}]', '2019-03-31 14:14:56', '2019-03-31 14:15:02'),
(53, 65, '2019-04-01', '08:21:57', '12:59:25', '23.7886534,90.3750528', '23.7590757,90.3899589', '609/1 Shameem Sharani, Dhaka, Bangladesh,Dhaka,Dhaka Division,Bangladesh', '31 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', NULL, '[{\"latlng\":[23.7591047,90.3900613],\"area\":\"Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:04:22\"},{\"latlng\":[23.7591869,90.390025],\"area\":\"Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:19:22\"},{\"latlng\":[23.7591869,90.390025],\"area\":\"Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:19:22\"}]', '2019-04-01 02:21:57', '2019-04-01 06:59:25'),
(54, 70, '2019-04-01', '08:22:38', '09:36:31', '23.7886534,90.3750528', '23.7591625,90.3900448', '609/1 Shameem Sharani, Dhaka, Bangladesh,Dhaka,Dhaka Division,Bangladesh', '19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', NULL, NULL, '2019-04-01 02:22:38', '2019-04-01 03:36:31'),
(55, 13, '2019-04-01', '10:13:24', '19:25:19', '23.759183,90.3900378', '23.7581664,90.3867119', 'Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', '27 Indira Rd, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', NULL, '[{\"latlng\":[23.759183,90.3900378],\"area\":\"Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"10:13:25\"},{\"latlng\":[23.759179,90.3900271],\"area\":\"Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"10:47:06\"},{\"latlng\":[23.759179,90.3900271],\"area\":\"Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"10:47:07\"}]', '2019-04-01 04:13:24', '2019-04-01 13:25:19'),
(56, 14, '2019-04-01', '10:29:21', NULL, '23.7591067,90.3900668', NULL, '19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', NULL, NULL, '[{\"latlng\":[23.7591067,90.3900668],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"10:29:22\"},{\"latlng\":[23.7590901,90.390073],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"10:43:23\"},{\"latlng\":[23.7590901,90.390073],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"10:47:39\"},{\"latlng\":[23.7590455,90.3900805],\"area\":\"Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:03:57\"},{\"latlng\":[23.7590455,90.3900805],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:03:57\"},{\"latlng\":[23.7590455,90.3900805],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:03:57\"},{\"latlng\":[23.7590455,90.3900805],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:03:57\"},{\"latlng\":[23.7590455,90.3900805],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:03:57\"},{\"latlng\":[23.7590455,90.3900805],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:03:57\"},{\"latlng\":[23.7590455,90.3900805],\"area\":\"19 Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:03:57\"}]', '2019-04-01 04:29:21', '2019-04-01 05:03:57'),
(57, 6, '2019-04-01', '11:11:07', NULL, '23.7596375,90.3879319', NULL, 'Khamar Bari Rd, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', NULL, NULL, '[{\"latlng\":[23.7596375,90.3879319],\"area\":\"Khamar Bari Rd, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:11:07\"},{\"latlng\":[23.7596375,90.3879319],\"area\":\"Khamar Bari Rd, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:14:11\"},{\"latlng\":[23.7596375,90.3879319],\"area\":\"Khamar Bari Rd, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:25:33\"},{\"latlng\":[23.7596375,90.3879319],\"area\":\"Khamar Bari Rd, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:25:33\"},{\"latlng\":[23.7596375,90.3879319],\"area\":\"Khamar Bari Rd, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"11:29:32\"},{\"latlng\":[23.7596375,90.3879319],\"area\":\"Khamar Bari Rd, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"12:16:42\"},{\"latlng\":[23.7596375,90.3879319],\"area\":\"Khamar Bari Rd, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"12:28:11\"},{\"latlng\":[23.7596375,90.3879319],\"area\":\"Khamar Bari Rd, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"12:28:11\"},{\"latlng\":[23.7484994,90.391711],\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:24:49\"},{\"latlng\":[23.7484542,90.3916776],\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"15:47:48\"}]', '2019-04-01 05:11:07', '2019-04-01 09:47:48'),
(58, 5, '2019-04-01', '12:02:31', NULL, '23.7592249,90.3899586', NULL, 'Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh', NULL, NULL, '[{\"latlng\":[23.7592249,90.3899586],\"area\":\"Concord Center Point, Kazi Nazrul Islam Ave, Dhaka 1215, Bangladesh,Dhaka - 1215,Dhaka Division,Bangladesh\",\"time\":\"12:02:32\"},{\"latlng\":[23.7484376,90.3916779],\"area\":\"Unnamed Road, Dhaka 1205, Bangladesh,Dhaka - 1205,Dhaka Division,Bangladesh\",\"time\":\"14:58:48\"}]', '2019-04-01 06:02:31', '2019-04-01 08:58:48');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `calendar_holidays`
--
ALTER TABLE `calendar_holidays`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `calendar_holidays_holiday_date_unique` (`holiday_date`);

--
-- Indexes for table `clients`
--
ALTER TABLE `clients`
  ADD PRIMARY KEY (`id`),
  ADD KEY `clients_user_id_foreign` (`user_id`),
  ADD KEY `clients_location_area_id_foreign` (`location_area_id`);

--
-- Indexes for table `collections`
--
ALTER TABLE `collections`
  ADD PRIMARY KEY (`id`),
  ADD KEY `collections_sales_id_foreign` (`sales_id`);

--
-- Indexes for table `departments`
--
ALTER TABLE `departments`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `depots`
--
ALTER TABLE `depots`
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
-- Indexes for table `jobseeker_references`
--
ALTER TABLE `jobseeker_references`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `leaves`
--
ALTER TABLE `leaves`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `leave_applications`
--
ALTER TABLE `leave_applications`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `location_areas`
--
ALTER TABLE `location_areas`
  ADD PRIMARY KEY (`id`),
  ADD KEY `location_areas_location_level_id_foreign` (`location_level_id`);

--
-- Indexes for table `location_levels`
--
ALTER TABLE `location_levels`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `meetings`
--
ALTER TABLE `meetings`
  ADD PRIMARY KEY (`id`),
  ADD KEY `meetings_created_by_foreign` (`created_by`),
  ADD KEY `meetings_created_for_foreign` (`created_for`);

--
-- Indexes for table `meeting_participants`
--
ALTER TABLE `meeting_participants`
  ADD PRIMARY KEY (`id`),
  ADD KEY `meeting_participants_meeting_id_foreign` (`meeting_id`);

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
-- Indexes for table `sales`
--
ALTER TABLE `sales`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `sales_invoice_no_unique` (`invoice_no`),
  ADD KEY `sales_user_id_foreign` (`user_id`),
  ADD KEY `sales_client_id_foreign` (`client_id`),
  ADD KEY `sales_location_area_id_foreign` (`location_area_id`);

--
-- Indexes for table `targets`
--
ALTER TABLE `targets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `targets_created_by_foreign` (`created_by`),
  ADD KEY `targets_user_id_foreign` (`user_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `users_email_unique` (`email`),
  ADD KEY `users_role_id_foreign` (`role_id`),
  ADD KEY `users_location_area_id_foreign` (`location_area_id`),
  ADD KEY `users_designation_id_foreign` (`designation_id`),
  ADD KEY `users_department_id_foreign` (`department_id`),
  ADD KEY `users_depot_id_foreign` (`depot_id`);

--
-- Indexes for table `user_attendances`
--
ALTER TABLE `user_attendances`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `calendar_holidays`
--
ALTER TABLE `calendar_holidays`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=38;

--
-- AUTO_INCREMENT for table `clients`
--
ALTER TABLE `clients`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=32;

--
-- AUTO_INCREMENT for table `collections`
--
ALTER TABLE `collections`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=63;

--
-- AUTO_INCREMENT for table `departments`
--
ALTER TABLE `departments`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `depots`
--
ALTER TABLE `depots`
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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `jobseeker_references`
--
ALTER TABLE `jobseeker_references`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `leaves`
--
ALTER TABLE `leaves`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `leave_applications`
--
ALTER TABLE `leave_applications`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `location_areas`
--
ALTER TABLE `location_areas`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=32;

--
-- AUTO_INCREMENT for table `location_levels`
--
ALTER TABLE `location_levels`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `meetings`
--
ALTER TABLE `meetings`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT for table `meeting_participants`
--
ALTER TABLE `meeting_participants`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=35;

--
-- AUTO_INCREMENT for table `migrations`
--
ALTER TABLE `migrations`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `permissions`
--
ALTER TABLE `permissions`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=112;

--
-- AUTO_INCREMENT for table `roles`
--
ALTER TABLE `roles`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `sales`
--
ALTER TABLE `sales`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=48;

--
-- AUTO_INCREMENT for table `targets`
--
ALTER TABLE `targets`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=48;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=221;

--
-- AUTO_INCREMENT for table `user_attendances`
--
ALTER TABLE `user_attendances`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=59;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `clients`
--
ALTER TABLE `clients`
  ADD CONSTRAINT `clients_location_area_id_foreign` FOREIGN KEY (`location_area_id`) REFERENCES `location_areas` (`id`),
  ADD CONSTRAINT `clients_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `collections`
--
ALTER TABLE `collections`
  ADD CONSTRAINT `collections_sales_id_foreign` FOREIGN KEY (`sales_id`) REFERENCES `sales` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `location_areas`
--
ALTER TABLE `location_areas`
  ADD CONSTRAINT `location_areas_location_level_id_foreign` FOREIGN KEY (`location_level_id`) REFERENCES `location_levels` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `meetings`
--
ALTER TABLE `meetings`
  ADD CONSTRAINT `meetings_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`),
  ADD CONSTRAINT `meetings_created_for_foreign` FOREIGN KEY (`created_for`) REFERENCES `users` (`id`);

--
-- Constraints for table `meeting_participants`
--
ALTER TABLE `meeting_participants`
  ADD CONSTRAINT `meeting_participants_meeting_id_foreign` FOREIGN KEY (`meeting_id`) REFERENCES `meetings` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `role_permissions`
--
ALTER TABLE `role_permissions`
  ADD CONSTRAINT `role_permissions_permission_id_foreign` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `role_permissions_role_id_foreign` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `sales`
--
ALTER TABLE `sales`
  ADD CONSTRAINT `sales_client_id_foreign` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `sales_location_area_id_foreign` FOREIGN KEY (`location_area_id`) REFERENCES `location_areas` (`id`),
  ADD CONSTRAINT `sales_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `targets`
--
ALTER TABLE `targets`
  ADD CONSTRAINT `targets_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`),
  ADD CONSTRAINT `targets_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `users_department_id_foreign` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`),
  ADD CONSTRAINT `users_depot_id_foreign` FOREIGN KEY (`depot_id`) REFERENCES `depots` (`id`),
  ADD CONSTRAINT `users_designation_id_foreign` FOREIGN KEY (`designation_id`) REFERENCES `designations` (`id`),
  ADD CONSTRAINT `users_location_area_id_foreign` FOREIGN KEY (`location_area_id`) REFERENCES `location_areas` (`id`),
  ADD CONSTRAINT `users_role_id_foreign` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
