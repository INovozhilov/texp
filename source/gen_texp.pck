create or replace package fss_cr_utils.gen_texp authid current_user is

  -- Author  : NOVOZHILOV
  -- Created : 15.04.2018 
  -- Purpose : Генерация пакета для сереализации PL/SQL типов

  --Для генерации необходимо указывать пакет ИСПОЛЬЗУЮЩИЙ интересующие типы в качестве входных параметров в процедуры, объявленные в спецификации
  --Необходимо контролировать, чтобы пакеты был скомпилированы и валидны
  --p_owner - владелец пакетов, использующих pl/sql тип
  --p_packages - имена пакетов, для которых генерировать, используемые типы
  --Выдает в clob пакет, для генерации
  procedure generate(p_clob     out nocopy clob,
                     p_owner    in varchar2,
                     p_packages in varchar2);
end gen_texp;
/
create or replace package body fss_cr_utils.gen_texp is

  gc_package_name constant varchar2(100) := 'texp';

  gc_version constant varchar2(10 char) := 'v0.1';

  gc_info constant varchar2(4000 char) := 'Пакет сгенерирован с помощью генератора '|| $$plsql_unit ||'('||gc_version||') для пакетов "[PACKAGES]" схемы "[OWNER]"';

  gc_spec_head constant varchar2(32767) :=
 'create or replace package [OWNER].'||gc_package_name|| 
 ' is 
--'||gc_info||' 
procedure e(p_clob in out nocopy clob, p_value in boolean, p_path in varchar2 default null, b_internal_call in boolean default false);
procedure e(p_clob in out nocopy clob, p_value in number, p_path in varchar2 default null, b_internal_call in boolean default false);
procedure e(p_clob in out nocopy clob, p_value in varchar2, p_path in varchar2 default null, b_internal_call in boolean default false);
procedure e(p_clob in out nocopy clob, p_value in date, p_path in varchar2 default null, b_internal_call in boolean default false);
procedure e(p_clob in out nocopy clob, p_value in timestamp, p_path in varchar2 default null, b_internal_call in boolean default false);
procedure e(p_clob in out nocopy clob, p_value in timestamp with time zone, p_path in varchar2 default null, b_internal_call in boolean default false);  
';


/*
TODO: owner="INovozhilov" created="16.04.2018"
text="Разобраться с экранированием спецсимволов"
*/
/*
TODO: owner="INovozhilov" created="16.04.2018"
text="СДелать защиту от наличия в тексте закрывающей пары символов (""}'"")
      Например, можно сделать словарь и перебирать, какие символы не встречаются
      Либо вернутся к обычному экранированию - ''"
*/
  gc_body_head constant varchar2(32767) := 
 'create or replace package body [OWNER].'||gc_package_name||  
 q'[ is
 
g_clob_part varchar2(32000);

procedure p(p_clob  in out nocopy clob, p_value in varchar2, p_newline in boolean default true) is
begin
  g_clob_part := g_clob_part || p_value || case when p_newline then chr(10) end;
exception
  when value_error then
    if p_clob is null then
      p_clob := g_clob_part;
    else
      p_clob := p_clob || to_clob(g_clob_part);
    end if;
    g_clob_part := p_value || case when p_newline then chr(10) end;
end p;

procedure pp(p_clob in out nocopy clob, p_value in varchar2, p_path in varchar2, b_internal_call in boolean) is
begin
  if not b_internal_call then g_clob_part := null; end if;
  if p_path is not null then
    if p_value is not null then
      p(p_clob, p_path || ' := '||p_value ||';');
    end if;  
  else
    p(p_clob, nvl(p_value,'null'), false);
  end if;    
  if not b_internal_call then p_clob := p_clob || to_clob(g_clob_part); g_clob_part := null; end if;        
end pp;

procedure e(p_clob in out nocopy clob) is
begin
  p(p_clob, 'null', false);
end e;

procedure e(p_clob in out nocopy clob, p_value in boolean, p_path in varchar2 default null, b_internal_call in boolean default false) is
begin
  pp(p_clob, case p_value when true then 'true' when false then 'false' end, p_path, b_internal_call);
end e;

procedure e(p_clob in out nocopy clob, p_value in number, p_path in varchar2 default null,  b_internal_call in boolean default false) is
begin
  pp(p_clob, rtrim(to_char(p_value,'fm999999999999999999990d99999999999999999999',
                               'NLS_NUMERIC_CHARACTERS = ''. '''),'.'), p_path, b_internal_call);
end e;

procedure e(p_clob in out nocopy clob, p_value in date, p_path in varchar2 default null, b_internal_call in boolean default false) is
c_format constant varchar2(100 char) := 'DD.MM.YYYY hh24:mi:ss';            
begin
 pp(p_clob, 'to_date('''|| to_char(p_value, c_format ) ||''','''||c_format||''')', p_path, b_internal_call); 
end e;

procedure e(p_clob in out nocopy clob, p_value in timestamp, p_path in varchar2 default null, b_internal_call in boolean default false) is
c_format constant varchar2(100 char) := 'DD.MM.YYYY hh24:mi:ss.FF9';            
begin
  pp(p_clob, 'to_timestamp('''|| to_char(p_value, c_format ) ||''','''||c_format||''')', p_path, b_internal_call);
end e;

procedure e(p_clob in out nocopy clob, p_value in timestamp with time zone, p_path in varchar2 default null, b_internal_call in boolean default false) is
c_format constant varchar2(100 char) := 'DD.MM.YYYY hh24:mi:ss.FF TZH:TZM';            
begin
  pp(p_clob, 'to_timestamp_tz('''|| to_char(p_value, c_format ) ||''','''||c_format||''')', p_path, b_internal_call);
end e;

procedure e(p_clob in out nocopy clob, p_value in varchar2, p_path in varchar2 default null, b_internal_call in boolean default false) is
  procedure int_(p_int_val in varchar2, p_first boolean default true) is
    l_value varchar(32000);
  begin
    begin
      l_value := p_int_val;
      --Непонятно, необходима ли обработка спец символов 
      --При необходимости, не просто расскоментировать, а дописать в генераторе с учетом q-механизма(q'{) для строковых литералов
      --l_value := replace(l_value, chr(10), q'{' || CHR(10) || '}'); --newline   
      --l_value := replace(l_value, chr(13), q'{' || CHR(13) || '}'); --newline
      --l_value := replace(l_value, CHR(38), q'{' || CHR(38) || '}'); --&
      -- удаление символа \n, который почему-то завершает строковые значения в поле sys.v$session.machine
      l_value := replace(l_value, chr(0));
    exception when value_error then
        --Строка привысила допустимые размеры. обреботаем частями
      declare
        l_half number := trunc(length(p_int_val)/2);
      begin 
        int_(substr(p_value, 1, l_half), p_first);
        int_(substr(p_value, l_half + 1), false);
        return; 
      end;
    end;
    --Раз в год и палка стреляет - сделать защиту от встречания в тексте закрывающиегося тэго ("}'")
    p(p_clob, case when not p_first then ' || ' end || 'q''{'|| l_value ||'}''', false);
  end int_;    
begin
  if not b_internal_call then g_clob_part := null; end if;
  if p_path is not null then
    if (p_value is not null) then
      p(p_clob, p_path || ' := ', false);
      int_(p_value);
      p(p_clob, ';');
    end if;
  else
    int_(p_value);
  end if;  
  if not b_internal_call then p_clob := p_clob || to_clob(g_clob_part); g_clob_part := null; end if;
end e;
]';--'Обходим проблему pl/sql developera с подсведкой        

  g_spec clob := null;
  g_spec_part varchar2(32767);

  g_body clob := null;  
  g_body_part varchar2(32767);



  procedure p(p_clob  in out nocopy clob, 
              p_clob_part in out nocopy varchar2,
              p_value in varchar2) is
  begin
    p_clob_part := p_clob_part || p_value ||chr(10);
  exception
    when value_error then
      if p_clob is null then
        p_clob := p_clob_part;
      else
        p_clob := p_clob || to_clob(p_clob_part);
      end if;
      p_clob_part := p_value ||chr(10);      
  end p;
  
  procedure ps(p_value in varchar2 default null) is
  begin
    p(g_spec, g_spec_part, p_value);
  end ps;


  procedure pb(p_value in varchar2 default null) is
  begin
    p(g_body, g_body_part, p_value);
  end pb;  
  
  --Определяем тип данных индекса у index by table
  --лучше варианта, чем проверить присвоением не нашлось
  function index_type(type_owner   varchar2,
                      type_name    varchar2,
                      type_subname varchar2) return varchar2 is
    l_result varchar2(50) := 'UNKNOWN';
  begin
    execute immediate q'[
        declare
          l_result varchar(50);
          v "]' || type_owner || '"."' || type_name || '"."' || type_subname || q'[";
        begin
          begin
            v('A') := null;
            l_result := 'varchar2';
          exception
            when value_error then
              begin
                v(1) := null;
                l_result := 'pls_integer';
              exception
                when value_error then l_result := 'UNKNOWN';
              end;
          end;

          :result := l_result;
        end;]'
      using out l_result;

    if l_result = 'UNKNOWN' then
      raise_application_error(-20999,'Не удалось определить тип данных ключ index by коллекции "'|| type_owner || '"."' || type_name || '"."' || type_subname ||'"',false);  
    end if;
    
    return l_result;

  end index_type;

  procedure generate_type(p_type_owner   in all_arguments.type_owner%type,
                          p_type_name    in all_arguments.type_name%type,
                          p_type_subname in all_arguments.type_subname%type) is
  
    l_first_seq     all_arguments.sequence%type;
    l_next_arg_seq  all_arguments.sequence%type;
    l_data_level    all_arguments.data_level%type;
    l_object_id     all_arguments.object_id%type;
    l_overload      all_arguments.overload%type;
    l_subprogram_id all_arguments.subprogram_id%type;
  
    l_object_name all_arguments.object_name%type;
    l_data_type   all_arguments.data_type%type;
    l_owner       all_arguments.owner%type;
  
    l_full_type_name varchar2(1000);
  
    procedure p(p_value in varchar2) is
    begin
      /*dbms_lob.writeappend(p_clob,
      length(p_value || chr(13) || chr(10)),
      p_value || chr(13) || chr(10)); */
      dbms_output.put_line(p_value);
    end p;
  
  begin
    --определяю первое попавшееся вхождение искомого типа
    <<type_info>>
    begin
      select a.sequence,
             a.data_level,
             (select min(a2.sequence)
                from all_arguments a2
               where a2.owner = a.owner
                 and a2.object_name = a.object_name
                 and decode(a2.package_name, a.package_name, 1) = 1
                 and a2.object_id = a.object_id
                 and decode(a2.overload, a.overload,1) = 1
                 and a2.sequence > a.sequence
                 and a2.data_level <= a.data_level),
             a.data_type,
             a.object_id,
             a.overload,
             a.subprogram_id,
             a.object_name,
             a.owner
        into l_first_seq,
             l_data_level,
             l_next_arg_seq,
             l_data_type,
             l_object_id,
             l_overload,
             l_subprogram_id,
             l_object_name,
             l_owner
        from all_arguments a    
               where decode(a.type_owner, p_type_owner, 1) = 1
                 and decode(a.type_subname, p_type_subname, 1) = 1
                 and a.type_name = p_type_name
                 and rownum = 1;
    exception
      when others then
        raise_application_error(-20999,
                                'Проблема с типом p_type_owner: ' || p_type_owner || ' p _type_subname: ' ||
                                p_type_subname || ' p_type_name: ' || p_type_name || chr(10) || sqlerrm || chr(10) ||
                                dbms_utility.format_error_backtrace,
                                false);
    end type_info;
  
    l_full_type_name := lower(p_type_owner || '.' || p_type_name || case
                          when p_type_subname is not null then
                           '.' || p_type_subname
                        end);

    ps('procedure e(p_clob in out nocopy clob, p_value in ' || l_full_type_name || ', p_path in varchar2 default null, b_internal_call boolean default false);');  
    pb('procedure e(p_clob in out nocopy clob, p_value in ' || l_full_type_name || ', p_path in varchar2 default null, b_internal_call boolean default false) is');
  
    <<data_type>>case
    
      when l_data_type = 'PL/SQL RECORD' then
        pb('begin');
        pb('  if not b_internal_call then g_clob_part := null; end if;');
        --цикл по аттрибутам PLSQL типа
        <<record_type_attrs>>
        for cur in (select a.data_type,
                           a.type_owner,
                           a.type_name,
                           a.type_subname,
                           lower(a.argument_name) as argument_name,
                           a.char_length
                      from all_arguments a
                     where a.owner = l_owner
                       and a.object_id = l_object_id
                       and decode(a.overload,
                                  l_overload,
                                  1) = 1
                       and a.subprogram_id = l_subprogram_id
                       and a.object_name = l_object_name
                          --Смотрим атрибуты - их уровень на 1 больше
                       and a.data_level = l_data_level + 1
                          --смотрим только дочерние элементы рассматриваемого типа, не других (start<sequence < end)
                       and a.sequence > l_first_seq
                       and (l_next_arg_seq is null or a.sequence < l_next_arg_seq)
                    
                     order by a.sequence) loop
        
          pb('  e(p_clob, p_value.' || cur.argument_name || ', p_path||''.' || cur.argument_name || ''', true);');
        
        end loop record_type_attrs;
    
    --для index by plsql типов l_data_type = 'PL/SQL TABLE'
    --для sql и plsql table (не index by) l_data_type= 'TABLE'
      when (l_data_type = 'PL/SQL TABLE') or (l_data_type = 'TABLE') then
        <<table_processing>>
        declare
          l_row all_arguments%rowtype;
          l_index_type varchar2(20 char);
        begin
          begin
            --если аргумент - PL/SQL TABLE, то следующей строкой в scripts_all_arguments идет тип, из которых и состоит PL/SQL TABLE
            select /*+ index (a i2_scripts_all_arguments)*/
             *
              into l_row
              from all_arguments a
             where a.owner = l_owner
               and a.object_id = l_object_id
               and decode(a.overload, l_overload, 1) = 1
               and a.subprogram_id = l_subprogram_id
               and a.object_name = l_object_name
               and a.sequence > l_first_seq
               and (l_next_arg_seq is null or a.sequence < l_next_arg_seq)
               and a.data_level = l_data_level + 1;
          exception
            when no_data_found or too_many_rows then
              raise_application_error(-20999,
                                      'Проблема с типом p_type_owner: ' || l_owner || 'l_object_id: ' ||
                                      l_object_id || ' l_overload: ' || l_overload || ' l_object_name: ' ||
                                      l_object_name || ' l_first_seq: ' || l_first_seq ||
                                      ' l_next_arg_seq: ' || l_next_arg_seq || ' l_data_level: ' ||
                                      l_data_level,
                                      true);
          end;
          
          if l_data_type = 'PL/SQL TABLE' then
            l_index_type := index_type(p_type_owner, p_type_name, p_type_subname);
          else
            l_index_type := 'pls_integer';  
          end if;
          
          pb('  l_idx  ' || case when l_index_type = 'varchar2' then 'varchar2(32767)' else l_index_type end || ';');
          pb('begin');
          pb('  if not b_internal_call then g_clob_part := null; end if;');        


          if l_data_type = 'TABLE' then          
          pb('  if p_value is not null then ');
            pb('    p(p_clob, p_path || '':= ' || l_full_type_name || '();'');');          
            pb(q'[    p(p_clob,  p_path ||'.extend('||p_value.count||');' );]');          
          end if;
        
          pb('    l_idx := p_value.first;');        
          pb('    while l_idx is not null loop');
          if l_index_type =  'pls_integer' then
            pb(q'[      e(p_clob, p_value(l_idx), p_path||'('||l_idx||')', true);]'); --'Обходим проблему pl/sql developera с подсведкой        
          else
            pb(q'[      e(p_clob, p_value(l_idx), p_path||'('''||l_idx||''')', true);]'); --'Обходим проблему pl/sql developera с подсведкой        
          end if;
          pb(q'[      l_idx := p_value.next(l_idx);]');
          pb('    end loop;');
          if l_data_type = 'TABLE' then                   
            pb('  end if;'); --p_value is not null
          end if;        
        end table_processing;

      else
        /*
        TODO: owner="INovozhilov" created="16.04.2018"
        text="Реализовать поддержку объектных (SQL) типов"
        */
        raise_application_error(-20999,
                                l_full_type_name || ' datatype "' || l_data_type || '"does''t support');
    end case data_type;
    pb('  if not b_internal_call then p_clob := p_clob || to_clob(g_clob_part); g_clob_part := null; end if;');
    pb('end e;');
    pb;
  
  end generate_type;

  procedure des_getexpression(p_anytype anytype) is
    
    l_typecode pls_integer;

    l_prec           pls_integer;
    l_scale          pls_integer;
    l_len            pls_integer;
    l_csid           pls_integer;
    l_csfrm          pls_integer;
    l_schema_name    varchar2(4000);
    l_type_name      varchar2(4000);
    l_version        varchar2(4000);
    l_count          pls_integer;
    l_clob_res_block varchar2(32767);
    l_full_type_name varchar2(4000);

    --режим обхода ошибки
    c_workaround_mode CONSTANT BOOLEAN := TRUE;


    TYPE tvarcharlist IS TABLE OF VARCHAR2(32767) INDEX BY PLS_INTEGER;
    
    l_unproccessed tvarcharlist;

    l_function_name CONSTANT VARCHAR2(100) := 'get_expression';

    l_clob_function_name     CONSTANT VARCHAR2(100) := 'append_clob';
    l_clob_int_function_name CONSTANT VARCHAR2(100) := 'p';

    l_value_str                  CONSTANT VARCHAR2(10) := 'p_value';
    l_clob_value_str             CONSTANT VARCHAR2(10) := 'p_clob';
    l_type_name_placer           CONSTANT VARCHAR2(100) := '[TYPE_NAME]';
    
    l_res_block_str              CONSTANT VARCHAR2(20) := '[OBTAINING RESULT]';
    
    l_clob_function_spec_pattern CONSTANT VARCHAR2(100) := 'procedure ' || l_clob_function_name || '(' ||
                                                           l_clob_value_str || ' in out nocopy clob, ' || l_value_str ||
                                                           ' in [TYPE_NAME]);';

    l_clob_structure varchar2(32767) := 'procedure ' || l_clob_function_name || '(' || l_clob_value_str ||
                                        ' in out nocopy clob, ' || l_value_str || ' in [TYPE_NAME])  is  begin if (p_value is not null) then '
                                         || l_res_block_str || ' else e(' || l_clob_value_str || '); end if; end ' || l_clob_function_name || ';';

    l_clob_collection varchar2(32767) := ' declare l_is_first_processed boolean := false; begin ' ||
                                         l_clob_int_function_name || ' (' || l_clob_value_str || ',''[TYPE_NAME]''||''('', false); for i in 1 .. ' || l_value_str ||
                                         '.count loop ' || 'if l_is_first_processed then ' || l_clob_int_function_name || '(' ||
                                         l_clob_value_str || ','','', false); else l_is_first_processed := true; end if;e(' || l_clob_value_str || ',' || l_value_str || '(i)' || ');' ||
                                         ' end loop;' || l_clob_int_function_name || '(' || l_clob_value_str ||
                                         ','', false)'');' || ' end;';

    l_clob_wrap_spec varchar2(32767) := 'procedure e(p_clob in out nocopy clob, p_value in [TYPE_NAME], p_path in varchar2 default null, b_internal_call in boolean default false);';

    l_clob_wrap varchar2(32767) := 
q'[procedure e(p_clob in out nocopy clob, p_value in [TYPE_NAME], p_path in varchar2 default null, b_internal_call in boolean default false) is
begin
  if not b_internal_call then g_clob_part := null; end if;
  if p_path is not null then
    if p_value is not null then
      p(p_clob, p_path || ' := ', false);  
      append_clob(p_clob, p_value);
      p(p_clob, ';');       
    end if;
  else
    append_clob(p_clob, p_value); 
  end if;
  if not b_internal_call then p_clob := p_clob || to_clob(g_clob_part); g_clob_part := null; end if;
end e;]';

  begin

    l_typecode       := p_anytype.getinfo(l_prec,
                                          l_scale,
                                          l_len,
                                          l_csid,
                                          l_csfrm,
                                          l_schema_name,
                                          l_type_name,
                                          l_version,
                                          l_count);
                                          
    l_full_type_name := l_schema_name ||'.'|| l_type_name;

    case
      when l_typecode = dbms_types.typecode_object then
        declare
          l_prec            pls_integer;
          l_scale           pls_integer;
          l_len             pls_integer;
          l_csid            pls_integer;
          l_csfrm           pls_integer;
          l_schema_name     varchar2(4000);
          l_type_name       varchar2(4000);
          l_version         varchar2(4000);
          l_count           pls_integer;
          l_typecode        pls_integer;
          l_attr_typecode   pls_integer;
          l_attr_anytype    anytype;
          l_aname           varchar2(30);
          l_atrrs_vals      varchar2(32767);
          l_clob_atrrs_vals varchar2(32767);
          l_proccessed      boolean;
        begin
          l_typecode := p_anytype.getinfo(l_prec,
                                          l_scale,
                                          l_len,
                                          l_csid,
                                          l_csfrm,
                                          l_schema_name,
                                          l_type_name,
                                          l_version,
                                          l_count);
          /*    dbms_output.put_line('l_typecode: ' || l_typecode);
          dbms_output.put_line('l_prec: ' || l_prec);
          dbms_output.put_line('l_scale: ' || l_scale);
          dbms_output.put_line('l_len: ' || l_len);
          dbms_output.put_line('l_csid: ' || l_csid);
          dbms_output.put_line('l_csfrm: ' || l_csfrm);
          dbms_output.put_line('l_schema_name: ' || l_schema_name);
          dbms_output.put_line('l_type_name: ' || l_type_name);
          dbms_output.put_line('l_version: ' || l_version);
          dbms_output.put_line('l_count: ' || l_count);*/
        
          for i in 1 .. l_count loop
            if (i <> 1) then
              l_atrrs_vals      := l_atrrs_vals || '||'',''|| ';
              l_clob_atrrs_vals := l_clob_atrrs_vals || l_clob_int_function_name || '(' || l_clob_value_str || ','','');';
            end if;
          
            l_proccessed := false;
            begin
              l_attr_typecode := p_anytype.getattreleminfo(pos           => i,
                                                           prec          => l_prec,
                                                           scale         => l_scale,
                                                           len           => l_len,
                                                           csid          => l_csid,
                                                           csfrm         => l_csfrm,
                                                           attr_elt_type => l_attr_anytype,
                                                           aname         => l_aname);
              l_proccessed    := true;
            exception
              --для атрибутов длиной 30 символов падает ошибка     
              --перехватываем её, тогда l_proccessed := false; 
              when value_error then
                --если режим обхода ошибки включен, то необходимую информацию получаю из представления all_type_attrs
                if c_workaround_mode then
                  declare
                    function get_sql_type_attr_name(p_shema_name in varchar2,
                                                    p_type_name  in user_type_attrs.type_name%type,
                                                    p_attr_num   in user_type_attrs.attr_no%type)
                      return user_type_attrs.attr_name%type is
                      l_result user_type_attrs.attr_name%type;
                    begin
                      select a.attr_name
                        into l_result
                        from all_type_attrs a
                       where a.owner = p_shema_name
                         and a.type_name = p_type_name
                         and a.attr_no = p_attr_num;
                      return l_result;
                    end get_sql_type_attr_name;
                  begin
                    l_aname := get_sql_type_attr_name(l_schema_name,
                                                      l_type_name,
                                                      i);
                  end;
                  l_proccessed := true;
                end if;
                l_unproccessed(l_unproccessed.count + 1) := l_type_name || ' ' || i;
              
            end;
            /*          dbms_output.put_line('i: ' || i);
            dbms_output.put_line('l_attr_typecode: ' || l_attr_typecode);
            dbms_output.put_line('l_prec: ' || l_prec);
            dbms_output.put_line('l_scale: ' || l_scale);
            dbms_output.put_line('l_len: ' || l_len);
            dbms_output.put_line('l_csid: ' || l_csid);
            dbms_output.put_line('l_csfrm: ' || l_csfrm);
            dbms_output.put_line('l_aname: ' || l_aname);*/
          
            if l_proccessed then
              l_atrrs_vals      := l_atrrs_vals || l_function_name || '(' || l_value_str || '.' || l_aname || ')';
              l_clob_atrrs_vals := l_clob_atrrs_vals || 'e(' || l_clob_value_str || ', ' ||
                                   l_value_str || '.' || l_aname || ');';
            else
            
              l_atrrs_vals := l_atrrs_vals || 'raise value_error;/*не обработан аттрибут с позицией ' || i || '*/';
              l_atrrs_vals := l_atrrs_vals || l_function_name || '(' || l_value_str || '.{ATTRIBUTE})';
            
              l_clob_atrrs_vals := l_clob_atrrs_vals || ' raise value_error;/*не обработан аттрибут с позицией ' || i || '*/';
            
              l_clob_atrrs_vals := l_clob_atrrs_vals || 'e(' || l_clob_value_str || ', ' ||
                                   l_value_str || '.{ATTRIBUTE});';
            end if;
          end loop;
          
          l_clob_res_block := l_clob_int_function_name || '(' || l_clob_value_str || ', ''' || l_type_name || '('');';
          l_clob_res_block := l_clob_res_block || l_clob_atrrs_vals;
          l_clob_res_block := l_clob_res_block || l_clob_int_function_name || '(' || l_clob_value_str || ',  '')'');';
        end;
      
      when l_typecode in (dbms_types.typecode_table,
                          dbms_types.typecode_varray) then
        
        
        l_clob_collection := replace(l_clob_collection,
                                     l_type_name_placer,
                                     l_full_type_name);

                                     
        l_clob_res_block  := l_clob_collection;
      
    end case;
    
   l_clob_structure := replace(l_clob_structure,
                                l_type_name_placer,
                                l_full_type_name);
    l_clob_structure := replace(l_clob_structure,
                                l_res_block_str,
                                l_clob_res_block);
                                

    ps(replace(l_clob_function_spec_pattern, l_type_name_placer, l_full_type_name));
    ps(replace(l_clob_wrap_spec, l_type_name_placer, l_full_type_name));
                                       
    pb(l_clob_structure);
    pb(replace(l_clob_wrap, l_type_name_placer, l_full_type_name));
                              

  end des_getexpression;
  
  procedure generate_sql(p_owner     in varchar2,
                         p_type_name in varchar2) is
    l_anytype anytype;
  begin
    l_anytype := anytype.getpersistent(p_owner,
                                       p_type_name);  
    des_getexpression(l_anytype);
  end generate_sql;


  procedure generate(p_clob     out nocopy clob,
                     p_owner    in varchar2,
                     p_packages in varchar2) is
  begin

  /*
  TODO: owner="INovozhilov" created="15.04.2018"
  text="Добавить проверку на валидность пакетов"
  */
  /*
  TODO: owner="INovozhilov" created="15.04.2018"
  text="Добавить защиту от изменения типов. Например брать хэш от описывающего его  блока в all_arguments"
  */

    g_spec := null;
    g_spec_part := null;
    g_body := null;
    g_body_part := null;
    
    <<types_loop>>
    for types_cur in (select a.type_owner,
                             a.type_name,
                             a.type_subname
                        from all_arguments a
                       where a.owner = upper(p_owner)
                         and ','||upper(replace(p_packages,' '))||',' like  '%,'||a.package_name ||',%'
                         and (a.type_owner is not null or a.type_name is not null or a.type_subname is not null)
                       group by a.type_owner,
                                a.type_name,
                                a.type_subname
                       order by a.type_owner,
                                a.type_name,
                                a.type_subname) loop
      if types_cur.type_subname is not null then
        generate_type(types_cur.type_owner,
                      types_cur.type_name,
                      types_cur.type_subname);
      else
        generate_sql(types_cur.type_owner,
                     types_cur.type_name);      
      end if;              
    
    end loop types_loop;
        
    p_clob := to_clob(replace(replace(gc_spec_head, '[OWNER]', lower(p_owner)),'[PACKAGES]',lower(replace(p_packages,' '))));
    p_clob := p_clob || g_spec;
    p_clob := p_clob || to_clob(g_spec_part);
    p_clob := p_clob || to_clob('end '||gc_package_name||';' ||chr(10)||'/'||chr(10));
    p_clob := p_clob || to_clob(replace(gc_body_head, '[OWNER]', p_owner));
    p_clob := p_clob || g_body;
    p_clob := p_clob || to_clob(g_body_part);
    p_clob := p_clob || to_clob('end '||gc_package_name||';' ||chr(10)||'/'||chr(10));

  end generate;


end gen_texp;
/
