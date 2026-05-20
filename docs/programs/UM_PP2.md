---
program: UM_PP2
language: "PL/I (Enterprise PL/I for z/OS)"
source: pli_src/code03.pli
analyzed: 2026-05-06
procedures:
  - name: UM_PP2
    type: external
  - name: exec_request_001
    type: internal
  - name: exec_request_002
    type: internal
  - name: exec_request_003
    type: internal
  - name: exec_request_004
    type: internal
  - name: exec_request_005
    type: internal
  - name: exec_request_006
    type: internal
  - name: exec_request_007
    type: internal
  - name: exec_request_008
    type: internal
  - name: commit
    type: internal
  - name: ERR_CHECK
    type: internal
external_calls:
  - name: PPRTEXT
    linkage: ASSEMBLER
files: []
---

# UM_PP2 — PL/I PP2 Host Umbrella Program for CICS / Teradata

## Overview

UM_PP2 is a PL/I program designed to run as a **CICS transaction** that demonstrates Teradata database operations using the **Teradata Preprocessor 2 (PP2)** interface. The program connects to a Teradata Database System (DBS), performs a series of SQL operations (INSERT, UPDATE, DELETE, SELECT) against the `HUTestResults` table, and then disconnects.

The program serves as a test harness that exercises all major DML (Data Manipulation Language) operations through the PP2 embedded SQL interface under CICS, validating that the PL/I PP2 host interface correctly handles a variety of Teradata data types including BYTE, BYTEINT, CHAR, DATE, DECIMAL, FLOAT, INTEGER, SMALLINT, VARBYTE, and VARCHAR.

**Key characteristics:**
- **Runtime environment**: CICS (Customer Information Control System) — the program uses `EXEC CICS` commands for terminal output and transaction control
- **Database interface**: Teradata PP2 (Preprocessor 2) embedded SQL — not IBM Db2
- **Table**: `HUTestResults` with a composite primary index on `(SourceOfRow, ROWNUMBER)`
- **History**: Originally coded 12-SEP-1988 (F.1) as a batch program; converted to CICS on 14-SEP-1988 (F.2)

## Program Flow

1. **LOGON** — Connect to the Teradata DBS using the logon string `'e/omh,omh'` stored in `LOGON_STR`. Display confirmation via `EXEC CICS SEND TEXT`.
2. **INSERT row 1** (`exec_request_001`) — Insert a row with minimum/boundary values (e.g., `BYTEINT = -128`, `INTEGER = -2147483648`, `SMALLINT = -32768`). Commit.
3. **INSERT row 2** (`exec_request_002`) — Insert a row with maximum/boundary values (e.g., `BYTEINT = 127`, `INTEGER = 2147483647`, `SMALLINT = 32767`). Commit.
4. **INSERT row 3** (`exec_request_003`) — Insert a row with NULL values for all columns except `SourceOfRow` and `ROWNUMBER`. Commit.
5. **INSERT row 4** (`exec_request_004`) — Insert another row with NULL values for all columns except `SourceOfRow` and `ROWNUMBER`. Commit.
6. **INSERT row 5** (`exec_request_005`) — Insert a row with the same maximum boundary values as row 2. Commit.
7. **UPDATE row 4** (`exec_request_006`) — Update all columns of row 4 with new specific values. Commit.
8. **DELETE row 2** (`exec_request_007`) — Delete the row where `ROWNUMBER = 2`. Commit. **Note**: The WHERE clause uses `'PREPROCESSOR/2/CICS'` which differs from the INSERT value `'PREPROCESSOR2/PLI/CICS'` — see [Observations](#observations).
9. **SELECT all rows** (`exec_request_008`) — Declare, open, and fetch all rows using a cursor (`CURSOR_008`). Uses indicator variables to detect NULLs. Excludes COL001 (BYTE) and COL009 (VARBYTE) because PP2 does not support those data types for retrieval. Commit.
10. **LOGOFF** — Disconnect from the Teradata DBS. Display confirmation.
11. **EXEC CICS RETURN** — Return control to CICS.

## Data Declarations

### Constants

| Variable | Value | Type | Description |
|----------|-------|------|-------------|
| `OK` | 0 | `FIXED BIN(15)` | Successful return code (declared but not referenced) |
| `DONE` | −1 | `FIXED BIN(15)` | End-of-data indicator (SQLCODE 100 or −501) |
| `TRY_AGAIN` | −2 | `FIXED BIN(15)` | Retry indicator (declared but not referenced) |
| `FATAL_ERR` | −9 | `FIXED BIN(15)` | Fatal error indicator — triggers program termination |

### Variables

| Variable | Type | Description |
|----------|------|-------------|
| `code` | `FIXED BIN(15)` | Return code from `ERR_CHECK`; compared against `DONE` and `FATAL_ERR` |
| `req_code` | `CHAR(32) VAR` | Current request identifier string (e.g., `'REQ_001'`, `'commit'`) |
| `SCREEN_MESSAGE` | `CHAR(60)` | Message buffer for CICS terminal output via `EXEC CICS SEND TEXT` |
| `COMPOINT` | `PTR` | CICS COMMAREA pointer parameter passed to the main procedure |
| `err_msg` | `CHAR(100) VAR` | Error message text returned by `PPRTEXT` |
| `err_code` | `FIXED BIN(31)` | Error code returned by `PPRTEXT` |
| `max_len` | `FIXED BIN(15)` | Maximum length for error message retrieval (initialized to 100) |

**Reference**: `FIXED BIN(15)` is a halfword (2-byte) signed binary integer; `FIXED BIN(31)` is a fullword (4-byte) signed binary integer. `CHAR(n) VAR` (abbreviation for `VARYING`) is a variable-length character string with a maximum length of `n` and a 2-byte length prefix. — *PL/I Language Reference*, Part 1, pp. 76, 81–82.

### SQL Host Variables

Host variables are declared within `EXEC SQL BEGIN DECLARE SECTION` / `EXEC SQL END DECLARE SECTION` blocks, making them available for use in embedded SQL statements.

**Reference**: *PL/I Programming Guide*, Part 1, p. 177 — "Under the option STDSQL(YES), you must declare all host variables between SQL BEGIN DECLARE SECTION and SQL END DECLARE SECTION statements."

#### Indicator Variables

| Variables | Type | Description |
|-----------|------|-------------|
| `I1` – `I10` | `FIXED BIN(15)` | SQL indicator variables for NULL detection during FETCH |
| `I11` – `I20` | `FIXED BIN(15)` | Additional indicator variables (declared but unused) |
| `I21` – `I30` | `FIXED BIN(15)` | Additional indicator variables (declared but unused) |

Indicator variables are used in the `FETCH` statement (e.g., `:H_ROWNUMBER :I1`). A negative indicator value signals that the corresponding host variable contains a NULL.

#### Data Host Variables

| Variable | Type | Teradata Column | Teradata Type | Description |
|----------|------|-----------------|---------------|-------------|
| `LOGON_STR` | `CHAR(30) VAR` | — | — | Teradata logon string: `'e/omh,omh'` (environment/user,password) |
| `USERNAME` | `CHAR(32) VAR` | — | — | Username (declared but unused) |
| `H_DATE` | `FIXED BIN(31)` | — | — | Date value (declared but unused in main flow) |
| `H_TIME` | `FIXED BIN(31)` | — | — | Time value (declared but unused in main flow) |
| `H_COL002` | `FIXED BIN(15)` | COL002 | `BYTEINT` | Maps to Teradata BYTEINT (−128 to 127) |
| `H_COL003` | `CHAR(8)` | COL003 | `CHAR(8)` | Fixed-length character string |
| `H_COL004` | `FIXED BIN(31)` | COL004 | `DATE` | Teradata DATE stored as integer (YYMMDD format) |
| `H_COL005` | `FIXED DEC(8,3)` | COL005 | `DECIMAL(8,3)` | Packed decimal, 8 digits total, 3 decimal places |
| `H_COL006` | `BIN FLOAT(53)` | COL006 | `FLOAT` | Double-precision floating point (IEEE 754) |
| `H_COL007` | `FIXED BIN(31)` | COL007 | `INTEGER` | Fullword binary integer |
| `H_COL008` | `FIXED BIN(15)` | COL008 | `SMALLINT` | Halfword binary integer |
| `H_COL010` | `CHAR(15) VAR` | COL010 | `VARCHAR(15)` | Variable-length character string |
| `H_ROWNUMBER` | `FIXED BIN(15)` | ROWNUMBER | `INTEGER` | Row identifier (note: declared as halfword, column is INTEGER) |

**Reference**: SQL data types mapped to PL/I declarations — *PL/I Programming Guide*, Part 1, p. 185, Table 11: `SMALLINT` → `BIN FIXED(15)`, `INTEGER` → `BIN FIXED(31)`, `DECIMAL(p,s)` → `DEC FIXED(p,s)`, `FLOAT` → `BIN FLOAT(53)`, `CHAR(n)` → `CHAR(n)`, `VARCHAR(n)` → `CHAR(n) VAR`.

### SQLCA (SQL Communication Area)

Included via `EXEC SQL INCLUDE SqlCA`. The SQLCA is a standard structure providing feedback from SQL statement execution:

```pli
Dcl 1 Sqlca,
    2 sqlcaid   char(8),          /* Eyecatcher = 'SQLCA   ' */
    2 sqlcabc   fixed binary(31), /* SQLCA size in bytes = 136 */
    2 sqlcode   fixed binary(31), /* SQL return code */
    2 sqlerrmc  char(70) var,     /* Error message tokens */
    2 sqlerrp   char(8),          /* Diagnostic information */
    2 sqlerrd(0:5) fixed binary(31), /* Diagnostic information */
    2 sqlwarn,                    /* Warning flags */
      3 sqlwarn0 char(1), ...
    2 sqlext,
      3 sqlwarn8 char(1), ...
      3 sqlstate char(5);         /* State corresponding to SQLCODE */
```

The program checks `SqlCA.sqlCode` after every SQL statement:
- `0` = success
- `100` = no data found (end of cursor)
- `−501` = cursor not open (treated as DONE by this program)
- `−901` = fatal database error
- `> 0` = warning treated as fatal

**Reference**: *PL/I Programming Guide*, Part 1, p. 177 — "The SQLCODE value is set by the Database Services after each SQL statement is executed."

### Structures

The program does not define explicit PL/I structures or unions (the SQLCA structure is included via `EXEC SQL INCLUDE`).

## External Interfaces

### Entry Declarations

#### PPRTEXT — Teradata PP2 Error Text Retrieval

```pli
dcl PPRTEXT external entry options (asm inter);
```

`PPRTEXT` is a Teradata PP2 runtime routine that retrieves the error message text corresponding to the most recent SQL error. It is declared with `OPTIONS(ASM INTER)`:

- **ASM** (abbreviation for ASSEMBLER): Specifies assembler linkage conventions. This has the same effect as `NODESCRIPTOR` — no PL/I parameter descriptors are passed. The default linkage becomes `LINKAGE(SYSTEM)`.
- **INTER** (abbreviation for INTER): Specifies interlanguage communication conventions, allowing PL/I to call non-PL/I routines properly under Language Environment.

**Reference**: *PL/I Language Reference*, Part 1, p. 179 — "The ASSEMBLER option has the same effect as NODESCRIPTOR. A PROCEDURE or ENTRY statement that specifies OPTIONS(ASSEMBLER) will have LINKAGE(SYSTEM) unless a different linkage is explicitly specified."

**Call signature** (from usage in `ERR_CHECK`):

```pli
call PPRTEXT(SQL_RDTRTCON, err_code, err_msg, max_len);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `SQL_RDTRTCON` | (PP2-generated) | Teradata PP2 connection handle — an implicit variable generated by the PP2 preprocessor representing the active database connection |
| `err_code` | `FIXED BIN(31)` | Output: Teradata-specific error code |
| `err_msg` | `CHAR(100) VAR` | Output: Error message text (up to `max_len` characters) |
| `max_len` | `FIXED BIN(15)` | Input: Maximum length of the error message buffer |

### File Declarations

The program does not declare any PL/I files. All output is performed via `EXEC CICS SEND TEXT` to the CICS terminal.

### CICS Commands Used

| Command | Purpose |
|---------|---------|
| `EXEC CICS SEND TEXT FROM(data) LENGTH(len) FREEKB ERASE` | Send a text message to the CICS terminal. `FREEKB` unlocks the keyboard; `ERASE` clears the screen before writing. |
| `EXEC CICS RETURN` | Return control to CICS, ending the transaction. |

**Reference**: *PL/I Programming Guide*, Part 1, p. 192 — "You can code CICS statements in your PL/I applications... Each CICS statement must begin with EXEC (or EXECUTE) CICS and end with a semicolon (;)."

The program must be compiled with the `PP(CICS)` compiler option (or pre-translated by the CICS command language translator) and with `SYSTEM(CICS)`. When `SYSTEM(CICS)` is in effect, `NOEXECOPS` is implied, and all parameters to the MAIN procedure must be `POINTER`s — which explains the `COMPOINT PTR` parameter.

**Reference**: *PL/I Compiler and Run-Time Migration Guide*, p. 187 — "If your CICS program is a MAIN procedure, you must also compile it with the SYSTEM(CICS) option. NOEXECOPS is implied with this option, and all parameters passed to the MAIN procedure must be POINTERs."

## Detailed Code Walkthrough

### 1. Program Entry (Line 1)

```pli
UM_PP2: PROC(COMPOINT) OPTIONS(MAIN);
```

The program is declared as the main entry point with `OPTIONS(MAIN)`. The single parameter `COMPOINT` is a `POINTER` to the CICS communication area (COMMAREA). Under `SYSTEM(CICS)`, `NOEXECOPS` is implied, so no Language Environment runtime options are passed via the parameter list.

**Reference**: *PL/I Language Reference*, Part 1, p. 183 — "MAIN indicates that this external procedure is the initial procedure of a PL/I program."

### 2. Constant and Variable Declarations (Lines 51–95)

Four return-code constants are declared with `INIT`:
- `OK (0)`, `DONE (-1)`, `TRY_AGAIN (-2)`, `FATAL_ERR (-9)`

Note: `OK` and `TRY_AGAIN` are declared but never referenced in the program.

SQL host variables are declared in two `EXEC SQL BEGIN/END DECLARE SECTION` blocks:
- **First block** (lines 64–68): 30 indicator variables (`I1`–`I30`) as `FIXED BIN(15)`. Only `I1`–`I8` and `I10` are used in the FETCH statement.
- **Second block** (lines 72–86): Data host variables for the Teradata logon string and table columns.

The `ADDR` builtin is declared explicitly (`dcl addr builtin`), though it is not used in the program code. The error-handling variables (`err_msg`, `err_code`, `max_len`) and the external entry `PPRTEXT` are declared at the end of the declaration section.

### 3. Main Flow — LOGON (Lines 103–111)

```pli
EXEC SQL
  LOGON :LOGON_STR;
if (SqlCA.sqlCode ¬= 0) then call ERR_CHECK(req_code, code);
if (code = FATAL_ERR) then return;

SCREEN_MESSAGE = 'Logged on ok...';
EXEC CICS SEND TEXT FROM(SCREEN_MESSAGE) LENGTH(60) FREEKB ERASE;
```

The `EXEC SQL LOGON` statement is a Teradata-specific SQL extension (not standard Db2 SQL). It connects to the Teradata DBS using the logon string `'e/omh,omh'` which specifies: environment `e`, username `omh`, password `omh`.

After each SQL statement, the program checks `SqlCA.sqlCode`. If non-zero, `ERR_CHECK` is called to classify the error. If `ERR_CHECK` sets `code` to `FATAL_ERR`, the program returns immediately.

### 4. Request Dispatch (Lines 113–120)

```pli
call exec_request_001;
call exec_request_002;
call exec_request_003;
call exec_request_004;
call exec_request_005;
call exec_request_006;
call exec_request_007;
call exec_request_008;
```

Eight internal procedures are called sequentially. Each procedure performs a single SQL operation and commits. If a fatal error occurs within any procedure, it returns to the main flow, but the main flow does not re-check `code` between calls — execution continues to the next request regardless.

### 5. INSERT — Rows 1 and 2: Boundary Values (exec_request_001, exec_request_002)

**Row 1** (minimum boundary values):

```pli
EXEC SQL
  INSERT INTO HUTESTRESULTS VALUES
    ( 'PREPROCESSOR2/PLI/CICS',
      1, '00010203'XB, -128, '        ', 000101,
      0.01, 5.4E-79, -2147483648, -32768, '00'XB, ' ' );
```

| Column | Value | Significance |
|--------|-------|-------------|
| SourceOfRow | `'PREPROCESSOR2/PLI/CICS'` | Identifies rows created by this program |
| ROWNUMBER | 1 | Row identifier |
| col001 | `'00010203'XB` | Hex byte literal — 4 bytes of binary data |
| col002 | −128 | BYTEINT minimum value |
| col003 | `'        '` (blanks) | Empty 8-character string |
| col004 | 000101 | DATE as integer (January 1, 1900 in YYMMDD) |
| col005 | 0.01 | Near-minimum DECIMAL(8,3) |
| col006 | 5.4E−79 | Very small FLOAT value |
| col007 | −2,147,483,648 | INTEGER minimum value (−2³¹) |
| col008 | −32,768 | SMALLINT minimum value (−2¹⁵) |
| col009 | `'00'XB` | 1-byte VARBYTE |
| col010 | `' '` | Single space VARCHAR |

**Row 2** (maximum boundary values):

```pli
EXEC SQL
  INSERT INTO HUTESTRESULTS VALUES
    ( 'PREPROCESSOR2/PLI/CICS',
      2, 'FCFDFEFF'XB, 127, '99999999', 991231,
      99999.999, 7.2E75, 2147483647, 32767, 'F8F9FAFBFCFDFEFF'XB,
      '}}}}}}}}}}}}}}}'  );
```

Tests maximum boundary values: `BYTEINT = 127`, `INTEGER = 2,147,483,647` (2³¹−1), `SMALLINT = 32,767` (2¹⁵−1), `DECIMAL(8,3) = 99999.999`, etc.

### 6. INSERT — Rows 3 and 4: NULL Values (exec_request_003, exec_request_004)

```pli
EXEC SQL
  INSERT INTO HUTESTRESULTS VALUES
    ( 'PREPROCESSOR2/PLI/CICS', 3,
      , , , , , , , , , );
```

Rows 3 and 4 are inserted with only `SourceOfRow` and `ROWNUMBER` populated. The remaining columns receive NULL values (indicated by the empty comma-separated positions in the VALUES clause). This tests the PP2 interface's ability to handle NULL insertion.

### 7. INSERT — Row 5: Maximum Values (exec_request_005)

Identical values to row 2. Provides a duplicate row for testing purposes.

### 8. UPDATE Row 4 (exec_request_006)

```pli
EXEC SQL
  UPDATE HUTESTRESULTS SET
    COL001 = '77'XB, COL002 = 100, COL003 = 'AAAA',
    COL004 = 500615, COL005 = 11111.222, COL006 = 1.2345E6,
    COL007 = 12345678, COL008 = 12345,
    COL009 = '888888'XB, COL010 = 'ZZZZZZZZ'
  WHERE SOURCEOFROW = 'PREPROCESSOR2/PLI/CICS' AND ROWNUMBER = 4;
```

Updates the previously-NULL row 4 with specific values. The WHERE clause uses the composite primary index `(SOURCEOFROW, ROWNUMBER)` for direct row access.

### 9. DELETE Row 2 (exec_request_007)

```pli
EXEC SQL
  DELETE FROM HUTESTRESULTS
    WHERE SOURCEOFROW = 'PREPROCESSOR/2/CICS' AND ROWNUMBER = 2;
```

**Observation**: The WHERE clause uses `'PREPROCESSOR/2/CICS'` but all INSERT statements use `'PREPROCESSOR2/PLI/CICS'`. This mismatch means the DELETE will likely not find and delete the intended row. See [Observations](#observations).

### 10. SELECT All Rows via Cursor (exec_request_008)

This is the most complex request, demonstrating full cursor-based retrieval:

**Step 1 — DECLARE CURSOR:**
```pli
EXEC SQL
  DECLARE CURSOR_008 CURSOR FOR
    SELECT ROWNUMBER, COL002, COL003, COL004, COL005,
           COL006, COL007, COL008, COL010
    FROM HUTESTRESULTS;
```

The SELECT excludes `COL001` (BYTE) and `COL009` (VARBYTE) because these data types are not supported by the PL/I PP2 for retrieval, as noted in the program header comments.

**Step 2 — OPEN CURSOR:**
```pli
EXEC SQL OPEN CURSOR_008;
```

**Step 3 — POSITION** (Teradata-specific):
```pli
EXEC SQL POSITION CURSOR_008 TO STATEMENT 1;
```

This is a Teradata PP2-specific command that positions the cursor to the first statement in a multi-statement request. The code comments note this is not needed for a single-statement request but is included for demonstration.

**Step 4 — FETCH loop:**
```pli
code = 0;
do while (code ¬= DONE);
  EXEC SQL
    FETCH CURSOR_008 INTO
      :H_ROWNUMBER :I1, :H_COL002 :I2, :H_COL003 :I3,
      :H_COL004 :I4, :H_COL005 :I5, :H_COL006 :I6,
      :H_COL007 :I7, :H_COL008 :I8, :H_COL010 :I10;
  if (SqlCA.sqlCode ¬= 0) then call ERR_CHECK(req_code, code);
  if (code = FATAL_ERR) then return;

  if (code = 0) then do;
    SCREEN_MESSAGE = 'Values Have Been Fetched...';
    EXEC CICS SEND TEXT FROM(SCREEN_MESSAGE) LENGTH(60) FREEKB ERASE;
  end;
end;
```

Each host variable is followed by an **indicator variable** (e.g., `:H_ROWNUMBER :I1`). When the indicator is negative, the host variable's value is NULL and should not be used. The loop continues until `ERR_CHECK` sets `code` to `DONE` (triggered by SQLCODE 100).

**Step 5 — CLOSE CURSOR and COMMIT:**
```pli
EXEC SQL CLOSE CURSOR_008;
call commit;
```

### 11. LOGOFF and Return (Lines 123–132)

```pli
EXEC SQL LOGOFF;
EXEC CICS RETURN;
return;
```

Disconnects from Teradata and returns control to CICS. `EXEC CICS RETURN` terminates the CICS transaction. The PL/I `return` statement is also present for completeness.

### 12. commit Procedure (Lines 475–483)

```pli
commit: proc;
  req_code = 'commit';
  EXEC SQL COMMIT;
  if (SqlCA.sqlCode ¬= 0) then call ERR_CHECK(req_code, code);
  if (code = FATAL_ERR) then return;
  return;
end;
```

A simple wrapper that issues `EXEC SQL COMMIT` and checks for errors. Called after every successful DML operation.

### 13. ERR_CHECK Procedure (Lines 486–509)

```pli
ERR_CHECK: proc(p_req_code, p_code);
  dcl p_req_code  char(32) var;
  dcl p_code      fixed bin(15);
  dcl i           fixed bin(15);

  p_code = 0;
  if (SqlCA.sqlCode = 100 | SqlCA.SqlCode = -501)
  then p_code = DONE;
  else do;
    call PPRTEXT(SQL_RDTRTCON, err_code, err_msg, max_len);
    SCREEN_MESSAGE = (SqlCA.sqlCode || ' ' || err_code || '  ' || err_msg);
    EXEC CICS SEND TEXT FROM(SCREEN_MESSAGE) LENGTH(60) FREEKB ERASE;

    if (SqlCA.sqlCode = -901 | SqlCA.SqlCode > 0)
    then do;
      p_code = FATAL_ERR;
      SCREEN_MESSAGE = 'Fatal Error in ' || p_req_code;
      EXEC CICS SEND TEXT FROM(SCREEN_MESSAGE) LENGTH(60) FREEKB ERASE;
    end;
  end;
  return;
end;
```

**Error classification logic:**

| SQLCODE | Classification | Action |
|---------|---------------|--------|
| 100 | `DONE` | End-of-data (no more rows to fetch) |
| −501 | `DONE` | Cursor not open (treated as end-of-data) |
| −901 | `FATAL_ERR` | Fatal database error — terminate |
| > 0 (warnings) | `FATAL_ERR` | Any warning treated as fatal |
| Other negative | (none) | Error displayed but execution continues (`p_code` remains 0) |

For non-DONE errors, `PPRTEXT` is called to retrieve the Teradata error text. The error information (SQLCODE, error code, and message) is displayed on the CICS terminal. `SQL_RDTRTCON` is a PP2 preprocessor-generated variable representing the active Teradata connection handle.

## PL/I Language Constructs

### PROCEDURE OPTIONS(MAIN)

Declares `UM_PP2` as the initial procedure of the PL/I program. Under CICS, this must be compiled with `SYSTEM(CICS)`, which implies `NOEXECOPS`.

**Reference**: *PL/I Language Reference*, Part 1, p. 183.

### POINTER (PTR)

`COMPOINT` is declared as `PTR` — a 4-byte (under `LP(32)`) locator variable holding the address of the CICS COMMAREA.

**Reference**: *PL/I Language Reference*, Part 2, p. 251 — "A POINTER(32) is four bytes in size and by default fullword-aligned."

### CHAR(n) VARYING (VAR)

Variables like `req_code CHAR(32) VAR` and `LOGON_STR CHAR(30) VAR` are variable-length character strings. Storage includes a 2-byte length prefix followed by up to `n` bytes of character data. The current length varies from 0 to `n`.

**Reference**: *PL/I Language Reference*, Part 1, pp. 81–82 — "The storage allocated for VARYING strings includes an additional 2 bytes that holds the current length of the string."

### FIXED BIN(15) and FIXED BIN(31)

`FIXED BIN(15)` is a halfword (2-byte) signed binary integer (range: −32,768 to 32,767). `FIXED BIN(31)` is a fullword (4-byte) signed binary integer (range: −2,147,483,648 to 2,147,483,647). These map directly to the z/Architecture halfword and fullword general register formats.

**Reference**: *PL/I Language Reference*, Part 1, p. 76. *PL/I Programming Guide*, Part 1, p. 185, Table 11 — `SMALLINT` → `BIN FIXED(15)`, `INTEGER` → `BIN FIXED(31)`.

### FIXED DEC(8,3)

`H_COL005 FIXED DEC(8,3)` declares a packed decimal variable with 8 total digits and 3 decimal places. Maps to the Teradata `DECIMAL(8,3)` column.

**Reference**: *PL/I Language Reference*, Part 1, p. 76. *PL/I Programming Guide*, Part 1, p. 185, Table 11 — `DECIMAL(p,s)` → `DEC FIXED(p,s)`.

### BIN FLOAT(53)

`H_COL006 BIN FLOAT(53)` declares a double-precision binary floating-point variable (8 bytes, 53 bits of mantissa precision). Maps to the Teradata `FLOAT` column.

**Reference**: *PL/I Programming Guide*, Part 1, p. 185, Table 11 — `DOUBLE PRECISION, DOUBLE, or FLOAT(n)` → `BIN FLOAT(p)` where `22 ≤ p ≤ 53`.

### INIT (INITIAL) Attribute

Constants are declared with `INIT(value)` to specify their initial values when storage is allocated (e.g., `dcl DONE fixed bin(15) init(-1)`).

**Reference**: *PL/I Language Reference*, Part 2, pp. 269–271.

### BUILTIN Declaration

`dcl addr builtin` explicitly declares `ADDR` as a built-in function. In PL/I, built-in functions can be declared explicitly to avoid ambiguity with user-defined names. However, `ADDR` is not actually used in this program.

**Reference**: *PL/I Language Reference*, Part 2, p. 251.

### EXTERNAL ENTRY OPTIONS(ASM INTER)

`PPRTEXT` is declared as an external entry with assembler linkage (`ASM`) and interlanguage communication (`INTER`). This allows PL/I to call the Teradata PP2 runtime routine using system linkage conventions.

**Reference**: *PL/I Language Reference*, Part 1, p. 179.

### ¬= (NOT EQUAL) Operator

The `¬=` operator is the PL/I not-equal comparison operator. Used extensively to check `SqlCA.sqlCode ¬= 0` and in the FETCH loop `code ¬= DONE`.

### || (Concatenation) Operator

The `||` operator concatenates character strings. Used in `ERR_CHECK` to build error messages: `SqlCA.sqlCode || ' ' || err_code || '  ' || err_msg`.

### DO WHILE Loop

`do while (code ¬= DONE)` implements a pre-test iterative loop. The loop continues fetching rows until `ERR_CHECK` sets `code` to `DONE` (triggered by SQLCODE 100).

### %PAGE Directive

`%page` directives throughout the source force page breaks in the compiler listing, improving readability of the printed source listing.

### EXEC SQL Statements

All `EXEC SQL` statements are processed by the Teradata PP2 preprocessor (or by the PL/I SQL preprocessor if configured). The PP2 translates SQL statements into PL/I calls to the Teradata Call-Level Interface.

**Reference**: *PL/I Programming Guide*, Part 1, pp. 165, 170–171 — SQL preprocessor and CICS preprocessor.

## Error Handling

The program implements centralized error handling through the `ERR_CHECK` internal procedure:

1. **After every SQL statement**, the program checks `SqlCA.sqlCode ¬= 0`
2. If non-zero, `ERR_CHECK` is called with the current `req_code` and `code` variables
3. `ERR_CHECK` classifies the error:
   - **SQLCODE 100 or −501** → `DONE` (end-of-data, not an error)
   - **SQLCODE −901 or > 0** → `FATAL_ERR` (terminate)
   - **Other negative SQLCODEs** → Error is displayed but execution continues
4. For actual errors, `PPRTEXT` retrieves the Teradata error message text and displays it on the CICS terminal
5. If `code = FATAL_ERR`, the calling procedure returns immediately

**Limitations:**
- No `ON ERROR` or `ON CONDITION` handlers are established
- No rollback is performed on error — only the current transaction is abandoned via return
- Warning SQLCODEs (> 0) are treated as fatal, which may be overly aggressive
- The main flow does not re-check `code` between `call exec_request_NNN` calls

## Observations

### Potential Bug: DELETE WHERE Clause Mismatch

In `exec_request_007` (line 380), the DELETE statement uses:
```sql
WHERE SOURCEOFROW = 'PREPROCESSOR/2/CICS' AND ROWNUMBER = 2
```

But all INSERT statements use `'PREPROCESSOR2/PLI/CICS'` as the `SourceOfRow` value. The string `'PREPROCESSOR/2/CICS'` does not match `'PREPROCESSOR2/PLI/CICS'`, so the DELETE will find zero matching rows and effectively be a no-op. The correct value should likely be `'PREPROCESSOR2/PLI/CICS'`.

### Unused Declarations

- `OK` and `TRY_AGAIN` constants are declared but never referenced
- `USERNAME`, `H_DATE`, `H_TIME` host variables are declared but unused
- Indicator variables `I9`, `I11`–`I30` are declared but never referenced
- Variable `i` in `ERR_CHECK` is declared but unused
- `ADDR` builtin is declared but not used

### PP2 Data Type Limitations

As noted in the program header, COL001 (BYTE) and COL009 (VARBYTE) are excluded from the SELECT because the PL/I PP2 does not support retrieval of these Teradata data types into PL/I host variables.

### H_ROWNUMBER Type Mismatch

`H_ROWNUMBER` is declared as `FIXED BIN(15)` (halfword, range −32,768 to 32,767), but the Teradata column `ROWNUMBER` is defined as `INTEGER` which maps to `FIXED BIN(31)` (fullword). This is safe for the small values used (1–5) but would truncate values exceeding 32,767.

## Dependencies

### Teradata PP2 Runtime

The program requires the Teradata Preprocessor 2 (PP2) runtime libraries:
- **PPRTEXT**: Error text retrieval routine (linked from Teradata PP2 load library)
- **SQL_RDTRTCON**: PP2-generated connection handle variable (created by the preprocessor)

### CICS

The program executes as a CICS transaction and requires:
- CICS Transaction Server runtime environment
- Program defined in the CICS CSD (CICS System Definition) with appropriate transaction ID
- CICS SDFHLOAD data set available for compilation with the CICS preprocessor

### Compiler Options Required

The program requires these compiler options:
- `SYSTEM(CICS)` — for CICS MAIN procedure support
- `PP(CICS('options'))` — to invoke the CICS preprocessor
- Teradata PP2 preprocessor invocation (typically via a separate precompile step or custom PP option)

**Reference**: *PL/I Compiler and Run-Time Migration Guide*, p. 187 — "If your CICS program is a MAIN procedure, you must also compile it with the SYSTEM(CICS) option."

### Language Environment

The program requires the z/OS Language Environment runtime (`CEE.SCEERUN`) for PL/I program initialization and runtime services.

### External Programs

| Program | Source | Purpose |
|---------|--------|---------|
| PPRTEXT | Teradata PP2 runtime | Retrieve error message text for Teradata SQL errors |

### Include Files

| Include | Method | Purpose |
|---------|--------|---------|
| SqlCA | `EXEC SQL INCLUDE SqlCA` | SQL Communication Area structure definition |

### Data Sets / Tables

| Object | Type | Description |
|--------|------|-------------|
| HUTestResults | Teradata table | Test results table with 12 columns covering various Teradata data types |

The table must be pre-created using the BTEQ script documented in the program header:

```sql
CREATE TABLE HUTestResults, FALLBACK
  (
    SourceOfRow   VARCHAR(30),
    ROWNUMBER     INTEGER,
    col001        BYTE(4),
    col002        BYTEINT,
    col003        CHAR(8),
    col004        DATE,
    col005        DECIMAL(8,3),
    col006        FLOAT,
    col007        INTEGER,
    col008        SMALLINT,
    col009        VARBYTE(8),
    col010        VARCHAR(15)
  )
  PRIMARY INDEX (SourceOfRow, ROWNUMBER);
```

## JCL

No JCL is included in the source file. As a CICS program, it would be:

1. **Compiled** with PL/I compiler options including `SYSTEM(CICS)` and `PP(CICS)`, plus the Teradata PP2 precompile step
2. **Link-edited** with the Teradata PP2 runtime libraries and CICS stub libraries
3. **Defined** in the CICS CSD as a program with an associated transaction ID
4. **Invoked** by entering the assigned transaction ID at a CICS terminal
