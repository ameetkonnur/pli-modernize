---
program: UM_PP2
source: pli_src/code03.pli
reviewed: 2026-05-06
severity_counts:
  critical: 7
  warning: 7
  info: 6
---

# Code Review — UM_PP2

## Summary
| Metric | Value |
|--------|-------|
| Lines of code | ~510 |
| Procedures | 11 (main + 8 request + commit + ERR_CHECK) |
| External calls | 1 (PPRTEXT) |
| Critical issues | 7 |
| Warnings | 7 |
| Info/suggestions | 6 |

## Critical Issues

### CRIT-1: Hardcoded credentials in LOGON_STR
- **Location**: Line 76 — `dcl LOGON_STR char(30) var init ('e/omh,omh');`
- **Category**: Security
- **Description**: The Teradata logon string contains a plaintext username and password (`omh,omh`). This credential is embedded directly in the source code, compiled into the load module, and visible to anyone with access to the source or a hex dump of the executable.
- **Impact**: Credential exposure. Anyone with read access to the source, object deck, or load module can extract the Teradata username and password.
- **Recommendation**: Retrieve credentials at runtime from a secure store — e.g., a CICS container, a RACF-secured PDS member, or a credential vault:
  ```pli
  dcl LOGON_STR char(30) var;
  EXEC CICS GET CONTAINER('LOGON_CRED') INTO(LOGON_STR);
  ```
- **Reference**: OWASP A07:2021 — Security Misconfiguration.

### CRIT-2: Malformed DCL statements — err_msg, err_code, max_len never declared
- **Location**: Lines 90–92
  ```
  dclerr_msg        char(100) var;
  dclerr_code       fixed bin(31);
  dclmax_len        fixed bin(15) init(100);
  ```
- **Category**: Data Declarations
- **Description**: The `DCL` keyword is missing the required space before the variable name. PL/I lexical analysis treats `dclerr_msg`, `dclerr_code`, and `dclmax_len` as single identifiers, not as `DCL err_msg`, `DCL err_code`, and `DCL max_len`. The variables `err_msg`, `err_code`, and `max_len` referenced in `ERR_CHECK` (line 496) are therefore never explicitly declared with the intended attributes.
- **Impact**: Under `RULES(NOLAXDCL)`, this is a compile-time error. Under default rules, `err_msg`, `err_code`, and `max_len` get default attributes (`FLOAT DEC(6)` or `FIXED BIN(15)` depending on first letter), not the intended `CHAR(100) VAR`, `FIXED BIN(31)`, and `FIXED BIN(15)`. The `PPRTEXT` call receives incorrectly-typed arguments, causing data corruption or runtime ABENDs.
- **Recommendation**: Add the missing space:
  ```pli
  dcl err_msg        char(100) var;
  dcl err_code       fixed bin(31);
  dcl max_len        fixed bin(15) init(100);
  ```
- **Reference**: PL/I Language Reference — DECLARE statement syntax; Migration Guide p.93 — `RULES(NOLAXDCL)` (IBM Programming Guide p.123).

### CRIT-3: ERR_CHECK parameter declarations corrupted
- **Location**: Lines 488–490
  ```
  ERR_CHECK: proc(p_req_code,p_code);
  d   clp_req_code  char(32) var;
  d   clp_code      fixed bin(15);
  d   cli           fixed bin(15);
  ```
- **Category**: Data Declarations
- **Description**: The `DCL` keyword is split across tokens (`d   cl`) making these syntactically invalid declarations. Parameters `p_req_code` and `p_code` receive implicit default attributes instead of `CHAR(32) VAR` and `FIXED BIN(15)`.
- **Impact**: Parameter `p_req_code` would default to `FLOAT DEC(6)` (first letter P), not `CHAR(32) VAR`. This causes descriptor mismatches, likely resulting in S0C4 ABENDs or data corruption.
- **Recommendation**:
  ```pli
  ERR_CHECK: proc(p_req_code, p_code);
    dcl p_req_code  char(32) var;
    dcl p_code      fixed bin(15);
    dcl i           fixed bin(15);
  ```
- **Reference**: Migration Guide p.93 — `RULES(NOLAXDCL)`.

### CRIT-4: DELETE WHERE clause mismatch — row 2 will never be deleted
- **Location**: Line 378
  ```sql
  DELETE FROM HUTESTRESULTS
      WHERE SOURCEOFROW = 'PREPROCESSOR/2/CICS' AND ROWNUMBER = 2;
  ```
- **Category**: Data Integrity
- **Description**: All INSERT statements use `SOURCEOFROW = 'PREPROCESSOR2/PLI/CICS'`, but the DELETE WHERE clause uses `'PREPROCESSOR/2/CICS'` (missing `PLI/` and has extra `/` after `PREPROCESSOR`). The WHERE clause will never match any inserted rows.
- **Impact**: Row 2 is never deleted. The program silently succeeds (sqlCode = 0 for zero rows affected), producing incorrect test results.
- **Recommendation**: Fix the WHERE clause:
  ```sql
  DELETE FROM HUTESTRESULTS
      WHERE SOURCEOFROW = 'PREPROCESSOR2/PLI/CICS' AND ROWNUMBER = 2;
  ```
- **Reference**: The UPDATE in exec_request_006 correctly uses `'PREPROCESSOR2/PLI/CICS'`.

### CRIT-5: Uninitialized variables before LOGON error check
- **Location**: Lines 106–107
  ```pli
  EXEC SQL LOGON :LOGON_STR;
  if (SqlCA.sqlCode ¬= 0)  then call ERR_CHECK(req_code,code);
  if (code = FATAL_ERR)   then return;
  ```
- **Category**: Error Handling
- **Description**: `req_code` (`CHAR(32) VAR` without `INIT`) is never assigned before the LOGON. `code` (`FIXED BIN(15)` without `INIT`) is uninitialized. If LOGON succeeds (`sqlCode = 0`), `ERR_CHECK` is never called but `code` is still tested with an undefined value.
- **Impact**: `code` may contain any arbitrary stack value, potentially matching `FATAL_ERR` (-9) and causing an early exit on successful LOGON.
- **Recommendation**:
  ```pli
  dcl code     fixed bin(15) init(0);
  dcl req_code char(32) var  init('');
  ...
  req_code = 'LOGON';
  EXEC SQL LOGON :LOGON_STR;
  ```
- **Reference**: IBM Programming Guide p.133 — `RULES(NOUNSET)`.

### CRIT-6: SQL_RDTRTCON never declared
- **Location**: Line 496 — `call PPRTEXT(SQL_RDTRTCON,err_code,err_msg,max_len);`
- **Category**: Data Declarations
- **Description**: `SQL_RDTRTCON` is used as the first argument to `PPRTEXT` but is never declared anywhere. Under default rules it gets implicit `FLOAT DEC(6)` attributes. This is almost certainly a Teradata constant from a missing `%INCLUDE`.
- **Impact**: Passing an undeclared, uninitialized variable to an assembler routine (`OPTIONS(ASM)`) will cause unpredictable behavior.
- **Recommendation**: Add the proper `%INCLUDE` or explicitly declare:
  ```pli
  dcl SQL_RDTRTCON fixed bin(31) value(...); /* Teradata constant */
  ```
- **Reference**: Migration Guide p.93 — `RULES(NOLAXDCL)`.

### CRIT-7: No ON ERROR SYSTEM statement
- **Location**: Program-wide
- **Category**: Error Handling
- **Description**: No `ON ERROR SYSTEM;` statement exists. If an unhandled condition occurs (e.g., CONVERSION during error message formatting on line 497), default PL/I action is taken, which can lead to condition loops or silent continuation.
- **Impact**: Under CICS, an unhandled condition can cause a transaction ABEND (ASRA/AICA) without a meaningful error message.
- **Recommendation**: Add at the start of the main procedure:
  ```pli
  ON ERROR SYSTEM;
  ```
- **Reference**: PL/I Language Reference Part 2 p.188 — "In order to prevent a loop of ERROR conditions, the first statement in any ON ERROR block should be ON ERROR SYSTEM."

## Warnings

### WARN-1: No CICS exception handling (HANDLE ABEND)
- **Location**: Program-wide
- **Category**: Error Handling / z/OS Integration
- **Description**: The program issues multiple `EXEC CICS` commands but does not establish any `EXEC CICS HANDLE ABEND` or `EXEC CICS HANDLE CONDITION`. If a CICS command fails, the transaction will ABEND without cleanup.
- **Recommendation**:
  ```pli
  EXEC CICS HANDLE ABEND LABEL(ABEND_EXIT);
  ```
- **Reference**: LE Programming Guide Part 2 p.175.

### WARN-2: EXEC SQL COMMIT instead of EXEC CICS SYNCPOINT
- **Location**: Lines 476–481 (commit procedure)
- **Category**: z/OS Integration
- **Description**: In a CICS environment, `EXEC CICS SYNCPOINT` is the standard commit mechanism. `EXEC SQL COMMIT` only commits Teradata work and does not participate in CICS sync-point coordination.
- **Recommendation**:
  ```pli
  commit: proc;
    req_code = 'commit';
    EXEC CICS SYNCPOINT;
    return;
  end;
  ```
- **Reference**: LE Programming Guide Part 2 p.180.

### WARN-3: Indicator variables I11–I30 declared but never used
- **Location**: Lines 67–69
- **Category**: Maintainability
- **Description**: `I9` and `I11`–`I30` are declared but never referenced. Wastes stack storage.
- **Recommendation**: Remove unused declarations. Keep only `I1, I2, I3, I4, I5, I6, I7, I8, I10`.

### WARN-4: PPRTEXT declared as unprototyped ENTRY
- **Location**: Line 95 — `dcl PPRTEXT external entry options (asm inter);`
- **Category**: Data Declarations
- **Description**: `PPRTEXT` has no parameter prototypes. Under `RULES(NOLAXENTRY)`, this would be flagged.
- **Recommendation**: Add a full prototype:
  ```pli
  dcl PPRTEXT external entry(
      fixed bin(31), fixed bin(31), char(100) var, fixed bin(15)
  ) options(asm inter);
  ```
- **Reference**: IBM Programming Guide p.123 — `RULES(NOLAXENTRY)`.

### WARN-5: EXEC CICS RETURN followed by PL/I RETURN — redundant
- **Location**: Lines 121–122
- **Category**: Maintainability
- **Description**: `EXEC CICS RETURN` terminates the transaction. The PL/I `return;` after it is unreachable dead code.
- **Recommendation**: Remove the PL/I `return;` after `EXEC CICS RETURN`.

### WARN-6: SCREEN_MESSAGE LENGTH always 60 regardless of content
- **Location**: All `EXEC CICS SEND TEXT` statements
- **Category**: I/O Operations
- **Description**: `SCREEN_MESSAGE` is `CHAR(60)` AUTOMATIC without INIT. Short messages leave trailing garbage from uninitialized or leftover storage, and all 60 bytes are sent.
- **Recommendation**: Initialize the variable: `dcl SCREEN_MESSAGE char(60) init('');`

### WARN-7: Code not resilient to non-fatal SQL errors
- **Location**: All request procedures
- **Category**: Error Handling
- **Description**: For negative sqlCodes other than -501 and -901, `ERR_CHECK` sets `p_code = 0`. Callers only check for `FATAL_ERR`, so non-fatal SQL errors are silently ignored.
- **Recommendation**: Treat all unknown negative sqlCodes as fatal:
  ```pli
  if (SqlCA.sqlCode < 0 & SqlCA.sqlCode ¬= -501) then p_code = FATAL_ERR;
  ```

## Informational

### INFO-1: Constants should use VALUE attribute instead of INIT
- **Location**: Lines 51–54
- **Category**: Performance
- **Description**: `OK`, `DONE`, `TRY_AGAIN`, `FATAL_ERR` are used as constants but declared AUTOMATIC with INIT. Use `VALUE` for compile-time constants.
- **Recommendation**: `dcl OK fixed bin(15) value(0);` etc.
- **Reference**: IBM Migration Guide p.109 — IBM2812.

### INFO-2: Explicit BUILTIN declaration for ADDR is unnecessary
- **Location**: Line 88 — `dcl addr builtin;`
- **Category**: Maintainability
- **Description**: `ADDR` is recognized without an explicit declaration.
- **Recommendation**: Remove unless coding standards require it.

### INFO-3: Significant code duplication across request procedures
- **Location**: `exec_request_001` through `exec_request_005`
- **Category**: Maintainability
- **Description**: All five INSERT procedures follow an identical pattern. `exec_request_002` and `exec_request_005` insert identical data. `exec_request_003` and `exec_request_004` have identical NULL-row structures.
- **Recommendation**: Refactor into a single parameterized INSERT procedure.

### INFO-4: Non-descriptive indicator variable names
- **Location**: Lines 65–69 — `I1, I2, I3, ...`
- **Category**: Maintainability
- **Recommendation**: Use descriptive names like `IND_ROWNUMBER`, `IND_COL002`, etc.

### INFO-5: COMPOINT parameter declared but never used
- **Location**: Line 1 and Line 62
- **Category**: Maintainability
- **Description**: The `COMPOINT` pointer parameter is declared but never referenced. Likely intended for CICS COMMAREA access.
- **Recommendation**: Either use `COMPOINT` to pass the logon string (see CRIT-1) or remove it.

### INFO-6: TRY_AGAIN constant declared but never used
- **Location**: Line 53
- **Category**: Maintainability
- **Description**: `TRY_AGAIN` is declared but never referenced. `ERR_CHECK` never sets `p_code` to `TRY_AGAIN`.
- **Recommendation**: Remove or implement retry logic for transient SQL errors.

## Compiler Options Baseline Assessment

| RULES Suboption | Pass? | Violations |
|-----------------|-------|------------|
| `NOLAXDCL` | :x: | `err_msg`, `err_code`, `max_len`, `SQL_RDTRTCON` implicit; `clp_req_code`, `clp_code`, `cli` in ERR_CHECK also implicit |
| `NOLAXENTRY` | :x: | `PPRTEXT` declared without parameter prototypes |
| `NOUNSET` | :x: | `code` and `req_code` used before assignment at LOGON (lines 106–107) |
| `NOGLOBALDO` | :white_check_mark: | No violations |
| `NOLAXRETURN` | :white_check_mark: | No violations |
| `NOYY` | :white_check_mark: | No violations |
| `NOSELFASSIGN` | :white_check_mark: | No violations |
| `ANS` | :white_check_mark: | No violations |

## Best Practice Scorecard

| Category | Score | Notes |
|----------|-------|-------|
| Error Handling | :x: | No ON ERROR SYSTEM; uninitialized error-path vars; DELETE mismatch silently succeeds; non-fatal SQL errors ignored |
| Data Declarations | :x: | Malformed DCL statements (CRIT-2, CRIT-3); undeclared SQL_RDTRTCON; unprototyped PPRTEXT |
| Memory Management | :white_check_mark: | No ALLOCATE/FREE issues |
| I/O Operations | :warning: | SEND TEXT always sends 60 bytes; no CICS HANDLE for I/O errors |
| Performance | :warning: | Constants use INIT instead of VALUE; code duplication |
| Maintainability | :warning: | Cryptic names (I1–I30); code duplication; unused variables |
| Security | :x: | Hardcoded credentials in LOGON_STR |
| z/OS Integration | :warning: | No CICS HANDLE ABEND; SQL COMMIT instead of CICS SYNCPOINT |
