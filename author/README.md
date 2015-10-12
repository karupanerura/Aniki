## benchmark

```
=============== SCHEMA ===============

BEGIN TRANSACTION;

--
-- Table: author
--
CREATE TABLE author (
id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
name VARCHAR(255)
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
aniki:  9 wallclock secs ( 8.67 usr +  0.03 sys =  8.70 CPU) @ 11494.25/s (n=100000)
=============== INSERT (fetch auto increment id only) ===============
Benchmark: timing 100000 iterations of aniki, teng...
aniki:  9 wallclock secs ( 8.80 usr +  0.02 sys =  8.82 CPU) @ 11337.87/s (n=100000)
teng:  8 wallclock secs ( 8.40 usr +  0.03 sys =  8.43 CPU) @ 11862.40/s (n=100000)
Rate aniki  teng
aniki 11338/s    --   -4%
teng  11862/s    5%    --
=============== INSERT ===============
Benchmark: timing 10000 iterations of aniki, dbic, teng...
aniki:  1 wallclock secs ( 1.09 usr +  0.01 sys =  1.10 CPU) @ 9090.91/s (n=10000)
dbic:  4 wallclock secs ( 3.71 usr +  0.01 sys =  3.72 CPU) @ 2688.17/s (n=10000)
teng:  3 wallclock secs ( 2.97 usr +  0.01 sys =  2.98 CPU) @ 3355.70/s (n=10000)
Rate  dbic  teng aniki
dbic  2688/s    --  -20%  -70%
teng  3356/s   25%    --  -63%
aniki 9091/s  238%  171%    --
=============== SELECT ===============
Benchmark: timing 20000 iterations of aniki, dbic, teng...
aniki:  6 wallclock secs ( 5.60 usr +  0.01 sys =  5.61 CPU) @ 3565.06/s (n=20000)
dbic: 11 wallclock secs (11.56 usr +  0.03 sys = 11.59 CPU) @ 1725.63/s (n=20000)
teng:  6 wallclock secs ( 5.49 usr +  0.02 sys =  5.51 CPU) @ 3629.76/s (n=20000)
Rate  dbic aniki  teng
dbic  1726/s    --  -52%  -52%
aniki 3565/s  107%    --   -2%
teng  3630/s  110%    2%    --
```
