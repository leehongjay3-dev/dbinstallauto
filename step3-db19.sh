mkdir -p $ORACLE_BASE/oradata                        
dbca -silent -createDatabase                         \
-templateName General_Purpose.dbc                    \
-gdbname orcl   -sid orcl   -characterSet AL32UTF8   \
-sysPassword Szdb123p   -systemPassword Szdb123p     \
-memoryPercentage 30   -emConfiguration NONE         \
-datafileDestination $ORACLE_BASE/oradata  
