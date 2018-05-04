create or replace package fss_cr_utils.gen_texp_test is

  -- Author  : INOVOZHILOV
  -- Created : 15.04.2018 20:45:47
  -- Purpose : тестирование генератора gen_texp
  
  
  type t_record is record(
  r_number number,
  r_varchar2 varchar2(4000),
  r_big_varchar2 varchar2(32767),
  r_date date,
  r_boolean boolean,
  r_timestamp timestamp,
  r_timestamp_tz timestamp with time zone,  
  r_clob clob,
  r_table fss_cr_common.t_number_tab,
  r_table2 fss_cr_common.t_number2_tab,
  r_object fss_cr_common.t_number2_rec
  
  );
  
  type t_table is table of number;
  
  type t_idx_table is table of number index by pls_integer;
  type t_vidx_table is table of number index by varchar2(4000);
  type t_vidx_table2 is table of number index by varchar2(32767);
  
  type t_complex_record is record (
  r_type t_record,
  r_varchar2 varchar2(4000),
  r_table t_idx_table,
  r_table2 t_vidx_table  
  );
  
  type t_complex_table is table of t_record;
  
  type t_complex_table2 is table of t_record index by varchar2(4000);
  
  type t_complex_table3 is table of t_complex_record index by varchar2(4000);
  
  type t_complex_record2 is record  
  (r_complex_table t_complex_table3,
   r_complex_record t_complex_record,
   r_varchar2 varchar2(32767));
  
  
  procedure tst(p1 t_record, 
  p2 t_table, 
  p3 t_idx_table,   
  p4 t_vidx_table, 
  p5 t_vidx_table2, 
  p6 t_complex_record, 
  p7 t_complex_table, 
  p8 t_complex_table2, 
  p9 t_complex_table3, 
  p10 t_complex_record2
  );
  

end gen_texp_test;
/
