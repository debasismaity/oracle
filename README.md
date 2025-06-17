The script can help to generate AWR report both RAC and instance specific using command line. This is extremely helpful to automate AWR generation report.

Consideration:

1. Change the ORACLE_HOME to point to your home where you installed oracle binaries
2. Change REPORT_DIR to point to your AWR report storage directory

How to execute:
Just provide start and end date of AWR report to be generated.
sh AWR_report_generation.sh "2025-06-17 08:55:00" "2025-06-17 10:05:00"

Your both RAC and instance specific AWR report will be generated as below:-

[oracle AWR_x6_baseline]$ ls -ltr
total 32028
-rw-r--r-- 1 oracle oinstall 2226849 Jun 17 09:55 AWR_RAC_WIDE_49886_49888_2025-06-17_07:55:00_2025-06-17_09:05:00.html
-rw-r--r-- 1 oracle oinstall 2180494 Jun 17 09:56 AWR_INST_1_49886_49888_2025-06-17_07:55:00_2025-06-17_09:05:00.html
-rw-r--r-- 1 oracle oinstall 2207155 Jun 17 09:56 AWR_INST_2_49886_49888_2025-06-17_07:55:00_2025-06-17_09:05:00.html
-rw-r--r-- 1 oracle oinstall 2209050 Jun 17 10:29 AWR_RAC_WIDE_49888_49890_2025-06-17_08:55:00_2025-06-17_10:05:00.html
-rw-r--r-- 1 oracle oinstall 2163418 Jun 17 10:29 AWR_INST_1_49888_49890_2025-06-17_08:55:00_2025-06-17_10:05:00.html
-rw-r--r-- 1 oracle oinstall 2187429 Jun 17 10:29 AWR_INST_2_49888_49890_2025-06-17_08:55:00_2025-06-17_10:05:00.html
-rw-r--r-- 1 oracle oinstall 2204568 Jun 17 11:32 AWR_RAC_WIDE_49890_49892_2025-06-17_09:55:00_2025-06-17_11:05:00.html
-rw-r--r-- 1 oracle oinstall 2149954 Jun 17 11:32 AWR_INST_1_49890_49892_2025-06-17_09:55:00_2025-06-17_11:05:00.html
-rw-r--r-- 1 oracle oinstall 2192109 Jun 17 11:32 AWR_INST_2_49890_49892_2025-06-17_09:55:00_2025-06-17_11:05:00.html
-rw-r--r-- 1 oracle oinstall 2093717 Jun 17 14:29 AWR_RAC_WIDE_49892_49894_2025-06-17_10:55:00_2025-06-17_12:05:00.html
-rw-r--r-- 1 oracle oinstall 2177729 Jun 17 14:29 AWR_INST_1_49892_49894_2025-06-17_10:55:00_2025-06-17_12:05:00.html
-rw-r--r-- 1 oracle oinstall 2181853 Jun 17 14:29 AWR_INST_2_49892_49894_2025-06-17_10:55:00_2025-06-17_12:05:00.html
-rw-r--r-- 1 oracle oinstall 2208081 Jun 17 14:30 AWR_RAC_WIDE_49894_49896_2025-06-17_11:55:00_2025-06-17_13:05:00.html
-rw-r--r-- 1 oracle oinstall 2177579 Jun 17 14:31 AWR_INST_1_49894_49896_2025-06-17_11:55:00_2025-06-17_13:05:00.html
-rw-r--r-- 1 oracle oinstall 2200745 Jun 17 14:31 AWR_INST_2_49894_49896_2025-06-17_11:55:00_2025-06-17_13:05:00.html
