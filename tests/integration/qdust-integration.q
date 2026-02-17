/ qdust-integration.q - Integration tests for the qdust testing framework
/ Run: q tests/integration/qdust-integration.q (from qdust dir)
/ Tests the full pipeline: write files, run qdust --one, verify .corrected, promote, re-test
/ Tests all pairing: colocation, @load, prefix substitution (tests/ test/ tst/)

\d .td

/ ============================================================================
/ Load qdust.q (to get .qd namespace with path utilities etc.)
/ ============================================================================

.qd.home:{s:string .z.f;i:last where s="/";$[null i;"../../";(i#s),"/../../"]}[]
/ Load qdust.q with .z.x cleared to prevent entry point from firing
`.QDUSTLIB set 1b;system"l ",.qd.home,"qdust.q"

/ ============================================================================
/ Test Harness
/ ============================================================================

pass:0
fail:0
total:0

assert:{[name;cond]
  total::total+1;
  $[cond;
    [pass::pass+1;-1"    PASS: ",name];
    [fail::fail+1;-1"    FAIL: ",name]]}

mkDir:{system"mkdir -p \"",x,"\"";x}
rmDir:{@[system;"rm -rf \"",x,"\"";{}]}
writeFile:{[path;lines]
  ls:$[10h=type lines;enlist lines;lines];
  (hsym`$path)0:{$[-10h=type x;enlist x;x]}each ls}
fileExists:{not()~key hsym`$x}
fileContent:{@[read0;hsym`$x;()]}

/ Run qdust --one as subprocess
runQ:{[file;extraFlags]
  tmpf:"/tmp/td_out_",string[`int$.z.t],"_",string[rand 100000],".txt";
  shf:"/tmp/td_cmd_",string[rand 100000],".sh";
  cmd:.qd.qEnvPrefix[],.qd.qExec[]," ",.qd.qFlags[],.qd.home,"qdust.q --one ",extraFlags,"test \"",file,"\"";
  (hsym`$shf)0:enlist cmd," > ",tmpf," 2>&1";
  @[system;"bash ",shf;{}];
  output:@[read0;hsym`$tmpf;enlist""];
  @[system;"rm -f ",tmpf," ",shf;{}];
  output}

/ Promote via qdust --one
promoteQ:{[file]
  shf:"/tmp/td_prm_",string[rand 100000],".sh";
  cmd:.qd.qEnvPrefix[],.qd.qExec[]," ",.qd.qFlags[],.qd.home,"qdust.q --one promote \"",file,"\"";
  (hsym`$shf)0:enlist cmd," > /dev/null 2>&1";
  @[system;"bash ",shf;{}];
  @[system;"rm -f ",shf;{}]}

/ ============================================================================
/ Test A: .q file inline tests (/// expr -> result)
/ ============================================================================

testA:{[]
  -1"\n=== A: .q file inline tests ===";
  dir:mkDir"/tmp/test-qdust-A-",string rand 100000;
  f:dir,"/t.q";

  / A1: new test capture (* placeholder)
  writeFile[f;("/ test";"/// 1+1 -> *")];
  runQ[f;""];
  assert["A1 .corrected created";fileExists f,".corrected"];
  c:fileContent f,".corrected";
  assert["A1 .corrected has correct value";any c like"*1+1 -> 2*"];

  / A2: promote
  promoteQ[f];
  assert["A2 .corrected removed";not fileExists f,".corrected"];
  c:fileContent f;
  assert["A2 file updated";any c like"*1+1 -> 2*"];

  / A3: re-test passes
  runQ[f;""];
  assert["A3 passes";not fileExists f,".corrected"];

  / A4: wrong expected
  writeFile[f;("/ test";"/// 1+1 -> 99")];
  runQ[f;""];
  assert["A4 .corrected created";fileExists f,".corrected"];
  c:fileContent f,".corrected";
  assert["A4 .corrected has correct value";any c like"*1+1 -> 2*"];

  / A5: promote and re-test
  promoteQ[f];
  runQ[f;""];
  assert["A5 passes after promote";not fileExists f,".corrected"];

  rmDir dir}

/ ============================================================================
/ Test B: .t file REPL tests (q)expr / expected)
/ ============================================================================

testB:{[]
  -1"\n=== B: .t file REPL tests ===";
  dir:mkDir"/tmp/test-qdust-B-",string rand 100000;
  f:dir,"/t.t";

  / B1: new REPL test capture (no expected lines)
  writeFile[f;enlist"q)1+1"];
  runQ[f;""];
  assert["B1 .corrected created";fileExists f,".corrected"];
  c:fileContent f,".corrected";
  assert["B1 .corrected has result";c~("q)1+1";enlist"2")];

  / B2: promote
  promoteQ[f];
  assert["B2 .corrected removed";not fileExists f,".corrected"];
  c:fileContent f;
  assert["B2 file updated";c~("q)1+1";enlist"2")];

  / B3: re-test passes
  runQ[f;""];
  assert["B3 passes";not fileExists f,".corrected"];

  / B4: wrong expected
  writeFile[f;("q)1+1";"99")];
  runQ[f;""];
  assert["B4 .corrected created";fileExists f,".corrected"];
  c:fileContent f,".corrected";
  assert["B4 .corrected has correct value";c~("q)1+1";enlist"2")];

  / B5: promote and re-test
  promoteQ[f];
  runQ[f;""];
  assert["B5 passes after promote";not fileExists f,".corrected"];

  rmDir dir}

/ ============================================================================
/ Test C: Colocation pairing (lib.q beside lib.t)
/ ============================================================================

testC:{[]
  -1"\n=== C: Colocation pairing ===";
  dir:mkDir"/tmp/test-qdust-C-",string rand 100000;
  qf:dir,"/lib.q";
  tf:dir,"/lib.t";

  writeFile[qf;enlist"add:{x+y}"];

  / C1: .t auto-loads paired .q — correct expected
  writeFile[tf;("q)add[2;3]";"5")];
  runQ[tf;""];
  assert["C1 colocation passes";not fileExists tf,".corrected"];

  / C2: wrong expected proves function was loaded
  writeFile[tf;("q)add[2;3]";"99")];
  runQ[tf;""];
  assert["C2 .corrected created";fileExists tf,".corrected"];
  c:fileContent tf,".corrected";
  assert["C2 correct result";c~("q)add[2;3]";enlist"5")];

  rmDir dir}

/ ============================================================================
/ Test D: @load directive
/ ============================================================================

testD:{[]
  -1"\n=== D: @load directive ===";
  dir:mkDir"/tmp/test-qdust-D-",string rand 100000;
  mkDir dir,"/src";
  writeFile[dir,"/.qd";enlist""];
  writeFile[dir,"/src/helpers.q";enlist"helper:{x*10}"];

  tf:dir,"/mytest.t";

  / D1: @load resolves relative to project root
  writeFile[tf;("/ @load src/helpers.q";"q)helper[5]";"50")];
  runQ[tf;"--root \"",dir,"/\" "];
  assert["D1 @load passes";not fileExists tf,".corrected"];

  / D2: wrong expected proves function was loaded
  writeFile[tf;("/ @load src/helpers.q";"q)helper[5]";"99")];
  runQ[tf;"--root \"",dir,"/\" "];
  assert["D2 .corrected created";fileExists tf,".corrected"];
  c:fileContent tf,".corrected";
  assert["D2 correct result";c~("/ @load src/helpers.q";"q)helper[5]";"50")];

  rmDir dir}

/ ============================================================================
/ Test E: Prefix substitution tests/ -> src/
/ ============================================================================

testE:{[]
  -1"\n=== E: Prefix sub tests/ -> src/ ===";
  dir:mkDir"/tmp/test-qdust-E-",string rand 100000;
  mkDir dir,"/src";
  mkDir dir,"/tests";
  writeFile[dir,"/.qd";enlist""];
  writeFile[dir,"/src/mymod.q";enlist"mymod:{x+100}"];

  tf:dir,"/tests/mymod.t";

  / E1: prefix substitution resolves src/mymod.q
  writeFile[tf;("q)mymod[5]";"105")];
  runQ[tf;"--root \"",dir,"/\" "];
  assert["E1 prefix sub passes";not fileExists tf,".corrected"];

  / E2: wrong expected proves source was loaded
  writeFile[tf;("q)mymod[5]";"999")];
  runQ[tf;"--root \"",dir,"/\" "];
  assert["E2 .corrected created";fileExists tf,".corrected"];
  c:fileContent tf,".corrected";
  assert["E2 correct result";c~("q)mymod[5]";"105")];

  rmDir dir}

/ ============================================================================
/ Test F: Prefix substitution test/ -> src/
/ ============================================================================

testF:{[]
  -1"\n=== F: Prefix sub test/ -> src/ ===";
  dir:mkDir"/tmp/test-qdust-F-",string rand 100000;
  mkDir dir,"/src";
  mkDir dir,"/test";
  writeFile[dir,"/.qd";enlist""];
  writeFile[dir,"/src/calc.q";enlist"calc:{x*x}"];

  tf:dir,"/test/calc.t";

  / F1: test/ recognized as test dir
  writeFile[tf;("q)calc[7]";"49")];
  runQ[tf;"--root \"",dir,"/\" "];
  assert["F1 prefix sub passes";not fileExists tf,".corrected"];

  rmDir dir}

/ ============================================================================
/ Test G: Prefix substitution tst/ -> root (no src/)
/ ============================================================================

testG:{[]
  -1"\n=== G: Prefix sub tst/ -> root ===";
  dir:mkDir"/tmp/test-qdust-G-",string rand 100000;
  mkDir dir,"/tst";
  writeFile[dir,"/.qd";enlist""];
  writeFile[dir,"/myfunc.q";enlist"myfunc:{x,x}"];

  tf:dir,"/tst/myfunc.t";

  / G1: tst/ stripped, finds myfunc.q at project root
  writeFile[tf;("q)myfunc[1 2 3]";"1 2 3 1 2 3")];
  runQ[tf;"--root \"",dir,"/\" "];
  assert["G1 prefix sub passes";not fileExists tf,".corrected"];

  rmDir dir}

/ ============================================================================
/ Run All
/ ============================================================================

\d .

-1"qdust integration tests";
-1"========================";

.td.testA[];
.td.testB[];
.td.testC[];
.td.testD[];
.td.testE[];
.td.testF[];
.td.testG[];

-1"\n========================================";
-1"Results: ",string[.td.pass]," passed, ",string[.td.fail]," failed, ",string[.td.total]," total";
-1"========================================";
exit $[0=.td.fail;0;1]
