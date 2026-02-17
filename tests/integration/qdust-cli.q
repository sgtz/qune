/ qdust-cli.q - CLI integration tests for orchestrator commands
/ Run: q tests/integration/qdust-cli.q (from qdust dir)
/ Tests: test, promote, check, diff, -json, -junit, -errorsonly,
/        -listci, diff:none, diff:term, -noipc, no-args help

\d .tc

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

/ Resolve qdust home as absolute path. CWD is the qdust dir in all contexts.
qdustHome:(first system"pwd"),"/"

/ Run qdust orchestrator as subprocess, return stdout lines.
/ Uses the qdust wrapper (real user entry point, handles Q detection).
runCmd:{[args]
  tmpf:"/tmp/tc_out_",string[`int$.z.t],"_",string[rand 100000],".txt";
  shf:"/tmp/tc_cmd_",string[rand 100000],".sh";
  cmd:qdustHome,"qdust ",args;
  (hsym`$shf)0:enlist cmd," > ",tmpf," 2>&1";
  @[system;"bash ",shf;{}];
  output:@[read0;hsym`$tmpf;enlist""];
  @[system;"rm -f ",tmpf," ",shf;{}];
  output}

/ Check if any line contains substring (safe for mixed/empty data)
anyMatch:{[lines;sub]
  any{0<count x ss y}[;sub]each lines where{10h=type x}each lines}

/ ============================================================================
/ Setup: create a test fixture directory with passing and failing tests
/ ============================================================================

setupDir:{
  dir:mkDir"/tmp/test-qdust-cli-",string rand 100000;
  mkDir dir,"/sub";
  / Passing test
  writeFile[dir,"/pass.t";("q)1+1";"2")];
  / Failing test (wrong expected)
  writeFile[dir,"/fail.t";("q)1+1";"99")];
  / Error test (undefined variable)
  writeFile[dir,"/err.t";("q)undefinedVar123";"42")];
  / Passing subdir test
  writeFile[dir,"/sub/ok.t";("q)2+3";"5")];
  dir}

/ ============================================================================
/ Test 1: test command — basic multi-file run
/ ============================================================================

test1:{[]
  -1"\n=== 1: test command (multi-file) ===";
  dir:setupDir[];
  out:runCmd"test ",dir," -noipc";
  assert["1a ALL TESTS PASSED not shown (has failures)";not anyMatch[out;"ALL TESTS PASSED"]];
  assert["1b summary shows passed";anyMatch[out;"Total"]];
  assert["1c .corrected created for fail.t";fileExists dir,"/fail.t.corrected"];
  assert["1d .corrected created for err.t";fileExists dir,"/err.t.corrected"];
  assert["1e no .corrected for pass.t";not fileExists dir,"/pass.t.corrected"];
  assert["1f no .corrected for sub/ok.t";not fileExists dir,"/sub/ok.t.corrected"];
  rmDir dir}

/ ============================================================================
/ Test 2: test command — all pass
/ ============================================================================

test2:{[]
  -1"\n=== 2: test command (all pass) ===";
  dir:mkDir"/tmp/test-qdust-cli-2-",string rand 100000;
  writeFile[dir,"/a.t";("q)1+1";"2")];
  writeFile[dir,"/b.t";("q)2+3";"5")];
  out:runCmd"test ",dir," -noipc";
  assert["2a ALL TESTS PASSED shown";anyMatch[out;"ALL TESTS PASSED"]];
  assert["2b no .corrected files";not fileExists dir,"/a.t.corrected"];
  rmDir dir}

/ ============================================================================
/ Test 3: -json output
/ ============================================================================

test3:{[]
  -1"\n=== 3: -json output ===";
  dir:mkDir"/tmp/test-qdust-cli-3-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"2")];
  out:runCmd"test ",dir,"/t.t -noipc -json";
  assert["3a has JSON file key";anyMatch[out;"\"file\""]];
  assert["3b has passed key";anyMatch[out;"\"passed\""]];
  assert["3c has sections key";anyMatch[out;"\"sections\""]];
  rmDir dir}

/ ============================================================================
/ Test 4: -junit output
/ ============================================================================

test4:{[]
  -1"\n=== 4: -junit output ===";
  dir:mkDir"/tmp/test-qdust-cli-4-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"2")];
  out:runCmd"test ",dir,"/t.t -noipc -junit";
  assert["4a has XML header";anyMatch[out;"<?xml"]];
  assert["4b has testsuites";anyMatch[out;"<testsuites"]];
  assert["4c has testcase";anyMatch[out;"<testcase"]];
  rmDir dir}

/ ============================================================================
/ Test 5: -errors-only output
/ ============================================================================

test5:{[]
  -1"\n=== 5: -errors-only output ===";
  dir:setupDir[];
  out:runCmd"test ",dir," -noipc -errors-only";
  assert["5a shows summary table";anyMatch[out;"Total"]];
  assert["5b no verbose PASS/FAIL block output";not anyMatch[out;"--- Sections ---"]];
  rmDir dir}

/ ============================================================================
/ Test 6: -listci output
/ ============================================================================

test6:{[]
  -1"\n=== 6: -listci output ===";
  dir:setupDir[];
  out:runCmd"test ",dir," -noipc -listci -errors-only";
  / listci format includes file path with line number
  assert["6a has CI-clickable format";any{any ":" in x}each out];
  rmDir dir}

/ ============================================================================
/ Test 7: diff:none suppresses diffs
/ ============================================================================

test7:{[]
  -1"\n=== 7: diff:none ===";
  dir:mkDir"/tmp/test-qdust-cli-7-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"99")];
  / diff:none is accepted and test runs without error
  out:runCmd"test ",dir," -noipc diff:none";
  assert["7a runs with diff:none";anyMatch[out;"Total"]];
  assert["7b .corrected still created";fileExists dir,"/t.t.corrected"];
  rmDir dir}

/ ============================================================================
/ Test 8: promote command
/ ============================================================================

test8:{[]
  -1"\n=== 8: promote command ===";
  dir:mkDir"/tmp/test-qdust-cli-8-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"99")];
  / Run test to create .corrected
  runCmd"test ",dir," -noipc";
  assert["8a .corrected exists";fileExists dir,"/t.t.corrected"];
  / Promote directory
  runCmd"promote ",dir;
  assert["8b .corrected removed";not fileExists dir,"/t.t.corrected"];
  c:fileContent dir,"/t.t";
  assert["8c file updated with correct value";anyMatch[c;"q)1+1"] and anyMatch[c;"2"]];
  / Re-test passes (single-file mode, no summary table)
  runCmd"test ",dir," -noipc";
  assert["8d passes after promote";not fileExists dir,"/t.t.corrected"];
  rmDir dir}

/ ============================================================================
/ Test 9: check command
/ ============================================================================

test9:{[]
  -1"\n=== 9: check command ===";
  dir:mkDir"/tmp/test-qdust-cli-9-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"2")];
  / No .corrected files — check should pass
  out:runCmd"check ",dir;
  assert["9a OK when clean";anyMatch[out;"No .corrected"]];
  / Create a .corrected file
  writeFile[dir,"/t.t.corrected";enlist"dummy"];
  out:runCmd"check ",dir;
  assert["9b ERROR when .corrected exists";anyMatch[out;"ERROR"]];
  rmDir dir}


/ ============================================================================
/ Test 12: diff command (diff:term)
/ ============================================================================

test12:{[]
  -1"\n=== 12: diff command ===";
  dir:mkDir"/tmp/test-qdust-cli-12-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"99")];
  / Run test to create .corrected
  runCmd"test ",dir,"/t.t -noipc";
  / Run diff
  out:runCmd"-one diff ",dir,"/t.t";
  assert["12a shows diff header";anyMatch[out;"diff"]];
  assert["12b shows diff content";anyMatch[out;"99"] or anyMatch[out;"2"]];
  rmDir dir}

/ ============================================================================
/ Test 13: -noipc flag
/ ============================================================================

test13:{[]
  -1"\n=== 13: -noipc flag ===";
  dir:mkDir"/tmp/test-qdust-cli-13-",string rand 100000;
  writeFile[dir,"/a.t";("q)1+1";"2")];
  writeFile[dir,"/b.t";("q)2+3";"5")];
  out:runCmd"test ",dir," -noipc";
  assert["13a runs in noipc mode";anyMatch[out;"ALL TESTS PASSED"]];
  rmDir dir}

/ ============================================================================
/ Test 14: no args shows help
/ ============================================================================

test14:{[]
  -1"\n=== 14: no args shows help ===";
  out:runCmd"";
  assert["14a shows usage";anyMatch[out;"Usage:"]];
  assert["14b shows test command";anyMatch[out;"q qdust.q test"]];
  assert["14c shows promote command";anyMatch[out;"q qdust.q promote"]];
  assert["14d shows status command";anyMatch[out;"q qdust.q status"]];
  assert["14e shows clean command";anyMatch[out;"q qdust.q clean"]];
  assert["14f shows diff options";anyMatch[out;"diff:term"]]}

/ ============================================================================
/ Test 15: .corrected file content for errors
/ ============================================================================

test15:{[]
  -1"\n=== 15: .corrected with errors ===";
  dir:mkDir"/tmp/test-qdust-cli-15-",string rand 100000;
  writeFile[dir,"/t.t";("q)undefinedXYZ123";"42")];
  runCmd"test ",dir,"/t.t -noipc";
  assert["15a .corrected created";fileExists dir,"/t.t.corrected"];
  c:fileContent dir,"/t.t.corrected";
  assert["15b .corrected has error marker";anyMatch[c;"undefinedXYZ123"]];
  rmDir dir}

/ ============================================================================
/ Test 16: IPC mode (default)
/ ============================================================================

test16:{[]
  -1"\n=== 16: IPC mode ===";
  dir:mkDir"/tmp/test-qdust-cli-16-",string rand 100000;
  writeFile[dir,"/a.t";("q)1+1";"2")];
  writeFile[dir,"/b.t";("q)2+3";"5")];
  out:runCmd"test ",dir;
  assert["16a IPC mode passes";anyMatch[out;"ALL TESTS PASSED"]];
  rmDir dir}

/ ============================================================================
/ Test 17: double-dash flags (--noipc, --json, --errors-only)
/ ============================================================================

test17:{[]
  -1"\n=== 17: double-dash flags ===";
  dir:mkDir"/tmp/test-qdust-cli-17-",string rand 100000;
  writeFile[dir,"/a.t";("q)1+1";"2")];
  writeFile[dir,"/b.t";("q)2+3";"5")];
  / --noipc with double dash
  out:runCmd"test ",dir," --noipc";
  assert["17a --noipc works";anyMatch[out;"ALL TESTS PASSED"]];
  / --json with double dash
  writeFile[dir,"/c.t";("q)1+1";"2")];
  out:runCmd"test ",dir,"/c.t --noipc --json";
  assert["17b --json works";anyMatch[out;"\"passed\""]];
  / --errors-only with double dash
  out:runCmd"test ",dir," --noipc --errors-only";
  assert["17c --errors-only works";not anyMatch[out;"--- Sections ---"]];
  rmDir dir}

/ ============================================================================
/ Test 18: gitignore command
/ ============================================================================

test18:{[]
  -1"\n=== 18: gitignore command ===";
  / gitignore runs in CWD — just verify it produces expected output
  out:runCmd"gitignore";
  assert["18a gitignore runs";anyMatch[out;"gitignore"] or anyMatch[out;"corrected"]];
  }

/ ============================================================================
/ Test 19: -filter flag
/ ============================================================================

test19:{[]
  -1"\n=== 19: -filter flag ===";
  dir:mkDir"/tmp/test-qdust-cli-19-",string rand 100000;
  writeFile[dir,"/alpha.t";("q)1+1";"2")];
  writeFile[dir,"/beta.t";("q)2+3";"5")];
  writeFile[dir,"/gamma.t";("q)3+4";"7")];
  / Filter to only alpha
  out:runCmd"test ",dir," -noipc -filter alpha";
  assert["19a filter matches alpha";anyMatch[out;"alpha"]];
  assert["19b filter excludes beta";not anyMatch[out;"beta"]];
  assert["19c filter excludes gamma";not anyMatch[out;"gamma"]];
  rmDir dir}

/ ============================================================================
/ Test 20: glob pattern target
/ ============================================================================

test20:{[]
  -1"\n=== 20: glob pattern ===";
  dir:mkDir"/tmp/test-qdust-cli-20-",string rand 100000;
  writeFile[dir,"/test_a.t";("q)1+1";"2")];
  writeFile[dir,"/test_b.t";("q)2+3";"5")];
  writeFile[dir,"/other.t";("q)3+4";"7")];
  / Filter with -filter (glob chars in pattern)
  out:runCmd"test ",dir," -noipc -filter test_";
  assert["20a filter matches test_ files";anyMatch[out;"test_a"] or anyMatch[out;"test_b"]];
  assert["20b filter excludes other";not anyMatch[out;"other"]];
  rmDir dir}

/ ============================================================================
/ Test 21: single-file promote
/ ============================================================================

test21:{[]
  -1"\n=== 21: single-file promote ===";
  dir:mkDir"/tmp/test-qdust-cli-21-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"99")];
  runCmd"test ",dir,"/t.t -noipc";
  assert["21a .corrected exists";fileExists dir,"/t.t.corrected"];
  / Promote single file
  runCmd"promote ",dir,"/t.t";
  assert["21b .corrected removed";not fileExists dir,"/t.t.corrected"];
  c:fileContent dir,"/t.t";
  assert["21c file updated";anyMatch[c;"q)1+1"] and anyMatch[c;"2"]];
  rmDir dir}

/ ============================================================================
/ Test 22: -timeout flag (IPC mode)
/ ============================================================================

test22:{[]
  -1"\n=== 22: -timeout flag ===";
  dir:mkDir"/tmp/test-qdust-cli-22-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"2")];
  / -timeout accepted without error
  out:runCmd"test ",dir,"/t.t -timeout 10";
  assert["22a -timeout runs";anyMatch[out;"Passed"]];
  rmDir dir}

/ ============================================================================
/ Test 23: status command
/ ============================================================================

test23:{[]
  -1"\n=== 23: status command ===";
  dir:mkDir"/tmp/test-qdust-cli-23-",string rand 100000;
  writeFile[dir,"/a.t";("q)1+1";"99")];
  writeFile[dir,"/b.t";("q)2+3";"5")];
  / Run tests to create .corrected for a.t only
  runCmd"test ",dir," -noipc";
  / Status should list the corrected file
  out:runCmd"status ",dir;
  assert["23a shows corrected file";anyMatch[out;"a.t"]];
  assert["23b shows file count";anyMatch[out;"pending corrections"]];
  assert["23c does not list passing file";not anyMatch[out;"b.t.corrected"]];
  rmDir dir}

/ ============================================================================
/ Test 24: clean command
/ ============================================================================

test24:{[]
  -1"\n=== 24: clean command ===";
  dir:mkDir"/tmp/test-qdust-cli-24-",string rand 100000;
  writeFile[dir,"/a.t";("q)1+1";"99")];
  writeFile[dir,"/b.t";("q)2+3";"99")];
  / Run tests to create .corrected files
  runCmd"test ",dir," -noipc";
  assert["24a .corrected files exist";fileExists[dir,"/a.t.corrected"] and fileExists[dir,"/b.t.corrected"]];
  / Clean should remove all .corrected files
  out:runCmd"clean ",dir;
  assert["24b .corrected files removed";not[fileExists dir,"/a.t.corrected"] and not fileExists dir,"/b.t.corrected"];
  assert["24c reports removal";anyMatch[out;"Removed"]];
  / Originals still intact
  assert["24d originals untouched";fileExists[dir,"/a.t"] and fileExists[dir,"/b.t"]];
  rmDir dir}

/ ============================================================================
/ Test 25: qdust shell: status
/ ============================================================================

/ Run qdust shell wrapper (with Q disabled to test shell fallback)
runEditor:{[args]
  tmpf:"/tmp/tc_out_",string[`int$.z.t],"_",string[rand 100000],".txt";
  shf:"/tmp/tc_cmd_",string[rand 100000],".sh";
  cmd:"QDUST_Q=/dev/null ",qdustHome,"qdust ",args;
  (hsym`$shf)0:enlist cmd," > ",tmpf," 2>&1";
  @[system;"bash ",shf;{}];
  output:@[read0;hsym`$tmpf;enlist""];
  @[system;"rm -f ",tmpf," ",shf;{}];
  output}

test25:{[]
  -1"\n=== 25: qdust shell: status ===";
  dir:mkDir"/tmp/test-qdust-cli-25-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"2")];
  writeFile[dir,"/t.t.corrected";("q)1+1";"2")];
  out:runEditor"status ",dir;
  assert["25a shows corrected";anyMatch[out;"t.t"]];
  assert["25b shows count";anyMatch[out;"pending corrections"]];
  rmDir dir}

/ ============================================================================
/ Test 26: qdust shell: promote
/ ============================================================================

test26:{[]
  -1"\n=== 26: qdust shell: promote ===";
  dir:mkDir"/tmp/test-qdust-cli-26-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"99")];
  writeFile[dir,"/t.t.corrected";("q)1+1";"2")];
  runEditor"promote ",dir;
  assert["26a .corrected removed";not fileExists dir,"/t.t.corrected"];
  c:fileContent dir,"/t.t";
  assert["26b file updated";anyMatch[c;"2"]];
  rmDir dir}

/ ============================================================================
/ Test 27: qdust shell: diff
/ ============================================================================

test27:{[]
  -1"\n=== 27: qdust shell: diff ===";
  dir:mkDir"/tmp/test-qdust-cli-27-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"99")];
  writeFile[dir,"/t.t.corrected";("q)1+1";"2")];
  out:runEditor"diff ",dir;
  assert["27a shows diff";anyMatch[out;"99"] or anyMatch[out;"2"]];
  rmDir dir}

/ ============================================================================
/ Test 28: qdust shell: clean
/ ============================================================================

test28:{[]
  -1"\n=== 28: qdust shell: clean ===";
  dir:mkDir"/tmp/test-qdust-cli-28-",string rand 100000;
  writeFile[dir,"/t.t";("q)1+1";"99")];
  writeFile[dir,"/t.t.corrected";("q)1+1";"2")];
  runEditor"clean ",dir;
  assert["28a .corrected removed";not fileExists dir,"/t.t.corrected"];
  assert["28b original untouched";fileExists dir,"/t.t"];
  rmDir dir}

/ ============================================================================
/ Test 29: remote hook — single verb
/ ============================================================================

/ Run qdust remote from a given CWD (needs .qd/hooks/ in dir)
/ Resolves qdust path to absolute before cd into temp dir
runRemote:{[dir;args]
  tmpf:"/tmp/tc_out_",string[`int$.z.t],"_",string[rand 100000],".txt";
  shf:"/tmp/tc_cmd_",string[rand 100000],".sh";
  cmd:"cd \"",dir,"\" && QDUST_Q=/dev/null ",qdustHome,"qdust remote ",args;
  (hsym`$shf)0:enlist cmd," > ",tmpf," 2>&1";
  @[system;"bash ",shf;{}];
  output:@[read0;hsym`$tmpf;enlist""];
  @[system;"rm -f ",tmpf," ",shf;{}];
  output}

test29:{[]
  -1"\n=== 29: remote hook — single verb ===";
  dir:mkDir"/tmp/test-qdust-cli-29-",string rand 100000;
  / Set up .qd/hooks/ with a deploy hook that writes a flag
  system"mkdir -p ",dir,"/.qd/hooks";
  writeFile[dir,"/.qd/hooks/deploy";("#!/bin/bash";"echo deployed > \"",dir,"/flag.txt\"")];
  system"chmod +x ",dir,"/.qd/hooks/deploy";
  out:runRemote[dir;"deploy"];
  assert["29a runs deploy";anyMatch[out;"running"]];
  assert["29b hook executed";fileExists dir,"/flag.txt"];
  / lastRun timestamp written
  assert["29c lastrun written";fileExists dir,"/.qd/.lastrun.deploy"];
  rmDir dir}

/ ============================================================================
/ Test 30: remote hook — chain and cycle
/ ============================================================================

test30:{[]
  -1"\n=== 30: remote hook — chain and cycle ===";
  dir:mkDir"/tmp/test-qdust-cli-30-",string rand 100000;
  system"mkdir -p ",dir,"/.qd/hooks";
  writeFile[dir,"/.qd/hooks/deploy";("#!/bin/bash";"echo d >> \"",dir,"/log.txt\"")];
  writeFile[dir,"/.qd/hooks/test";("#!/bin/bash";"echo t >> \"",dir,"/log.txt\"")];
  writeFile[dir,"/.qd/hooks/ingest";("#!/bin/bash";"echo i >> \"",dir,"/log.txt\"")];
  system"chmod +x ",dir,"/.qd/hooks/deploy ",dir,"/.qd/hooks/test ",dir,"/.qd/hooks/ingest";
  / Chain: deploy test ingest
  runRemote[dir;"deploy test ingest"];
  c:fileContent dir,"/log.txt";
  assert["30a all three ran";3=count c];
  / Reset log
  system"rm -f ",dir,"/log.txt";
  / Cycle shorthand
  runRemote[dir;"cycle"];
  c:fileContent dir,"/log.txt";
  assert["30b cycle ran all three";3=count c];
  rmDir dir}

/ ============================================================================
/ Test 31: remote hook — missing hook
/ ============================================================================

test31:{[]
  -1"\n=== 31: remote hook — missing hook ===";
  dir:mkDir"/tmp/test-qdust-cli-31-",string rand 100000;
  system"mkdir -p ",dir,"/.qd/hooks";
  / No deploy hook defined
  out:runRemote[dir;"deploy"];
  assert["31a reports not defined";anyMatch[out;"not defined"]];
  rmDir dir}

/ ============================================================================
/ Test 32: remote hook — skip via env var
/ ============================================================================

test32:{[]
  -1"\n=== 32: remote hook — skip via env var ===";
  dir:mkDir"/tmp/test-qdust-cli-32-",string rand 100000;
  system"mkdir -p ",dir,"/.qd/hooks";
  writeFile[dir,"/.qd/hooks/deploy";("#!/bin/bash";"echo deployed")];
  writeFile[dir,"/.qd/hooks/test";("#!/bin/bash";"echo tested")];
  system"chmod +x ",dir,"/.qd/hooks/deploy ",dir,"/.qd/hooks/test";
  / Skip deploy, run test
  tmpf:"/tmp/tc_out_",string[`int$.z.t],"_",string[rand 100000],".txt";
  shf:"/tmp/tc_cmd_",string[rand 100000],".sh";
  cmd:"cd \"",dir,"\" && QDUST_Q=/dev/null QDUST_SKIP_DEPLOY=1 ",qdustHome,"qdust remote deploy test";
  (hsym`$shf)0:enlist cmd," > ",tmpf," 2>&1";
  @[system;"bash ",shf;{}];
  out:@[read0;hsym`$tmpf;enlist""];
  @[system;"rm -f ",tmpf," ",shf;{}];
  assert["32a deploy skipped";anyMatch[out;"skipped"]];
  assert["32b test ran";anyMatch[out;"tested"]];
  rmDir dir}

/ ============================================================================
/ Test 33: remote hook — chain stops on failure
/ ============================================================================

test33:{[]
  -1"\n=== 33: remote hook — chain stops on failure ===";
  dir:mkDir"/tmp/test-qdust-cli-33-",string rand 100000;
  system"mkdir -p ",dir,"/.qd/hooks";
  writeFile[dir,"/.qd/hooks/deploy";("#!/bin/bash";"exit 1")];
  writeFile[dir,"/.qd/hooks/test";("#!/bin/bash";"echo tested > \"",dir,"/flag.txt\"")];
  system"chmod +x ",dir,"/.qd/hooks/deploy ",dir,"/.qd/hooks/test";
  runRemote[dir;"deploy test"];
  assert["33a test did not run after deploy failure";not fileExists dir,"/flag.txt"];
  rmDir dir}

/ ============================================================================
/ Test 34: remote hooks with Q available (Q mode)
/ ============================================================================

/ Run qdust remote with Q available (no QDUST_Q override)
runRemoteQ:{[dir;args]
  tmpf:"/tmp/tc_out_",string[`int$.z.t],"_",string[rand 100000],".txt";
  shf:"/tmp/tc_cmd_",string[rand 100000],".sh";
  cmd:"cd \"",dir,"\" && ",qdustHome,"qdust remote ",args;
  (hsym`$shf)0:enlist cmd," > ",tmpf," 2>&1";
  @[system;"bash ",shf;{}];
  output:@[read0;hsym`$tmpf;enlist""];
  @[system;"rm -f ",tmpf," ",shf;{}];
  output}

test34:{[]
  -1"\n=== 34: remote hooks with Q available ===";
  dir:mkDir"/tmp/test-qdust-cli-34-",string rand 100000;
  system"mkdir -p ",dir,"/.qd/hooks";
  writeFile[dir,"/.qd/hooks/deploy";("#!/bin/bash";"echo d >> \"",dir,"/log.txt\"")];
  writeFile[dir,"/.qd/hooks/test";("#!/bin/bash";"echo t >> \"",dir,"/log.txt\"")];
  writeFile[dir,"/.qd/hooks/ingest";("#!/bin/bash";"echo i >> \"",dir,"/log.txt\"")];
  system"chmod +x ",dir,"/.qd/hooks/deploy ",dir,"/.qd/hooks/test ",dir,"/.qd/hooks/ingest";
  / Single verb with Q available
  out:runRemoteQ[dir;"deploy"];
  assert["34a deploy runs with Q";anyMatch[out;"running"]];
  assert["34b hook executed";fileExists dir,"/log.txt"];
  / Chain with Q available
  system"rm -f ",dir,"/log.txt";
  runRemoteQ[dir;"cycle"];
  c:fileContent dir,"/log.txt";
  assert["34c cycle runs all three with Q";3=count c];
  / lastRun timestamps
  assert["34d lastrun.deploy";fileExists dir,"/.qd/.lastrun.deploy"];
  assert["34e lastrun.test";fileExists dir,"/.qd/.lastrun.test"];
  assert["34f lastrun.ingest";fileExists dir,"/.qd/.lastrun.ingest"];
  rmDir dir}

/ ============================================================================
/ Test 35: remote hook — missing hooks dir
/ ============================================================================

test35:{[]
  -1"\n=== 35: remote hook — no hooks dir ===";
  dir:mkDir"/tmp/test-qdust-cli-35-",string rand 100000;
  / .qd exists but no hooks/ directory
  system"touch ",dir,"/.qd";
  out:runRemote[dir;"deploy"];
  assert["35a reports no hooks dir";anyMatch[out;"No hooks directory"]];
  rmDir dir}

/ ============================================================================
/ Test 36: remote hook — no .qd root
/ ============================================================================

test36:{[]
  -1"\n=== 36: remote hook — no .qd root ===";
  dir:mkDir"/tmp/test-qdust-cli-36-",string rand 100000;
  / No .qd at all
  out:runRemote[dir;"deploy"];
  assert["36a reports no project root";anyMatch[out;"No .qd project root"]];
  rmDir dir}

/ ============================================================================
/ Test 37: remote hook — no args shows usage
/ ============================================================================

test37:{[]
  -1"\n=== 37: remote hook — no args ===";
  dir:mkDir"/tmp/test-qdust-cli-37-",string rand 100000;
  system"mkdir -p ",dir,"/.qd/hooks";
  out:runRemote[dir;""];
  assert["37a shows usage";anyMatch[out;"Usage"]];
  rmDir dir}

/ ============================================================================
/ Run All
/ ============================================================================

\d .

-1"qdust CLI integration tests";
-1"==============================";

.tc.test1[];
.tc.test2[];
.tc.test3[];
.tc.test4[];
.tc.test5[];
.tc.test6[];
.tc.test7[];
.tc.test8[];
.tc.test9[];
.tc.test12[];
.tc.test13[];
.tc.test14[];
.tc.test15[];
.tc.test16[];
.tc.test17[];
.tc.test18[];
.tc.test19[];
.tc.test20[];
.tc.test21[];
.tc.test22[];
.tc.test23[];
.tc.test24[];
.tc.test25[];
.tc.test26[];
.tc.test27[];
.tc.test28[];
.tc.test29[];
.tc.test30[];
.tc.test31[];
.tc.test32[];
.tc.test33[];
.tc.test34[];
.tc.test35[];
.tc.test36[];
.tc.test37[];

-1"\n========================================";
-1"Results: ",string[.tc.pass]," passed, ",string[.tc.fail]," failed, ",string[.tc.total]," total";
-1"========================================";
exit $[0=.tc.fail;0;1]
