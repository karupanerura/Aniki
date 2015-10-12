## benchmark

```
=============== SCHEMA ===============

BEGIN TRANSACTION;

--
-- Table: author
--
CREATE TABLE author (
id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
name VARCHAR(255),
message VARCHAR(255) DEFAULT 'hello'
);

CREATE UNIQUE INDEX name_uniq ON author (name);

--
-- Table: module
--
CREATE TABLE module (
id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
name VARCHAR(255),
author_id INTEGER
);

CREATE INDEX author_id_idx ON module (author_id);

COMMIT;
=============== INSERT (no fetch) ===============
Benchmark: timing 100000 iterations of aniki...
aniki:  7 wallclock secs ( 6.56 usr +  0.03 sys =  6.59 CPU) @ 15174.51/s (n=100000)
=============== INSERT (fetch auto increment id only) ===============
Benchmark: timing 100000 iterations of aniki, teng...
aniki:  7 wallclock secs ( 7.37 usr +  0.03 sys =  7.40 CPU) @ 13513.51/s (n=100000)
teng:  7 wallclock secs ( 8.90 usr +  0.04 sys =  8.94 CPU) @ 11185.68/s (n=100000)
Rate  teng aniki
teng  11186/s    --  -17%
aniki 13514/s   21%    --
=============== INSERT ===============
Benchmark: timing 20000 iterations of aniki(emulate), dbic, teng...
aniki(emulate):  1 wallclock secs ( 1.80 usr +  0.01 sys =  1.81 CPU) @ 11049.72/s (n=20000)
dbic:  8 wallclock secs ( 7.83 usr +  0.03 sys =  7.86 CPU) @ 2544.53/s (n=20000)
teng:  7 wallclock secs ( 6.61 usr +  0.02 sys =  6.63 CPU) @ 3016.59/s (n=20000)
Benchmark: timing 20000 iterations of aniki(fetch)...
aniki(fetch):  6 wallclock secs ( 5.58 usr +  0.02 sys =  5.60 CPU) @ 3571.43/s (n=20000)
Rate           dbic          teng  aniki(fetch) aniki(emulate)
dbic            2545/s             --          -16%          -29%           -77%
teng            3017/s            19%            --          -16%           -73%
aniki(fetch)    3571/s            40%           18%            --           -68%
aniki(emulate) 11050/s           334%          266%          209%             --
=============== SELECT ===============
Benchmark: timing 20000 iterations of aniki, dbic, teng...
aniki:  5 wallclock secs ( 4.92 usr +  0.01 sys =  4.93 CPU) @ 4056.80/s (n=20000)
dbic: 12 wallclock secs (12.17 usr +  0.04 sys = 12.21 CPU) @ 1638.00/s (n=20000)
teng:  6 wallclock secs ( 5.86 usr +  0.01 sys =  5.87 CPU) @ 3407.16/s (n=20000)
Rate  dbic  teng aniki
dbic  1638/s    --  -52%  -60%
teng  3407/s  108%    --  -16%
aniki 4057/s  148%   19%    --
=============== UPDATE ===============
Benchmark: timing 20000 iterations of aniki, aniki(row), dbic, teng, teng(row)...
aniki:  1 wallclock secs ( 1.72 usr +  0.01 sys =  1.73 CPU) @ 11560.69/s (n=20000)
aniki(row):  7 wallclock secs ( 6.38 usr +  0.01 sys =  6.39 CPU) @ 3129.89/s (n=20000)
dbic:  9 wallclock secs ( 9.51 usr +  0.03 sys =  9.54 CPU) @ 2096.44/s (n=20000)
teng:  2 wallclock secs ( 1.81 usr +  0.01 sys =  1.82 CPU) @ 10989.01/s (n=20000)
teng(row):  5 wallclock secs ( 4.20 usr +  0.01 sys =  4.21 CPU) @ 4750.59/s (n=20000)
Rate       dbic aniki(row)  teng(row)       teng      aniki
dbic        2096/s         --       -33%       -56%       -81%       -82%
aniki(row)  3130/s        49%         --       -34%       -72%       -73%
teng(row)   4751/s       127%        52%         --       -57%       -59%
teng       10989/s       424%       251%       131%         --        -5%
aniki      11561/s       451%       269%       143%         5%         --
=============== DELETE ===============
Benchmark: timing 20000 iterations of aniki(row), dbic, teng(row)...
aniki(row):  5 wallclock secs ( 5.71 usr +  0.01 sys =  5.72 CPU) @ 3496.50/s (n=20000)
dbic: 30 wallclock secs (29.72 usr +  0.11 sys = 29.83 CPU) @ 670.47/s (n=20000)
teng(row):  6 wallclock secs ( 5.61 usr +  0.01 sys =  5.62 CPU) @ 3558.72/s (n=20000)
Benchmark: timing 20000 iterations of aniki, teng...
aniki:  1 wallclock secs ( 1.19 usr +  0.00 sys =  1.19 CPU) @ 16806.72/s (n=20000)
teng:  2 wallclock secs ( 1.25 usr +  0.00 sys =  1.25 CPU) @ 16000.00/s (n=20000)
Rate       dbic aniki(row)  teng(row)       teng      aniki
dbic         670/s         --       -81%       -81%       -96%       -96%
aniki(row)  3497/s       422%         --        -2%       -78%       -79%
teng(row)   3559/s       431%         2%         --       -78%       -79%
teng       16000/s      2286%       358%       350%         --        -5%
aniki      16807/s      2407%       381%       372%         5%         --
```
