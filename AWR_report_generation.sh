#!/bin/bash

# --- Configuration Variables ---
# IMPORTANT: Adjust ORACLE_HOME to your Oracle Database home directory
# Example: /u01/app/oracle/product/19.0.0/dbhome_1
ORACLE_HOME="/orasw/app/oracle/product/19.3.0.0/dbhome_1"

# Set your Oracle environment variables
export ORACLE_HOME
export PATH="$ORACLE_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$ORACLE_HOME/lib:$LD_LIBRARY_PATH"

# IMPORTANT: Database connection string.
# Use "/ as sysdba" if running on the database server and have OS authentication setup.
# Alternatively, use "username/password@tns_alias" for remote or specific user connections.
# Ensure the user has permissions to query DBA_HIST views and run AWR scripts.
DB_CONNECT_STRING="/ as sysdba"

# IMPORTANT: Directory where AWR reports will be saved
# Ensure this directory exists and the script user has write permissions.
REPORT_DIR="/home/oracle/AWR_x6_baseline"

# --- Optional Report Period Definition ---
# To generate a report for a specific time window, uncomment and set these variables.
# Format: 'YYYY-MM-DD HH24:MI:SS'
# Example: REPORT_START_DATETIME="2024-06-15 09:00:00"
# Example: REPORT_END_DATETIME="2024-06-15 10:00:00"

REPORT_START_DATETIME=$1
REPORT_END_DATETIME=$2

# --- Script Start ---
echo "--- Starting AWR report generation ( $(date) ) ---"

# Create the report directory if it does not exist
mkdir -p "$REPORT_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Could not create directory $REPORT_DIR. Please check permissions."
    exit 1
fi

# Get current date and time for filename (e.g., 20240616_1230)
CURRENT_DATE=$(date +"%Y%m%d_%H%M")

# --- Function to get start and end snap IDs for a specific time window ---
# This function queries DBA_HIST_SNAPSHOT to find the appropriate AWR snapshot IDs.
# If start_datetime and end_datetime are provided, it uses them.
# Otherwise, it finds snaps for approximately the last hour from current time.
# Arguments:
#   $1: Optional instance number (empty for RAC-wide, specific INST_ID for instance-specific)
#   $2: Database connection string
#   $3: Optional start datetime (YYYY-MM-DD HH24:MI:SS)
#   $4: Optional end datetime (YYYY-MM-DD HH24:MI:SS)
get_snap_ids_for_period() {
    local instance_number="$1"
    local report_start_dt="$2"
    local report_end_dt="$3"
    local snap_ids=""
    snap_ids=$(sqlplus -s / as sysdba <<EOF
        -- Exit immediately if any SQL error occurs
        WHENEVER SQLERROR EXIT FAILURE;
        -- Suppress headings, page breaks, feedback messages, and terminal output of SQL
        SET HEADING OFF;
        SET PAGESIZE 0;
        SET FEEDBACK OFF;
        SET TERMOUT OFF;
        SET LINESIZE 200;
        SET SERVEROUTPUT ON;
        DECLARE
            v_end_snap_id NUMBER;
            v_start_snap_id NUMBER;
            v_actual_start_time TIMESTAMP;
            v_actual_end_time TIMESTAMP;
        BEGIN
            -- Determine the actual start and end timestamps based on input or current time
            IF '$report_start_dt' IS NOT NULL AND '$report_end_dt' IS NOT NULL THEN
                v_actual_start_time := TO_TIMESTAMP('$report_start_dt', 'YYYY-MM-DD HH24:MI:SS');
                v_actual_end_time   := TO_TIMESTAMP('$report_end_dt', 'YYYY-MM-DD HH24:MI:SS');
            ELSE
                -- Default to the last hour if no specific period is provided
                SELECT SYSTIMESTAMP - INTERVAL '1' HOUR, SYSTIMESTAMP
                INTO v_actual_start_time, v_actual_end_time
                FROM dual;
            END IF;

            -- Find the earliest snap ID that started on or after the actual start time
            SELECT MIN(snap_id)
            INTO v_start_snap_id
            FROM DBA_HIST_SNAPSHOT
            WHERE end_interval_time between  v_actual_start_time and   v_actual_end_time
            $( [ -n "$instance_number" ] && echo "AND instance_number = $instance_number" );
            -- Find the latest snap ID that ended on or before the actual end time
            SELECT MAX(snap_id)
            INTO v_end_snap_id
            FROM DBA_HIST_SNAPSHOT
            WHERE end_interval_time between  v_actual_start_time and   v_actual_end_time
            $( [ -n "$instance_number" ] && echo "AND instance_number = $instance_number" );
           -- Additional validation to ensure snaps exist within the range and start_snap < end_snap
            IF v_start_snap_id IS NULL OR v_end_snap_id IS NULL OR v_start_snap_id >= v_end_snap_id THEN
                DBMS_OUTPUT.PUT_LINE('ERROR: Not enough AWR snapshot data for the specified period or invalid range (Start: ' || TO_CHAR(v_actual_start_time, 'YYYY-MM-DD HH24:MI:SS') || ', End: ' || TO_CHAR(v_actual_end_time, 'YYYY-MM-DD HH24:MI:SS') || ').');
            ELSE
                -- Print the start and end snap IDs on separate lines for easy parsing by the shell script
                DBMS_OUTPUT.PUT_LINE(v_start_snap_id);
                DBMS_OUTPUT.PUT_LINE(v_end_snap_id);
            END IF;
        END;
/
EOF
    )
    echo "$snap_ids"
}

# --- Generate RAC-wide AWR report (Global AWR Report) ---
echo "Generating RAC-wide AWR report..."
# Pass the optional start/end datetimes to the function
echo $REPORT_START_DATETIME
echo $REPORT_END_DATETIME
RAC_SNAP_OUTPUT=$(get_snap_ids_for_period "" "$REPORT_START_DATETIME" "$REPORT_END_DATETIME")
RAC_START_SNAP=$(echo "$RAC_SNAP_OUTPUT" | head -n 1)
RAC_END_SNAP=$(echo "$RAC_SNAP_OUTPUT" | tail -n 1)
echo "--- AWR report generation complete ( $(date) ) ---"
if [[ "$RAC_SNAP_OUTPUT" == *"ERROR"* ]] || [ -z "$RAC_START_SNAP" ] || [ -z "$RAC_END_SNAP" ]; then
    echo "Warning: Failed to determine valid snap IDs for RAC-wide report. Output: '$RAC_SNAP_OUTPUT'"
    echo "Skipping RAC-wide AWR report generation."
else
    RAC_REPORT_FILENAME="${REPORT_DIR}/AWR_RAC_WIDE_${RAC_START_SNAP}_${RAC_END_SNAP}_"${REPORT_START_DATETIME// /_}"_"${REPORT_END_DATETIME// /_}".html"
    echo "RAC-wide: Generating report from snap $RAC_START_SNAP to $RAC_END_SNAP. Output file: $RAC_REPORT_FILENAME"

    # Execute the awrgrpt.sql script for Global AWR report
    sqlplus -s / as sysdba <<EOF
        WHENEVER SQLERROR EXIT FAILURE;
        @$ORACLE_HOME/rdbms/admin/awrgrpt.sql
        active-html
        7
        $RAC_START_SNAP
        $RAC_END_SNAP
        $RAC_REPORT_FILENAME
EOF
    if [ $? -eq 0 ]; then
        echo "RAC-wide AWR report generated successfully."
    else
        echo "Error generating RAC-wide AWR report. Check SQL*Plus output above for details."
    fi
fi


# --- Generate Instance-specific AWR reports ---
echo "Generating Instance-specific AWR reports..."

# Get a list of instance numbers in the RAC database from GV$INSTANCE
INSTANCES=$(sqlplus -s / as sysdba <<EOF
    WHENEVER SQLERROR EXIT FAILURE;
    SET HEADING OFF;
    SET PAGESIZE 0;
    SET FEEDBACK OFF;
    SET TERMOUT OFF;
    SELECT INST_ID FROM GV\$INSTANCE ORDER BY INST_ID;
EOF
)
echo $INSTANCES
if [ $? -ne 0 ] || [ -z "$INSTANCES" ]; then
    echo "Warning: Failed to retrieve instance list from GV\$INSTANCE. Output: '$INSTANCES'"
    echo "Skipping instance-specific reports generation."
else
    for INST_ID in $INSTANCES; do
        echo "Processing instance ID: $INST_ID"
        # Pass the optional start/end datetimes to the function
        INSTANCE_SNAP_OUTPUT=$(get_snap_ids_for_period "" "$REPORT_START_DATETIME" "$REPORT_END_DATETIME")
        INSTANCE_START_SNAP=$(echo "$INSTANCE_SNAP_OUTPUT" | head -n 1)
        INSTANCE_END_SNAP=$(echo "$INSTANCE_SNAP_OUTPUT" | tail -n 1)

        if [[ "$INSTANCE_SNAP_OUTPUT" == *"ERROR"* ]] || [ -z "$INSTANCE_START_SNAP" ] || [ -z "$INSTANCE_END_SNAP" ]; then
            echo "Warning: Failed to determine valid snap IDs for instance $INST_ID. Output: '$INSTANCE_SNAP_OUTPUT'"
            echo "Skipping AWR report generation for instance $INST_ID."
            continue
        fi

        INSTANCE_REPORT_FILENAME="${REPORT_DIR}/AWR_INST_${INST_ID}_${INSTANCE_START_SNAP}_${INSTANCE_END_SNAP}_"${REPORT_START_DATETIME// /_}"_"${REPORT_END_DATETIME// /_}".html"
        echo "Instance $INST_ID: Generating report from snap $INSTANCE_START_SNAP to $INSTANCE_END_SNAP. Output file: $INSTANCE_REPORT_FILENAME"

DBID=$(sqlplus -s / as sysdba <<EOF
    WHENEVER SQLERROR EXIT FAILURE;
    SET HEADING OFF;
    SET PAGESIZE 0;
    SET FEEDBACK OFF;
    SET TERMOUT OFF;
    SELECT DBID FROM V\$DATABASE ;
EOF
)


        # Execute the awrrpt.sql script for instance-specific AWR report
        sqlplus -s / as sysdba <<EOF
            WHENEVER SQLERROR EXIT FAILURE;
            @$ORACLE_HOME/rdbms/admin/awrrpti.sql
            active-html
            $DBID
            $INST_ID
            7
            $INSTANCE_START_SNAP
            $INSTANCE_END_SNAP
            $INSTANCE_REPORT_FILENAME
EOF
        if [ $? -eq 0 ]; then
            echo "Instance $INST_ID AWR report generated successfully."
        else
            echo "Error generating AWR report for instance $INST_ID. Check SQL*Plus output above for details."
        fi
    done
fi
