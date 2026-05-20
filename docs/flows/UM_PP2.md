---
program: UM_PP2
source: pli_src/code03.pli
generated: 2026-05-06
---

# UM_PP2 — Control Flow

## High-Level Flow

```mermaid
flowchart TD
    START([UM_PP2: PROC OPTIONS MAIN]) --> LOGON[(EXEC SQL LOGON)]
    LOGON --> CHK_LOGON{sqlCode ¬= 0?}
    CHK_LOGON -->|Yes| ERR_LOGON[[ERR_CHECK]]
    ERR_LOGON --> FATAL_LOGON{code = FATAL_ERR?}
    FATAL_LOGON -->|Yes| EXIT_EARLY([RETURN — exit program])
    CHK_LOGON -->|No| SEND_LOGON[(CICS SEND 'Logged on ok...')]
    FATAL_LOGON -->|No| SEND_LOGON
    SEND_LOGON --> REQ1[[exec_request_001 — INSERT row 1]]
    REQ1 --> REQ2[[exec_request_002 — INSERT row 2]]
    REQ2 --> REQ3[[exec_request_003 — INSERT row 3]]
    REQ3 --> REQ4[[exec_request_004 — INSERT row 4]]
    REQ4 --> REQ5[[exec_request_005 — INSERT row 5]]
    REQ5 --> REQ6[[exec_request_006 — UPDATE row 4]]
    REQ6 --> REQ7[[exec_request_007 — DELETE row 2]]
    REQ7 --> REQ8[[exec_request_008 — SELECT all rows]]
    REQ8 --> LOGOFF[(EXEC SQL LOGOFF)]
    LOGOFF --> CHK_LOGOFF{sqlCode ¬= 0?}
    CHK_LOGOFF -->|Yes| ERR_LOGOFF[[ERR_CHECK]]
    ERR_LOGOFF --> FATAL_LOGOFF{code = FATAL_ERR?}
    FATAL_LOGOFF -->|Yes| EXIT_EARLY
    CHK_LOGOFF -->|No| SEND_LOGOFF[(CICS SEND 'Logged off...')]
    FATAL_LOGOFF -->|No| SEND_LOGOFF
    SEND_LOGOFF --> CICS_RET[(EXEC CICS RETURN)]
    CICS_RET --> END_PROC([END UM_PP2])
```

## Detailed Flow — Request Procedures 001–007 (Common Pattern)

Each of `exec_request_001` through `exec_request_005` (INSERT), `exec_request_006` (UPDATE), and `exec_request_007` (DELETE) follows this identical control-flow pattern:

```mermaid
flowchart TD
    ENTRY([exec_request_NNN: PROCEDURE]) --> SET_REQ[req_code = 'REQ_NNN']
    SET_REQ --> SQL_OP[(EXEC SQL INSERT / UPDATE / DELETE)]
    SQL_OP --> CHK{sqlCode ¬= 0?}
    CHK -->|Yes| ERR[[ERR_CHECK]]
    ERR --> FATAL{code = FATAL_ERR?}
    FATAL -->|Yes| RET_ERR([RETURN — abort procedure])
    CHK -->|No| COMMIT[[call commit]]
    FATAL -->|No| COMMIT
    COMMIT --> SEND[(CICS SEND TEXT 'Finished Request NNN...')]
    SEND --> RET([RETURN — END exec_request_NNN])
```

### SQL Operations per Procedure

| Procedure | SQL Operation | Description |
|-----------|---------------|-------------|
| `exec_request_001` | `INSERT INTO HUTESTRESULTS` | Insert row 1 — min boundary values |
| `exec_request_002` | `INSERT INTO HUTESTRESULTS` | Insert row 2 — max boundary values |
| `exec_request_003` | `INSERT INTO HUTESTRESULTS` | Insert row 3 — null columns |
| `exec_request_004` | `INSERT INTO HUTESTRESULTS` | Insert row 4 — null columns |
| `exec_request_005` | `INSERT INTO HUTESTRESULTS` | Insert row 5 — max boundary values |
| `exec_request_006` | `UPDATE HUTESTRESULTS SET ... WHERE ROWNUMBER = 4` | Update row 4 |
| `exec_request_007` | `DELETE FROM HUTESTRESULTS WHERE ROWNUMBER = 2` | Delete row 2 |

## Detailed Flow — exec_request_008 (SELECT with Cursor)

```mermaid
flowchart TD
    ENTRY([exec_request_008: PROCEDURE]) --> SET_REQ[req_code = 'REQ_008']
    SET_REQ --> DECLARE[EXEC SQL DECLARE CURSOR_008 CURSOR FOR SELECT ...]
    DECLARE --> OPEN[(EXEC SQL OPEN CURSOR_008)]
    OPEN --> CHK_OPEN{sqlCode ¬= 0?}
    CHK_OPEN -->|Yes| ERR_OPEN[[ERR_CHECK]]
    ERR_OPEN --> FATAL_OPEN{code = FATAL_ERR?}
    FATAL_OPEN -->|Yes| RET_ERR([RETURN — abort])
    CHK_OPEN -->|No| POSITION[(EXEC SQL POSITION CURSOR_008 TO STATEMENT 1)]
    FATAL_OPEN -->|No| POSITION
    POSITION --> CHK_POS{sqlCode ¬= 0?}
    CHK_POS -->|Yes| ERR_POS[[ERR_CHECK]]
    ERR_POS --> FATAL_POS{code = FATAL_ERR?}
    FATAL_POS -->|Yes| RET_ERR
    CHK_POS -->|No| INIT_CODE[code = 0]
    FATAL_POS -->|No| INIT_CODE
    INIT_CODE --> LOOP{code ¬= DONE?}
    LOOP -->|No| CLOSE[(EXEC SQL CLOSE CURSOR_008)]
    LOOP -->|Yes| FETCH[(EXEC SQL FETCH CURSOR_008 INTO host vars)]
    FETCH --> CHK_FETCH{sqlCode ¬= 0?}
    CHK_FETCH -->|Yes| ERR_FETCH[[ERR_CHECK]]
    ERR_FETCH --> FATAL_FETCH{code = FATAL_ERR?}
    FATAL_FETCH -->|Yes| RET_ERR
    CHK_FETCH -->|No| CHK_CODE{code = 0?}
    FATAL_FETCH -->|No| CHK_CODE
    CHK_CODE -->|Yes| SEND_FETCHED[(CICS SEND 'Values Have Been Fetched...')]
    SEND_FETCHED --> LOOP
    CHK_CODE -->|No| LOOP
    CLOSE --> CHK_CLOSE{sqlCode ¬= 0?}
    CHK_CLOSE -->|Yes| ERR_CLOSE[[ERR_CHECK]]
    ERR_CLOSE --> FATAL_CLOSE{code = FATAL_ERR?}
    FATAL_CLOSE -->|Yes| RET_ERR
    CHK_CLOSE -->|No| COMMIT[[call commit]]
    FATAL_CLOSE -->|No| COMMIT
    COMMIT --> SEND_DONE[(CICS SEND 'Finished Request 008...')]
    SEND_DONE --> RET([RETURN — END exec_request_008])
```

## Commit Procedure Flow

```mermaid
flowchart TD
    ENTRY([commit: PROC]) --> SET_REQ[req_code = 'commit']
    SET_REQ --> SQL_COMMIT[(EXEC SQL COMMIT)]
    SQL_COMMIT --> CHK{sqlCode ¬= 0?}
    CHK -->|Yes| ERR[[ERR_CHECK]]
    ERR --> FATAL{code = FATAL_ERR?}
    FATAL -->|Yes| RET_ERR([RETURN — abort])
    CHK -->|No| RET([RETURN — END commit])
    FATAL -->|No| RET
```

## Error Handling Flow — ERR_CHECK

```mermaid
flowchart TD
    ENTRY([ERR_CHECK: PROC]) --> INIT[p_code = 0]
    INIT --> CHK_DONE{sqlCode = 100 OR sqlCode = -501?}
    CHK_DONE -->|Yes| SET_DONE[p_code = DONE]
    SET_DONE --> RET([RETURN])
    CHK_DONE -->|No| GET_ERR[[call PPRTEXT — get error text]]
    GET_ERR --> BUILD_MSG[SCREEN_MESSAGE = sqlCode // err_code // err_msg]
    BUILD_MSG --> SEND_ERR[(CICS SEND TEXT error message)]
    SEND_ERR --> CHK_FATAL{sqlCode = -901 OR sqlCode > 0?}
    CHK_FATAL -->|Yes| SET_FATAL[p_code = FATAL_ERR]
    SET_FATAL --> SEND_FATAL[(CICS SEND TEXT 'Fatal Error in ' // p_req_code)]
    SEND_FATAL --> RET
    CHK_FATAL -->|No| RET
```

## Flow Notes

1. **Sequential request execution**: The main procedure calls all 8 request procedures in strict sequence. There is no conditional skipping — if a procedure encounters a `FATAL_ERR`, it returns to the main flow, which continues to the next `call` statement (no early exit from the main sequence between requests).

2. **Error propagation is local**: Each request procedure checks `code` after `ERR_CHECK` and returns early only from *itself*. The main procedure only checks for `FATAL_ERR` after `LOGON` and `LOGOFF` — not after the individual request calls. This means a fatal error in one request procedure does **not** prevent subsequent requests from executing.

3. **ERR_CHECK return codes**:
   - `0` (OK) — sqlCode was non-zero but not a recognized end/fatal condition; execution continues
   - `-1` (DONE) — sqlCode 100 (no more rows) or -501; normal end-of-data
   - `-9` (FATAL_ERR) — sqlCode -901 (crash/recovery) or any positive sqlCode; caller should abort

4. **CICS interactions**: Every status message and error message is sent to the CICS terminal via `EXEC CICS SEND TEXT`. The program ends with `EXEC CICS RETURN` to hand control back to CICS.

5. **Cursor lifecycle in exec_request_008**: DECLARE → OPEN → POSITION → FETCH loop → CLOSE. The `POSITION TO STATEMENT 1` is technically redundant for a single-statement cursor but included for multi-statement compatibility.

6. **External call**: `PPRTEXT` is an external assembler-interface entry that retrieves Teradata error text from the `SQL_RDTRTCON` connection.
