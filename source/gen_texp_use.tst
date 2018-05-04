PL/SQL Developer Test script 3.0
6
begin
  -- Call the procedure
  fss_cr_utils.gen_texp.generate(p_clob => :p_clob,
                                 p_owner => user,
                                 p_packages => 'gen_texp_test');
end;
1
p_clob
1
<CLOB>
112
0
