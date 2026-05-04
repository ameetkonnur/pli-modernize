# Code Generation Skill

Use this skill when generating new PL/I source code.

## MCP Reference Documents

When generating code, leverage all indexed documents:
- **Language Reference** — verify syntax of all constructs and built-in functions
- **Programming Guide** — check compiler options, I/O patterns, and cataloged procedures
- **Messages and Codes** — anticipate compiler warnings and avoid patterns that trigger them
- **Migration Guide** — avoid deprecated patterns; prefer modern constructs (e.g., VALUE over STATIC INIT for named constants)
- **LE Programming Guide** — reference for condition handling models, storage tuning, interlanguage communication, and CEE callable service usage (e.g., CEEHDLR, CEEMSG, CEE3DMP)

## Code Templates

### Batch File Processing Program
```pli
 /********************************************************************/
 /*  Program: <NAME>                                                 */
 /*  Purpose: <description>                                          */
 /********************************************************************/
 <NAME>: PROCEDURE OPTIONS (MAIN);

  DCL INPUT_FILE   FILE RECORD INPUT  ENV(CONSECUTIVE);
  DCL OUTPUT_FILE  FILE RECORD OUTPUT ENV(CONSECUTIVE);
  DCL REPORT_FILE  FILE STREAM OUTPUT PRINT;

  DCL 1 INPUT_REC,
      2 KEY_FIELD    CHAR(10),
      2 DATA_FIELD   CHAR(70);

  DCL 1 OUTPUT_REC,
      2 KEY_FIELD    CHAR(10),
      2 RESULT_FIELD CHAR(70);

  DCL EOF           BIT(1) INIT('0'B);
  DCL RECORD_COUNT  FIXED BIN(31) INIT(0);
  DCL ERROR_COUNT   FIXED BIN(31) INIT(0);

  ON ENDFILE(INPUT_FILE) EOF = '1'B;
  ON ERROR BEGIN;
    PUT FILE(REPORT_FILE) SKIP LIST('UNEXPECTED ERROR AT RECORD ' ||
        TRIM(RECORD_COUNT));
    GOTO CLEANUP;
  END;

  OPEN FILE(INPUT_FILE), FILE(OUTPUT_FILE), FILE(REPORT_FILE);

  PUT FILE(REPORT_FILE) SKIP LIST('<NAME> STARTED');

  READ FILE(INPUT_FILE) INTO(INPUT_REC);
  DO WHILE(¬EOF);
    RECORD_COUNT = RECORD_COUNT + 1;
    CALL PROCESS_RECORD;
    READ FILE(INPUT_FILE) INTO(INPUT_REC);
  END;

  CLEANUP:
  CLOSE FILE(INPUT_FILE), FILE(OUTPUT_FILE);
  PUT FILE(REPORT_FILE) SKIP LIST('RECORDS PROCESSED: ' ||
      TRIM(RECORD_COUNT));
  PUT FILE(REPORT_FILE) SKIP LIST('ERRORS: ' || TRIM(ERROR_COUNT));
  PUT FILE(REPORT_FILE) SKIP LIST('<NAME> COMPLETED');
  CLOSE FILE(REPORT_FILE);

  PROCESS_RECORD: PROCEDURE;
    /* TODO: implement record processing */
    OUTPUT_REC.KEY_FIELD = INPUT_REC.KEY_FIELD;
    OUTPUT_REC.RESULT_FIELD = INPUT_REC.DATA_FIELD;
    WRITE FILE(OUTPUT_FILE) FROM(OUTPUT_REC);
  END PROCESS_RECORD;

 END <NAME>;
```

### VSAM KSDS Access Program
```pli
 <NAME>: PROCEDURE OPTIONS (MAIN);

  DCL KSDS_FILE FILE RECORD KEYED DIRECT UPDATE
      ENV(VSAM);

  DCL 1 KSDS_REC,
      2 REC_KEY     CHAR(8),
      2 REC_DATA    CHAR(72);

  DCL SEARCH_KEY    CHAR(8);
  DCL RETURN_CODE   FIXED BIN(31);

  ON KEY(KSDS_FILE) BEGIN;
    PUT SKIP LIST('KEY CONDITION: KEY=' || SEARCH_KEY);
    RETURN_CODE = 8;
  END;

  OPEN FILE(KSDS_FILE);

  SEARCH_KEY = 'KEY00001';
  RETURN_CODE = 0;
  READ FILE(KSDS_FILE) INTO(KSDS_REC) KEY(SEARCH_KEY);
  IF RETURN_CODE = 0 THEN
    PUT SKIP LIST('FOUND: ' || KSDS_REC.REC_DATA);
  ELSE
    PUT SKIP LIST('NOT FOUND: ' || SEARCH_KEY);

  CLOSE FILE(KSDS_FILE);

 END <NAME>;
```

### MVS Callable Service Program
```pli
 <NAME>: PROCEDURE OPTIONS (MAIN);

  DCL (RETURN_CODE, REASON_CODE) FIXED BIN(31);

  DCL SERVICE_NAME ENTRY(
      <param declarations>
      FIXED BIN(31),      /* RETURN_CODE */
      FIXED BIN(31))      /* REASON_CODE */
      OPTIONS(ASSEMBLER);

  CALL SERVICE_NAME(
      <params>,
      RETURN_CODE,
      REASON_CODE);

  SELECT(RETURN_CODE);
    WHEN(0) PUT SKIP LIST('SUCCESS');
    WHEN(4) PUT SKIP LIST('WARNING: RC=4 RS=' || TRIM(REASON_CODE));
    WHEN(8) PUT SKIP LIST('ERROR: RC=8 RS=' || TRIM(REASON_CODE));
    OTHERWISE PUT SKIP LIST('SEVERE: RC=' || TRIM(RETURN_CODE) ||
                           ' RS=' || TRIM(REASON_CODE));
  END;

 END <NAME>;
```

## JCL Templates

### Compile and Link-Edit
```jcl
//<NAME>C  JOB <jobcard>
//*
//*  Compile and Link-Edit PL/I program <NAME>
//*
//STEP1    EXEC PLIXCL
//PLI.SYSIN DD DSN=<hlq>.SRCLIB(<NAME>),DISP=SHR
//LKED.SYSLMOD DD DSN=<hlq>.LOADLIB,DISP=SHR
//LKED.SYSIN DD *
  NAME <NAME>(R)
/*
```

### Execute
```jcl
//<NAME>R  JOB <jobcard>
//*
//*  Execute PL/I program <NAME>
//*
//STEP1    EXEC PGM=<NAME>
//STEPLIB  DD DSN=<hlq>.LOADLIB,DISP=SHR
//SYSLIB   DD DSN=CEE.SCEERUN,DISP=SHR
//SYSPRINT DD SYSOUT=*
//INPUT    DD DSN=<hlq>.INPUT.DATA,DISP=SHR
//OUTPUT   DD DSN=<hlq>.OUTPUT.DATA,
//            DISP=(NEW,CATLG,DELETE),
//            SPACE=(CYL,(5,1)),
//            DCB=(RECFM=FB,LRECL=80,BLKSIZE=27920)
//*
```

## MCP Verification Checklist

Before finalizing generated code, verify with the MCP server:

- [ ] All built-in functions used exist in PL/I 6.2
- [ ] Parameter types match ENTRY declaration signatures
- [ ] ENVIRONMENT options are valid for the file organization
- [ ] Compiler options referenced are valid
- [ ] Condition names are spelled correctly
- [ ] Attribute combinations are valid (e.g., CHAR VARYING not CHAR VAR)
