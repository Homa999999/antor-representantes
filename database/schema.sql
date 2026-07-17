--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.25
-- Dumped by pg_dump version 9.5.25

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


--
-- Name: armor(bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.armor(bytea) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_armor';


ALTER FUNCTION public.armor(bytea) OWNER TO postgres;

--
-- Name: atualiza_comissoes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.atualiza_comissoes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
IF (TG_OP IN ('INSERT','UPDATE')) THEN
    IF not exists (select id from comissoes where periodo=lpad(cast(EXTRACT(Month from new.df10dtemissao) as character(2)), 2, '0')||cast(EXTRACT(year from new.df10dtemissao) as        character(4)) and representante_id=(select aa80id from aa80 where aa80codigo=new.df10repres_cod)
     ) then
	INSERT INTO comissoes (id,representante_id, periodo, comissao) VALUES (new.df10id, (select aa80id from aa80 where aa80codigo=new.df10repres_cod),
	       lpad(cast(EXTRACT(Month from new.df10dtemissao) as character(2)), 2, '0')||cast(EXTRACT(year from new.df10dtemissao) as character(4)),
	       new.df10repres_comisao_valor);
	RETURN NEW;
    ELSE
      update comissoes as com set comissao=(select sum(df10repres_comisao_valor)from df10 where lpad(cast(EXTRACT(Month from df10dtemissao) as character(2)), 2, '0')||cast(EXTRACT             (year from df10dtemissao) as character(4))=com.periodo  and df10repres_cod=(select aa80codigo from aa80 where aa80id=com.representante_id));
    END IF;	
END IF;


IF (TG_OP IN ('DELETE')) THEN
      update comissoes as com set comissao=coalesce((select sum(df10repres_comisao_valor)from df10 where lpad(cast(EXTRACT(Month from df10dtemissao) as character(2)), 2, '0')||      cast(EXTRACT (year from df10dtemissao) as character(4))=com.periodo and df10repres_cod=(select aa80codigo from aa80 where aa80id=com.representante_id)),0);
END IF;

RETURN NULL;
END;
$$;


ALTER FUNCTION public.atualiza_comissoes() OWNER TO postgres;

--
-- Name: autoinc(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.autoinc() RETURNS trigger
    LANGUAGE c
    AS '$libdir/autoinc', 'autoinc';


ALTER FUNCTION public.autoinc() OWNER TO postgres;

--
-- Name: crypt(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.crypt(text, text) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_crypt';


ALTER FUNCTION public.crypt(text, text) OWNER TO postgres;

--
-- Name: dearmor(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dearmor(text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_dearmor';


ALTER FUNCTION public.dearmor(text) OWNER TO postgres;

--
-- Name: decrypt(bytea, bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decrypt(bytea, bytea, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_decrypt';


ALTER FUNCTION public.decrypt(bytea, bytea, text) OWNER TO postgres;

--
-- Name: decrypt_iv(bytea, bytea, bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decrypt_iv(bytea, bytea, bytea, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_decrypt_iv';


ALTER FUNCTION public.decrypt_iv(bytea, bytea, bytea, text) OWNER TO postgres;

--
-- Name: digest(bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.digest(bytea, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_digest';


ALTER FUNCTION public.digest(bytea, text) OWNER TO postgres;

--
-- Name: digest(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.digest(text, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_digest';


ALTER FUNCTION public.digest(text, text) OWNER TO postgres;

--
-- Name: encrypt(bytea, bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.encrypt(bytea, bytea, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_encrypt';


ALTER FUNCTION public.encrypt(bytea, bytea, text) OWNER TO postgres;

--
-- Name: encrypt_iv(bytea, bytea, bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.encrypt_iv(bytea, bytea, bytea, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_encrypt_iv';


ALTER FUNCTION public.encrypt_iv(bytea, bytea, bytea, text) OWNER TO postgres;

--
-- Name: func_get_saldo_cc(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.func_get_saldo_cc(integer, date, date) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
DECLARE
p_conta_id ALIAS FOR $1; 
p_data_inicial ALIAS FOR $2; 
p_data_final ALIAS FOR $3; 
p_entrada numeric;
p_saida numeric;
p_saldo numeric;
p_sql character(5000);
BEGIN

p_entrada = 0;
p_saida = 0;

-- GERA SQL COM AS ENTRADAS
p_sql = 'select sum(lb_valor) from lancamento_bancario  where lb_previsao<>true and lb_bco_id= '|| p_conta_id ||' and lb_credito_debito=''C''';

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (lb_data between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;


execute(p_sql) into p_entrada;

-- GERA SQL COM AS SAIDAS
p_sql = 'select sum(lb_valor) from lancamento_bancario  where lb_previsao<>true and lb_bco_id= '|| p_conta_id ||' and lb_credito_debito=''D''';

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (lb_data between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;



execute(p_sql) into p_saida;

--VERIFICA SE OS RETORNOS SÃO <> DE NULL
if p_entrada is null then
  p_entrada = 0; 
end if;

if p_saida is null then
  p_saida = 0; 
end if;

p_saldo = ((p_entrada - p_saida)); 

RETURN p_saldo; 
END;

$_$;


ALTER FUNCTION public.func_get_saldo_cc(integer, date, date) OWNER TO postgres;

--
-- Name: func_get_saldo_cc_previsao(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.func_get_saldo_cc_previsao(integer, date, date) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
DECLARE
p_conta_id ALIAS FOR $1; 
p_data_inicial ALIAS FOR $2; 
p_data_final ALIAS FOR $3; 
p_entrada numeric;
p_saida numeric;
p_saldo numeric;
p_sql character(5000);
BEGIN

p_entrada = 0;
p_saida = 0;

-- GERA SQL COM AS ENTRADAS
p_sql = 'select sum(lb_valor) from lancamento_bancario  where lb_previsao=true and lb_bco_id= '|| p_conta_id ||' and lb_credito_debito=''C''';

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (lb_data between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;


execute(p_sql) into p_entrada;

-- GERA SQL COM AS SAIDAS
p_sql = 'select sum(lb_valor) from lancamento_bancario  where lb_previsao=true and lb_bco_id= '|| p_conta_id ||' and lb_credito_debito=''D''';

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (lb_data between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;



execute(p_sql) into p_saida;

--VERIFICA SE OS RETORNOS SÃO <> DE NULL
if p_entrada is null then
  p_entrada = 0; 
end if;

if p_saida is null then
  p_saida = 0; 
end if;

p_saldo = ((p_entrada - p_saida)); 

RETURN p_saldo; 
END;

$_$;


ALTER FUNCTION public.func_get_saldo_cc_previsao(integer, date, date) OWNER TO postgres;

--
-- Name: func_get_saldo_credito(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.func_get_saldo_credito(integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
DECLARE
p_cliente_id ALIAS FOR $1; 
p_entrada numeric;
p_saida numeric;
p_saldo numeric;
p_sql character(5000);
BEGIN

p_entrada = 0;
p_saida = 0;

-- GERA SQL COM AS ENTRADAS
p_sql = 'SELECT sum(fcre_valor) FROM "fnc_creditos" WHERE fcre_idcliente = '|| p_cliente_id ||' and fcre_tipo =''C'' ';

execute(p_sql) into p_entrada;

-- GERA SQL COM AS SAIDAS
p_sql = 'SELECT sum(fcre_valor) FROM "fnc_creditos" WHERE fcre_idcliente = '|| p_cliente_id ||' and fcre_tipo =''D'' ';


execute(p_sql) into p_saida;

--VERIFICA SE OS RETORNOS SÃO <> DE NULL
if p_entrada is null then
  p_entrada = 0; 
end if;

if p_saida is null then
  p_saida = 0; 
end if;

p_saldo = (p_entrada - p_saida);

RETURN p_saldo; 
END;

$_$;


ALTER FUNCTION public.func_get_saldo_credito(integer) OWNER TO postgres;

--
-- Name: func_get_saldo_empenhado(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.func_get_saldo_empenhado(integer, integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
DECLARE
p_prod_id ALIAS FOR $1; 
p_deposito_id ALIAS FOR $2;
p_entrada numeric;
p_saida numeric;
p_saldo numeric;
p_sql character(5000);
BEGIN

p_entrada = 0;
p_saida = 0;

-- GERA SQL COM AS ENTRADAS
p_sql = 'SELECT sum(movest_qtde) FROM "mov_estoque" WHERE movest_prod_id = '|| p_prod_id ||' and movest_tipo_movimento = 0 and movest_empenhado = true';

IF p_deposito_id <> 0 THEN
   p_sql = p_sql || ' AND movest_deposito_id = '||p_deposito_id; 
END IF;

execute(p_sql) into p_entrada;

-- GERA SQL COM AS SAIDAS
p_sql = 'SELECT sum(movest_qtde) FROM "mov_estoque" WHERE movest_prod_id = '|| p_prod_id ||' and movest_tipo_movimento = 1 and movest_empenhado = true';

IF p_deposito_id <> 0 THEN
   p_sql = p_sql || ' AND movest_deposito_id = '||p_deposito_id; 
END IF;

execute(p_sql) into p_saida;

--VERIFICA SE OS RETORNOS SÃO <> DE NULL
if p_entrada is null then
  p_entrada = 0; 
end if;

if p_saida is null then
  p_saida = 0; 
end if;

p_saldo = (p_entrada - p_saida);

RETURN p_saldo; 
END;

$_$;


ALTER FUNCTION public.func_get_saldo_empenhado(integer, integer) OWNER TO postgres;

--
-- Name: func_get_saldo_estoque(integer, integer, character, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.func_get_saldo_estoque(integer, integer, character, integer, date, date) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
DECLARE
p_prod_id ALIAS FOR $1; 
p_prod_nivel ALIAS FOR $2;
p_lote ALIAS FOR $3;
p_deposito_id ALIAS FOR $4;
p_data_inicial ALIAS FOR $5;
p_data_final ALIAS FOR $6;
p_entrada numeric;
p_saida numeric;
p_saida_emp_fio numeric;
p_saldo numeric;
p_sql character(5000);
BEGIN

p_entrada = 0;
p_saida = 0;
p_saida_emp_fio = 0;

-- GERA SQL COM AS ENTRADAS
p_sql = 'SELECT sum(movest_qtde) FROM "mov_estoque" WHERE movest_prod_id = '|| p_prod_id ||' and movest_tipo_movimento = 0';

IF p_prod_nivel in (1) THEN
   IF p_lote <> '' THEN
      p_sql = p_sql || ' AND movest_lote = '''||p_lote||''''; 
   END IF;
END IF;

IF p_deposito_id <> 0 THEN
   p_sql = p_sql || ' AND movest_deposito_id = '||p_deposito_id; 
END IF;

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (movest_data_mov between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;

execute(p_sql) into p_entrada;

-- GERA SQL COM AS SAIDAS
p_sql = 'SELECT sum(movest_qtde) FROM "mov_estoque" WHERE movest_prod_id = '|| p_prod_id ||' and movest_tipo_movimento in (1,4)';

IF p_prod_nivel in (1) THEN
   IF p_lote <> '' THEN
      p_sql = p_sql || ' AND movest_lote = '''||p_lote||''''; 
   END IF;
END IF;

IF p_deposito_id <> 0 THEN
   p_sql = p_sql || ' AND movest_deposito_id = '||p_deposito_id; 
END IF;

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (movest_data_mov between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;

execute(p_sql) into p_saida;

-- GERA SQL COM EMPENHO DO FIO
IF p_prod_nivel in (1) THEN

p_sql = 'select
            SUM (osl_quantidade - coalesce((select sum(pec_peso) from pecas where pec_ordem_servico_id = os_id) * (osl_percentual/100),0)) as "EMPENHADO"
         from ordem_servico
         inner join ordem_servico_lote on (osl_os_id = os_id)
         where (os_tipo = 0) and (os_finalizada = false) and osl_aa50id = '|| p_prod_id ||'';

   IF p_lote <> '' THEN
      p_sql = p_sql || ' AND osl_lote = '''||p_lote||''''; 
   END IF;

   IF p_deposito_id <> 0 THEN
      p_sql = p_sql || ' AND os_deposito_id = '||p_deposito_id; 
   END IF;

   IF (p_data_inicial is not null) and (p_data_final is not null) THEN
      p_sql = p_sql || ' AND (os_data_emissao between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
   END IF;

execute(p_sql) into p_saida_emp_fio;

END IF;

--VERIFICA SE OS RETORNOS SÃO <> DE NULL
if p_entrada is null then
  p_entrada = 0; 
end if;

if p_saida is null then
  p_saida = 0; 
end if;

if p_saida_emp_fio is null then
  p_saida_emp_fio = 0; 
end if;

p_saldo = ((p_entrada - p_saida) - p_saida_emp_fio);

RETURN p_saldo; 
END;

$_$;


ALTER FUNCTION public.func_get_saldo_estoque(integer, integer, character, integer, date, date) OWNER TO postgres;

--
-- Name: func_get_saldo_estoque(integer, integer, integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.func_get_saldo_estoque(integer, integer, integer, integer, date, date) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
DECLARE
p_prod_id ALIAS FOR $1; 
p_prod_nivel ALIAS FOR $2;
p_item_prod_id ALIAS FOR $3;
p_deposito_id ALIAS FOR $4;
p_data_inicial ALIAS FOR $5;
p_data_final ALIAS FOR $6;
p_entrada numeric;
p_saida numeric;
p_saldo numeric;
p_sql character(5000);
BEGIN

p_entrada = 0;
p_saida = 0;

-- GERA SQL COM AS ENTRADAS
p_sql = 'SELECT sum(movest_qtde) FROM "mov_estoque" WHERE movest_prod_id = '|| p_prod_id ||' and movest_tipo_movimento = 0';

IF p_prod_nivel in (3,4) THEN
   p_sql = p_sql || ' AND movest_item_id = '||p_item_prod_id; 
END IF;

IF p_deposito_id <> 0 THEN
   p_sql = p_sql || ' AND movest_deposito_id = '||p_deposito_id; 
END IF;

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (movest_data_mov between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;

execute(p_sql) into p_entrada;

-- GERA SQL COM AS SAIDAS
p_sql = 'SELECT sum(movest_qtde) FROM "mov_estoque" WHERE movest_prod_id = '|| p_prod_id ||' and movest_tipo_movimento in (1,4)';

IF p_prod_nivel in (3,4) THEN
   p_sql = p_sql || ' AND movest_item_id ='||p_item_prod_id; 
END IF;

IF p_deposito_id <> 0 THEN
   p_sql = p_sql || ' AND movest_deposito_id = '||p_deposito_id; 
END IF;

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (movest_data_mov between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;

execute(p_sql) into p_saida;

--VERIFICA SE OS RETORNOS SÃO <> DE NULL
if p_entrada is null then
  p_entrada = 0; 
end if;

if p_saida is null then
  p_saida = 0; 
end if;

p_saldo = (p_entrada - p_saida);

RETURN p_saldo; 
END;

$_$;


ALTER FUNCTION public.func_get_saldo_estoque(integer, integer, integer, integer, date, date) OWNER TO postgres;

--
-- Name: func_get_saldo_estoque_sem_empenho(integer, integer, integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.func_get_saldo_estoque_sem_empenho(integer, integer, integer, integer, date, date) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
DECLARE
p_prod_id ALIAS FOR $1; 
p_prod_nivel ALIAS FOR $2;
p_item_prod_id ALIAS FOR $3;
p_deposito_id ALIAS FOR $4;
p_data_inicial ALIAS FOR $5;
p_data_final ALIAS FOR $6;
p_entrada numeric;
p_saida numeric;
p_saldo numeric;
p_sql character(5000);
BEGIN

p_entrada = 0;
p_saida = 0;

-- GERA SQL COM AS ENTRADAS
p_sql = 'SELECT sum(movest_qtde) FROM "mov_estoque" WHERE movest_prod_id = '|| p_prod_id ||' and movest_tipo_movimento = 0 and movest_empenhado=false';

IF p_prod_nivel in (3,4) THEN
   p_sql = p_sql || ' AND movest_item_id = '||p_item_prod_id; 
END IF;

IF p_deposito_id <> 0 THEN
   p_sql = p_sql || ' AND movest_deposito_id = '||p_deposito_id; 
END IF;

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (movest_data_mov between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;

execute(p_sql) into p_entrada;

-- GERA SQL COM AS SAIDAS
p_sql = 'SELECT sum(movest_qtde) FROM "mov_estoque" WHERE movest_prod_id = '|| p_prod_id ||' and movest_tipo_movimento in (1,4) and movest_empenhado=false';

IF p_prod_nivel in (3,4) THEN
   p_sql = p_sql || ' AND movest_item_id ='||p_item_prod_id; 
END IF;

IF p_deposito_id <> 0 THEN
   p_sql = p_sql || ' AND movest_deposito_id = '||p_deposito_id; 
END IF;

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (movest_data_mov between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;

execute(p_sql) into p_saida;

--VERIFICA SE OS RETORNOS SÃO <> DE NULL
if p_entrada is null then
  p_entrada = 0; 
end if;

if p_saida is null then
  p_saida = 0; 
end if;

p_saldo = (p_entrada - p_saida);

RETURN p_saldo; 
END;

$_$;


ALTER FUNCTION public.func_get_saldo_estoque_sem_empenho(integer, integer, integer, integer, date, date) OWNER TO postgres;

--
-- Name: func_get_ultimo_valor(integer, integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.func_get_ultimo_valor(integer, integer, integer, date, date) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
DECLARE
p_prod_id ALIAS FOR $1; 
p_prod_nivel ALIAS FOR $2;
p_item_prod_id ALIAS FOR $3;
p_data_inicial ALIAS FOR $4;
p_data_final ALIAS FOR $5;
p_valor numeric;
p_sql character(5000);
BEGIN

p_valor = 0;
p_sql ='select nfiv_vlr_unitario FROM NF_ITEM INNER JOIN NF_FIXA ON (NFIV_NOTA_ID = nf_id) where NFIV_PRODUTO_ID = '||p_prod_id;

IF p_prod_nivel in (3,4) THEN
   p_sql = p_sql || ' AND nfiv_cor_codigo = '||p_item_prod_id; 
END IF;

IF (p_data_inicial is not null) and (p_data_final is not null) THEN
   p_sql = p_sql || ' AND (nota_dt_emissao between '''||p_data_inicial||''' and '''||p_data_final||''')'; 
END IF;

execute(p_sql) into p_valor;


if p_valor is null then
  p_valor = 0; 
end if;


RETURN p_valor; 
END;

$_$;


ALTER FUNCTION public.func_get_ultimo_valor(integer, integer, integer, date, date) OWNER TO postgres;

--
-- Name: func_total_minutos(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.func_total_minutos(timestamp without time zone, timestamp without time zone) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
p_data_inicio ALIAS FOR $1; 
p_data_final ALIAS FOR $2; 
retorno_em_minutos integer;
BEGIN


retorno_em_minutos = cast(extract('day' from p_data_final-p_data_inicio )* 24  * 60   as integer) + cast(extract('hour' from p_data_final-p_data_inicio) * 60  as integer) +cast(extract('minute' from p_data_final-p_data_inicio)  as integer); 
if retorno_em_minutos is null then
  retorno_em_minutos = 0; 
end if;


RETURN retorno_em_minutos; 
END;

$_$;


ALTER FUNCTION public.func_total_minutos(timestamp without time zone, timestamp without time zone) OWNER TO postgres;

--
-- Name: funcao_total_em_minutos_string(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.funcao_total_em_minutos_string(bigint) RETURNS character
    LANGUAGE plpgsql
    AS $_$
DECLARE
total_minutos ALIAS FOR $1; 
p_horas character(30);
p_minutos character(10);
p_retorno  character(1000);
BEGIN

p_horas      := TO_CHAR(TRUNC((sum(total_minutos ) * 60) / 3600),'FM9900')||' Hr  '||  TO_CHAR(TRUNC(MOD((sum(total_minutos ) * 60), 3600) / 60), 'FM00')||' Min';
--p_minutos    := TO_CHAR(TRUNC(MOD((sum(total_minutos ) * 60), 3600) / 60), 'FM00');
p_retorno    := p_horas;

RETURN p_retorno; 
END;

$_$;


ALTER FUNCTION public.funcao_total_em_minutos_string(bigint) OWNER TO postgres;

--
-- Name: gen_salt(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.gen_salt(text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/pgcrypto', 'pg_gen_salt';


ALTER FUNCTION public.gen_salt(text) OWNER TO postgres;

--
-- Name: gen_salt(text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.gen_salt(text, integer) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/pgcrypto', 'pg_gen_salt_rounds';


ALTER FUNCTION public.gen_salt(text, integer) OWNER TO postgres;

--
-- Name: hmac(bytea, bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.hmac(bytea, bytea, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_hmac';


ALTER FUNCTION public.hmac(bytea, bytea, text) OWNER TO postgres;

--
-- Name: hmac(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.hmac(text, text, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pg_hmac';


ALTER FUNCTION public.hmac(text, text, text) OWNER TO postgres;

--
-- Name: pedido_produzindo(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pedido_produzindo(integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
p_pedido ALIAS FOR $1; 
p_saida integer;
p_sql character(5000);
BEGIN
p_saida = 0;
p_sql = 'select ob_pdi_id from ordem_beneficiamento where ob_pdi_id in (select pdi_id from pdi_item where pdi_id_pedido= '||p_pedido||')';
execute(p_sql) into p_saida;
if p_saida is null then
  p_saida = 0; 
end if;



RETURN p_saida; 
END;

$_$;


ALTER FUNCTION public.pedido_produzindo(integer) OWNER TO postgres;

--
-- Name: pgp_key_id(bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_key_id(bytea) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_key_id_w';


ALTER FUNCTION public.pgp_key_id(bytea) OWNER TO postgres;

--
-- Name: pgp_pub_decrypt(bytea, bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_pub_decrypt(bytea, bytea) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_pub_decrypt_text';


ALTER FUNCTION public.pgp_pub_decrypt(bytea, bytea) OWNER TO postgres;

--
-- Name: pgp_pub_decrypt(bytea, bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_pub_decrypt(bytea, bytea, text) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_pub_decrypt_text';


ALTER FUNCTION public.pgp_pub_decrypt(bytea, bytea, text) OWNER TO postgres;

--
-- Name: pgp_pub_decrypt(bytea, bytea, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_pub_decrypt_text';


ALTER FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text) OWNER TO postgres;

--
-- Name: pgp_pub_decrypt_bytea(bytea, bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_pub_decrypt_bytea';


ALTER FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea) OWNER TO postgres;

--
-- Name: pgp_pub_decrypt_bytea(bytea, bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_pub_decrypt_bytea';


ALTER FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text) OWNER TO postgres;

--
-- Name: pgp_pub_decrypt_bytea(bytea, bytea, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_pub_decrypt_bytea';


ALTER FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text) OWNER TO postgres;

--
-- Name: pgp_pub_encrypt(text, bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_pub_encrypt(text, bytea) RETURNS bytea
    LANGUAGE c STRICT
    AS '$libdir/pgcrypto', 'pgp_pub_encrypt_text';


ALTER FUNCTION public.pgp_pub_encrypt(text, bytea) OWNER TO postgres;

--
-- Name: pgp_pub_encrypt(text, bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_pub_encrypt(text, bytea, text) RETURNS bytea
    LANGUAGE c STRICT
    AS '$libdir/pgcrypto', 'pgp_pub_encrypt_text';


ALTER FUNCTION public.pgp_pub_encrypt(text, bytea, text) OWNER TO postgres;

--
-- Name: pgp_pub_encrypt_bytea(bytea, bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea) RETURNS bytea
    LANGUAGE c STRICT
    AS '$libdir/pgcrypto', 'pgp_pub_encrypt_bytea';


ALTER FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea) OWNER TO postgres;

--
-- Name: pgp_pub_encrypt_bytea(bytea, bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text) RETURNS bytea
    LANGUAGE c STRICT
    AS '$libdir/pgcrypto', 'pgp_pub_encrypt_bytea';


ALTER FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text) OWNER TO postgres;

--
-- Name: pgp_sym_decrypt(bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_sym_decrypt(bytea, text) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_sym_decrypt_text';


ALTER FUNCTION public.pgp_sym_decrypt(bytea, text) OWNER TO postgres;

--
-- Name: pgp_sym_decrypt(bytea, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_sym_decrypt(bytea, text, text) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_sym_decrypt_text';


ALTER FUNCTION public.pgp_sym_decrypt(bytea, text, text) OWNER TO postgres;

--
-- Name: pgp_sym_decrypt_bytea(bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_sym_decrypt_bytea(bytea, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_sym_decrypt_bytea';


ALTER FUNCTION public.pgp_sym_decrypt_bytea(bytea, text) OWNER TO postgres;

--
-- Name: pgp_sym_decrypt_bytea(bytea, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/pgcrypto', 'pgp_sym_decrypt_bytea';


ALTER FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text) OWNER TO postgres;

--
-- Name: pgp_sym_encrypt(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_sym_encrypt(text, text) RETURNS bytea
    LANGUAGE c STRICT
    AS '$libdir/pgcrypto', 'pgp_sym_encrypt_text';


ALTER FUNCTION public.pgp_sym_encrypt(text, text) OWNER TO postgres;

--
-- Name: pgp_sym_encrypt(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_sym_encrypt(text, text, text) RETURNS bytea
    LANGUAGE c STRICT
    AS '$libdir/pgcrypto', 'pgp_sym_encrypt_text';


ALTER FUNCTION public.pgp_sym_encrypt(text, text, text) OWNER TO postgres;

--
-- Name: pgp_sym_encrypt_bytea(bytea, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_sym_encrypt_bytea(bytea, text) RETURNS bytea
    LANGUAGE c STRICT
    AS '$libdir/pgcrypto', 'pgp_sym_encrypt_bytea';


ALTER FUNCTION public.pgp_sym_encrypt_bytea(bytea, text) OWNER TO postgres;

--
-- Name: pgp_sym_encrypt_bytea(bytea, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text) RETURNS bytea
    LANGUAGE c STRICT
    AS '$libdir/pgcrypto', 'pgp_sym_encrypt_bytea';


ALTER FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: aa50; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50 (
    aa50id integer NOT NULL,
    aa50nivel integer,
    aa50grupo character(10) NOT NULL,
    aa50descricao character(500) NOT NULL,
    aa50um character(6),
    aa50linha_produto character(4) NOT NULL,
    aa50colecao character(4),
    aa50artigo_produto character(4),
    aa50conta_estoque character(4),
    aa50classificacao_fiscal character(10),
    aa50comprado_fabricado character(50) NOT NULL,
    aa50tipo_produto character(4) NOT NULL,
    aa50composicao character(4),
    aa50imagem bytea,
    aa50conservacao1 character(4),
    aa50conservacao2 character(4),
    aa50conservacao3 character(4),
    aa50conservacao4 character(4),
    aa50conservacao5 character(4),
    aa50conservacao6 character(4),
    aa50conservacao7 character(4),
    aa50conservacao8 character(4),
    aa50genero character(4),
    aa50cliente character(11),
    aa50utilidadeproduto character(4),
    aa50relacionamento integer,
    aa50empresa integer,
    aa50gramatura numeric(15,3) DEFAULT 0.000,
    aa50largura numeric(15,3) DEFAULT 0.000,
    aa50encolhimento numeric(15,3) DEFAULT 0.000,
    aa50gramatura_m2 numeric(15,3) DEFAULT 0.000,
    aa50espessura numeric(15,3) DEFAULT 0.000,
    aa50observacao text,
    aa50ref_cliente character(20),
    aa50composicao_codigo1 character(4),
    aa50composicao_percentual1 numeric(5,2),
    aa50composicao_codigo2 character(4),
    aa50composicao_percentual2 numeric(5,2),
    aa50composicao_codigo3 character(4),
    aa50composicao_percentual3 numeric(5,2),
    aa50composicao_codigo4 character(4),
    aa50composicao_percentual4 numeric(5,2),
    aa50composicao_codigo5 character(4),
    aa50composicao_percentual5 numeric(5,2),
    aa50composicao_codigo6 character(4),
    aa50composicao_percentual6 numeric(5,2),
    aa50composicao_codigo7 character(4),
    aa50composicao_percentual7 numeric(5,2),
    aa50composicao_codigo8 character(4),
    aa50composicao_percentual8 numeric(5,2),
    aa50exclusivo boolean,
    aa50tipo character(2) DEFAULT 2,
    aa50sugestao_compra character(2) DEFAULT 2,
    aa50bloqueio character(2) DEFAULT 2,
    aa50draw character(2) DEFAULT 2,
    aa50requerimento_compra character(2) DEFAULT 2,
    aa50workflow character(2) DEFAULT 2,
    aa50deposito character(4),
    aa50endereco character(6),
    aa50estq_minimo numeric(15,4),
    aa50estq_maximo numeric(15,4),
    aa50rendimento numeric(15,4) DEFAULT 0.0000,
    aa50evolucao numeric(10,3),
    aa50composicao_abreviacao1 character(5),
    aa50composicao_abreviacao2 character(5),
    aa50composicao_abreviacao3 character(5),
    aa50composicao_abreviacao4 character(5),
    aa50composicao_abreviacao5 character(5),
    aa50composicao_abreviacao6 character(5),
    aa50composicao_abreviacao7 character(5),
    aa50composicao_abreviacao8 character(5),
    aa50composicao_porcentagem1 character(1),
    aa50composicao_porcentagem2 character(1),
    aa50composicao_porcentagem3 character(1),
    aa50composicao_porcentagem4 character(1),
    aa50composicao_porcentagem5 character(1),
    aa50composicao_porcentagem6 character(1),
    aa50composicao_porcentagem7 character(1),
    aa50composicao_porcentagem8 character(1),
    aa50linha_produto_descricao character(50),
    aa50un_medida_faturamento character(3),
    aa50ref_cliente_descricao character(80),
    aa50csticms character(3),
    aa50reducao numeric(5,2),
    aa50diferido numeric(5,2),
    aa50st numeric(5,2),
    aa50reducaost numeric(5,2),
    aa50diferimento numeric(5,2),
    aa50cstcofins character(3),
    aa50aliquotacofins numeric(5,2),
    aa50cstpis character(3),
    aa50aliquotapis numeric(5,2),
    aa50cstipi character(3),
    aa50ipi numeric(5,2),
    aa50contribuicaosocial numeric(15,6),
    aa50operacional numeric(15,6),
    aa50comissoes numeric(5,2),
    aa50energia numeric(15,6),
    aa50csosncst character(3),
    aa50csosnaliquota numeric(5,2),
    aa50dens_base numeric(15,4) DEFAULT 0.0000,
    aa50dens_top numeric(15,4) DEFAULT 0.0000,
    aa50dens_laca numeric(15,4) DEFAULT 0.0000,
    aa50icms_id integer,
    aa50icms_codigo integer,
    aa50icms_tabela character(100),
    aa50cfop_est_id integer,
    aa50cfop_est_natureza character(4),
    aa50cfop_est_descr character(100),
    aa50cfop_fora_id integer,
    aa50cfop_fora_natureza character(4),
    aa50cfop_fora_descr character(100),
    aa50grafico_id integer,
    aa50grafico_codigo character(6),
    aa50grafico_nome character(50),
    aa50_pickup numeric(5,2),
    aa50_fundo integer,
    aa50_volume integer,
    aa50_relacaodebanho numeric(15,4),
    aa50_maquina_id integer,
    aa50_maquina_codigo character(3),
    aa50_maquina_descricao character(80),
    aa50_foulard integer,
    aa50grafico_imagem text,
    aa50estampas_id integer,
    aa50estampas_codigo character(6),
    aa50estampas_descricao character(50),
    aa50artigo_produto_descricao character(50),
    aa50cliente_nome character(100),
    aa50tipo_produto_descricao character(50),
    aa50marcar character(1),
    aa50_ultimopreco numeric(15,4),
    aa50_precomedio numeric(15,4),
    aa50_mediadiaria numeric(15,4),
    aa50grupo_id integer,
    aa50gravacao integer,
    aa50estamparia integer,
    aa50substrato integer,
    aa50papel integer,
    aa50roteiro_id integer,
    aa50aplicacaoformula integer DEFAULT 0,
    aa50pecapadrao numeric,
    aa50inativar boolean DEFAULT false,
    aa50prodpadrao integer DEFAULT 0,
    aa50tiporeceita integer,
    aa50movimentaestoque boolean DEFAULT true,
    aa50conteudoimportacao numeric(15,2) DEFAULT 0,
    aa50ci_valor numeric(10,2),
    aa50valormediovenda numeric(10,2),
    aa50fci character(36),
    aa50descricaotecnica character(500),
    aa50tipofio integer,
    aa50tituloid integer DEFAULT 0,
    aa50papelgram numeric(15,5) DEFAULT 0,
    aa50tara numeric DEFAULT 0,
    aa50percentual_relaxamento numeric,
    aa50_perfil integer,
    aa50codigo_sistema_antigo_materia_prima character(20),
    aa50grupo_maquinas_id integer,
    aa50classificacao_produto_blocok integer,
    aa50conservacao9 character(4),
    aa50conservacao10 character(4),
    aa50conservacao11 character(4),
    aa50conservacao12 character(4),
    aa50conservacao13 character(4),
    aa50conservacao14 character(4),
    aa50conservacao15 character(4),
    aa50conservacao16 character(4),
    aa50conservacao17 character(4),
    aa50conservacao18 character(4),
    aa50conservacao19 character(4),
    aa50conservacao20 character(4),
    aa50conservacao21 character(4),
    aa50conservacao22 character(4),
    aa50conservacao23 character(4),
    aa50conservacao24 character(4),
    aa50conservacao25 character(4),
    aa50conservacao26 character(4),
    aa50conservacao27 character(4),
    aa50conservacao28 character(4),
    aa50conservacao29 character(4),
    aa50conservacao30 character(4),
    aa50prazo_em_dias integer,
    aa50estamparia2 integer,
    aa50acabamento integer,
    aa50preco_para_compor_custo numeric(15,4),
    aa50metros_minutos integer,
    aa50substrato2 integer,
    aa50_vende_forca_de_vendas boolean,
    aa50cest character(20),
    aa50plano_contas integer,
    aa50icms numeric(18,2),
    aa50_usuario_insert integer,
    aa50_usuario_insert_data character(30),
    aa50_usuario_alterou integer,
    aa50_usuario_alterou_data character(30),
    aa50parametros_materia_prima boolean DEFAULT false,
    aa50imagem_76 character(300),
    aa50gtin character(20),
    aa50sd_id integer,
    aa50percentual_seguranca numeric(18,2),
    gerou_estrutura boolean DEFAULT false,
    aa50categoria_custo integer,
    aa50inutilizou_usuario integer,
    aa50inutilizou_data date,
    aa50quebra_custo numeric(18,2),
    aa50teor_absorcao integer,
    aa50sarilho integer,
    aa50velocidade_bomba integer,
    aa50turbovario integer,
    aa50tipotecido integer,
    aa50delicado integer,
    aa50tempo_ciclo integer,
    aa50volume_a_desc integer,
    aa50max_vel_sarilho integer,
    aa50programa character(100),
    aa50viscosidade numeric(18,2),
    aa50velmm numeric(18,2),
    aa50graus_celsius numeric(18,2),
    aa50setup1 integer,
    aa50setup2 integer,
    aa50ph numeric(18,2),
    aa50sub_grupo1 integer,
    aa50sub_grupo2 integer,
    aa50sub_grupo3 integer,
    aa50sub_grupo4 integer,
    aa50sub_grupo5 integer,
    aa50sub_grupo6 integer,
    aa50sub_grupo7 integer,
    aa50sub_grupo1_descricao character(100),
    aa50sub_grupo2_descricao character(100),
    aa50sub_grupo3_descricao character(100),
    aa50sub_grupo4_descricao character(100),
    aa50sub_grupo5_descricao character(100),
    aa50sub_grupo6_descricao character(100),
    aa50sub_grupo7_descricao character(100),
    aa50segmento_mercado_id integer,
    aa50ph2 numeric(18,2),
    aa50tipo_produto_id integer,
    aa50deposito_id integer,
    aa50preco_para_compor_custo_compra numeric(15,4),
    aa50destacar_observacao boolean DEFAULT false,
    aa50ref_cliente2 character(20),
    aa50cst_cbs_ibs integer,
    aa50nao_atualiza_preco_pela_nota boolean DEFAULT false
);


ALTER TABLE public.aa50 OWNER TO postgres;

--
-- Name: COLUMN aa50.aa50grupo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.aa50.aa50grupo IS 'Código do Produto';


--
-- Name: aa50_aa50id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50_aa50id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50_aa50id_seq OWNER TO postgres;

--
-- Name: aa50_aa50id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50_aa50id_seq OWNED BY public.aa50.aa50id;


--
-- Name: aa50componentes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50componentes (
    aa50componente_codigo integer,
    aa50componente_componente integer,
    aa50componente_id integer NOT NULL,
    aa50componente_alternativa character(2),
    aa50componente_cor_id integer,
    aa50componente_cor_codigo character(6),
    aa50componente_qtde numeric(15,6) DEFAULT 0.000000,
    aa50componente_tipo character(1),
    aa50componente_nivel integer,
    aa50componente_referencia character(10),
    aa50componente_descricao character(100),
    aa50componente_componente_nivel integer,
    aa50componente_componente_referencia character(10),
    aa50componente_componente_descricao character(100),
    aa50componente_componente_cor_id integer,
    aa50componente_componente_cor_codigo character(6),
    aa50componente_componente_qtde numeric(15,6) DEFAULT 0.000000,
    aa50componente_componente_un character(3),
    aa50componente_tipo_estrutura integer,
    aa50componente_seq integer,
    aa50componente_estagio_id integer
);


ALTER TABLE public.aa50componentes OWNER TO postgres;

--
-- Name: aa50componentes_aa50componente_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50componentes_aa50componente_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50componentes_aa50componente_id_seq OWNER TO postgres;

--
-- Name: aa50componentes_aa50componente_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50componentes_aa50componente_id_seq OWNED BY public.aa50componentes.aa50componente_id;


--
-- Name: aa50conversao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50conversao_id_seq
    START WITH 14
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50conversao_id_seq OWNER TO postgres;

--
-- Name: aa50conversao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50conversao (
    id integer DEFAULT nextval('public.aa50conversao_id_seq'::regclass) NOT NULL,
    aa50id integer,
    unidade1 character(10),
    unidade2 character(10),
    valor1 numeric(20,6),
    valor2 numeric(20,6)
);


ALTER TABLE public.aa50conversao OWNER TO postgres;

--
-- Name: aa50ct; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50ct (
    aa50ct_id integer NOT NULL,
    aa50ct_produto_id integer,
    aa50ct_produto_id_substitutivo integer,
    aa50ct_percentual numeric(20,4),
    aa50ct_data date,
    aa50ct_usuario integer,
    aa50ct_observacao character(150)
);


ALTER TABLE public.aa50ct OWNER TO postgres;

--
-- Name: aa50ct_aa50ct_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50ct_aa50ct_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50ct_aa50ct_id_seq OWNER TO postgres;

--
-- Name: aa50ct_aa50ct_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50ct_aa50ct_id_seq OWNED BY public.aa50ct.aa50ct_id;


--
-- Name: aa50estrutura; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50estrutura (
    aa50estrutura_id integer NOT NULL,
    aa50estrutura_aa50item integer NOT NULL,
    aa50estrutura_aa50grupo character(10) NOT NULL,
    aa50estrutura_qtd numeric(15,3) NOT NULL
);


ALTER TABLE public.aa50estrutura OWNER TO postgres;

--
-- Name: aa50estrutura_aa50estrutura_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50estrutura_aa50estrutura_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50estrutura_aa50estrutura_id_seq OWNER TO postgres;

--
-- Name: aa50estrutura_aa50estrutura_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50estrutura_aa50estrutura_id_seq OWNED BY public.aa50estrutura.aa50estrutura_id;


--
-- Name: aa50fornecedor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50fornecedor (
    aa50fornecedor_id integer NOT NULL,
    aa50fornecedor_produto integer,
    aa50fornecedor_codigo character(10),
    aa50fornecedor_tempo_reposicao numeric(15,4),
    aa50fornecedor_preco_avista numeric(15,2),
    aa50fornecedor_preco_aprazo numeric(15,2),
    aa50fornecedor_media_uso numeric(15,4),
    aa50fornecedor_primeira_compra date,
    aa50fornecedor_ultima_compra date,
    aa50fornecedor_compra_acumulada numeric(15,4),
    aa50fornecedor_icms numeric(15,2),
    aa50fornecedor_ipi numeric(15,2),
    aa50fornecedor_unidade_compra character(12),
    aa50fornecedor_prod_desc_original character(80),
    aa50fornecedor_produto_codigo character(20),
    aa50fornecedor_contato character(200),
    aa50fornecedor_bloquear_compra boolean DEFAULT false,
    aa50fornecedor_moeda integer DEFAULT 0
);


ALTER TABLE public.aa50fornecedor OWNER TO postgres;

--
-- Name: aa50fornecedor_aa50fornecedor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50fornecedor_aa50fornecedor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50fornecedor_aa50fornecedor_id_seq OWNER TO postgres;

--
-- Name: aa50fornecedor_aa50fornecedor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50fornecedor_aa50fornecedor_id_seq OWNED BY public.aa50fornecedor.aa50fornecedor_id;


--
-- Name: aa50imagem_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50imagem_id_seq
    START WITH 20
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50imagem_id_seq OWNER TO postgres;

--
-- Name: aa50imagem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50imagem (
    id integer DEFAULT nextval('public.aa50imagem_id_seq'::regclass) NOT NULL,
    aa50id integer,
    caminho_imagem text,
    id_ambiente integer
);


ALTER TABLE public.aa50imagem OWNER TO postgres;

--
-- Name: aa50item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50item (
    aa50item_id integer NOT NULL,
    aa50item_codigo character(6) NOT NULL,
    aa50item_descricao character(50),
    aa50item_classificacao character(10),
    aa50item_subgrupo integer,
    aa50item_aa50 integer NOT NULL,
    aa50item_importacao character(20),
    aa50item_peso numeric(15,4) DEFAULT 0.0000,
    aa50item_cor_id integer NOT NULL,
    aa50item_roteiro_id integer,
    aa50item_inativar boolean DEFAULT false,
    aa50item_importacao2 character(20),
    aa50item_liberacao boolean,
    aa50item_solicitacao_desenvolvimento character(15),
    aa50item_vende_forca_de_vendas boolean DEFAULT true,
    aa50item_usuario_insert integer,
    aa50item_usuario_insert_data character(30),
    aa50item_usuario_alterou integer,
    aa50item_usuario_alterou_data character(30),
    aa50item_cenario character(100),
    aa50item_usuario_inativar integer,
    aa50item_data_inativar date
);


ALTER TABLE public.aa50item OWNER TO postgres;

--
-- Name: aa50item_aa50item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50item_aa50item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50item_aa50item_id_seq OWNER TO postgres;

--
-- Name: aa50item_aa50item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50item_aa50item_id_seq OWNED BY public.aa50item.aa50item_id;


--
-- Name: aa50item_acabamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50item_acabamento (
    aa50item_acabamento_id integer NOT NULL,
    aa50item_acabamento_codigo character(4),
    aa50item_acabamento_cor integer
);


ALTER TABLE public.aa50item_acabamento OWNER TO postgres;

--
-- Name: aa50item_acabamento_aa50item_acabamento_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50item_acabamento_aa50item_acabamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50item_acabamento_aa50item_acabamento_id_seq OWNER TO postgres;

--
-- Name: aa50item_acabamento_aa50item_acabamento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50item_acabamento_aa50item_acabamento_id_seq OWNED BY public.aa50item_acabamento.aa50item_acabamento_id;


--
-- Name: aa50item_simula; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50item_simula (
    aa50item_simula_id integer NOT NULL,
    aa50item_simula_categoria integer,
    aa50item_simula_categoria_nome character(60),
    aa50item_simula_item_id integer,
    aa50item_simula_tipo character(200),
    aa50item_simula_codigo integer,
    aa50item_simula_qtde numeric(20,6),
    aa50item_simula_valor numeric(20,6),
    aa50item_simula_unidade character(4),
    aa50item_simula_tipo_calculo character(10),
    aa50item_simula_gordura numeric(18,4),
    aa50item_simula_exibe boolean DEFAULT true,
    aa50item_simula_valor_bkp numeric(20,6),
    aa50item_simula_qtde_bkp numeric(20,6),
    aa50item_simula_permite_alterar boolean
);


ALTER TABLE public.aa50item_simula OWNER TO postgres;

--
-- Name: aa50item_simula_aa50item_simula_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50item_simula_aa50item_simula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50item_simula_aa50item_simula_id_seq OWNER TO postgres;

--
-- Name: aa50item_simula_aa50item_simula_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50item_simula_aa50item_simula_id_seq OWNED BY public.aa50item_simula.aa50item_simula_id;


--
-- Name: aa50log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50log (
    aa50log_id integer NOT NULL,
    aa50log_aa50id integer,
    aa50log_data date,
    aa50log_usuario integer,
    aa50log_observacao character(1000),
    aa50log_hora character(10),
    aa50log_acao character(90)
);


ALTER TABLE public.aa50log OWNER TO postgres;

--
-- Name: aa50log_aa50log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50log_aa50log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50log_aa50log_id_seq OWNER TO postgres;

--
-- Name: aa50log_aa50log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50log_aa50log_id_seq OWNED BY public.aa50log.aa50log_id;


--
-- Name: aa50logpm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50logpm (
    aa50logpm_id integer NOT NULL,
    aa50logpm_aa50id integer,
    aa50logpm_data date,
    aa50logpm_usuario integer,
    aa50logpm_observacao character(1000),
    aa50logpm_hora character(10),
    aa50logpm_acao character(90)
);


ALTER TABLE public.aa50logpm OWNER TO postgres;

--
-- Name: aa50logpm_aa50logpm_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50logpm_aa50logpm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50logpm_aa50logpm_id_seq OWNER TO postgres;

--
-- Name: aa50logpm_aa50logpm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50logpm_aa50logpm_id_seq OWNED BY public.aa50logpm.aa50logpm_id;


--
-- Name: aa50ondeusa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50ondeusa (
    aa50ondeusa_id integer NOT NULL,
    aa50ondeusa_aa50id integer NOT NULL,
    aa50ondeusa_destino integer NOT NULL,
    aa50ondeusa_obs character(150)
);


ALTER TABLE public.aa50ondeusa OWNER TO postgres;

--
-- Name: aa50ondeusa_aa50ondeusa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50ondeusa_aa50ondeusa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50ondeusa_aa50ondeusa_id_seq OWNER TO postgres;

--
-- Name: aa50ondeusa_aa50ondeusa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50ondeusa_aa50ondeusa_id_seq OWNED BY public.aa50ondeusa.aa50ondeusa_id;


--
-- Name: aa50pratica_mercado; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50pratica_mercado (
    aa50pm_id integer NOT NULL,
    aa50pm_concorrente character(90),
    aa50pm_preco numeric(17,5),
    aa50pm_data date,
    aa50pm_observacao character(250),
    aa50pm_alteracao date,
    aa50pm_aa50id integer
);


ALTER TABLE public.aa50pratica_mercado OWNER TO postgres;

--
-- Name: aa50pratica_mercado_aa50pm_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50pratica_mercado_aa50pm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50pratica_mercado_aa50pm_id_seq OWNER TO postgres;

--
-- Name: aa50pratica_mercado_aa50pm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50pratica_mercado_aa50pm_id_seq OWNED BY public.aa50pratica_mercado.aa50pm_id;


--
-- Name: aa50preco; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50preco (
    aa50preco_id integer NOT NULL,
    aa50preco_aa50id integer NOT NULL,
    aa50preco_series_cor_id integer NOT NULL,
    aa50preco_tabela_preco_id integer NOT NULL,
    aa50preco_preco numeric(15,2),
    aa50preco_cor_id integer,
    aa50preco_observacao text,
    aa50preco_preco_anterior numeric(15,2),
    aa50preco_atualizado timestamp without time zone,
    aa50preco_user_alterou integer,
    aa50preco_perc_lucro numeric(15,2)
);


ALTER TABLE public.aa50preco OWNER TO postgres;

--
-- Name: aa50preco_aa50preco_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50preco_aa50preco_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50preco_aa50preco_id_seq OWNER TO postgres;

--
-- Name: aa50preco_aa50preco_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50preco_aa50preco_id_seq OWNED BY public.aa50preco.aa50preco_id;


--
-- Name: aa50subgrupo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50subgrupo (
    aa50subgrupo_nivel integer NOT NULL,
    aa50subgrupo_id integer NOT NULL,
    aa50subgrupo_codigo character(4) NOT NULL,
    aa50subgrupo_descricao character(50),
    aa50subgrupo_tipoproduto character(4),
    aa50subgrupo_grupo integer NOT NULL,
    aa50subgrupo_gramatura numeric(15,4) NOT NULL,
    aa50subgrupo_largura numeric(15,3),
    aa50subgrupo_espessura numeric(15,3),
    aa50subgrupo_grpencolhimento character(123) NOT NULL,
    aa50subgrupo_largura_cru numeric(15,3)
);


ALTER TABLE public.aa50subgrupo OWNER TO postgres;

--
-- Name: aa50subgrupo_aa50subgrupo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50subgrupo_aa50subgrupo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50subgrupo_aa50subgrupo_id_seq OWNER TO postgres;

--
-- Name: aa50subgrupo_aa50subgrupo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50subgrupo_aa50subgrupo_id_seq OWNED BY public.aa50subgrupo.aa50subgrupo_id;


--
-- Name: aa50variacao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa50variacao (
    aa50variacao_id integer NOT NULL,
    aa50variacao_variacao_id integer NOT NULL,
    aa50variacao_aa50id integer NOT NULL,
    aa50variacao_codigo character(3),
    aa50variacao_padrao boolean DEFAULT false,
    aa50variacao_inativar boolean DEFAULT false
);


ALTER TABLE public.aa50variacao OWNER TO postgres;

--
-- Name: aa50variacao_aa50variacao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa50variacao_aa50variacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa50variacao_aa50variacao_id_seq OWNER TO postgres;

--
-- Name: aa50variacao_aa50variacao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa50variacao_aa50variacao_id_seq OWNED BY public.aa50variacao.aa50variacao_id;


--
-- Name: aa80codigo_aa80codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80codigo_aa80codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80codigo_aa80codigo_seq OWNER TO postgres;

--
-- Name: aa80; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa80 (
    aa80id integer NOT NULL,
    aa80codigo character(10) DEFAULT lpad(((nextval('public.aa80codigo_aa80codigo_seq'::regclass))::character(10))::text, 10, '0'::text),
    aa80nome character(100),
    aa80endereco character(70),
    aa80numero character(10),
    aa80complem character(50),
    aa80ni character(18),
    aa80ie character(18),
    aa80email character(80),
    aa80na character(20),
    aa80cep character(10),
    aa80site character(50),
    aa80fone character(15),
    aa80sexo character(1),
    aa80ecivil character(1),
    aa80nasc date,
    aa80nat character(20),
    aa80orge character(16),
    aa80rgexped character(20),
    aa80cnae character(10),
    aa80suframa character(18),
    aa80ean character(15),
    aa80mae character(70),
    aa80pai character(70),
    aa80bairro character(50),
    aa80rgee character(2),
    aa80obs text,
    aa80pais integer,
    aa80municipio integer,
    aa80cliente character(1) DEFAULT 'N'::bpchar,
    aa80fornecedor character(1) DEFAULT 'N'::bpchar,
    aa80transportadora character(1) DEFAULT 'N'::bpchar,
    aa80representante character(1) DEFAULT 'N'::bpchar,
    aa80cepcp character(10),
    aa80cp integer,
    aa80rg character(18),
    aa80im character(18),
    aa80cei character(18),
    aa80empresa integer,
    aa80inativo boolean DEFAULT false NOT NULL,
    aa80fornecedor_primeira_compra date,
    aa80fornecedor_ultima_compra date,
    aa80fornecedor_compra_acumulada numeric(15,4),
    aa80fornecedor_prazo_pagamento numeric(15,4),
    aa80fornecedor_nota character(10),
    aa80fornecedor_data_maior_compra date,
    aa80fornecedor_valor numeric(15,2),
    aa80repres1 character(10),
    aa80repres1n character(60),
    aa80repres1comi numeric(6,2),
    aa80repres2 character(10),
    aa80repres2n character(60),
    aa80repres2comi numeric(6,2),
    aa80repres3 character(10),
    aa80repres3n character(60),
    aa80repres3comi numeric(6,2),
    aa80tipodetributacao integer DEFAULT 0,
    aa80tipodetributacaonome character(30),
    aa80repres1id integer,
    aa80repres2id integer,
    aa80repres3id integer,
    aa80despachoid integer,
    aa80despacho character(10),
    aa80despachon character(60),
    aa80despachoantt character(17),
    aa80despachoplaca character(7),
    aa80despachouf character(2),
    aa80redespachoid integer,
    aa80redespacho character(10),
    aa80redespachon character(60),
    aa80redespachoantt character(17),
    aa80redespachoplaca character(7),
    aa80redespachouf character(2),
    aa80frete integer DEFAULT 0,
    aa80condicaoid integer,
    aa80condicao character(4),
    aa80condicaon character(60),
    aa80observacaoadc text,
    aa80banco_codigo character(3),
    aa80banco_descricao character(60),
    aa80nota_dadosadicionais text,
    aa80outras character(1),
    aa80municionome character(80),
    aa80municiuf character(2),
    aa80_data_cadastro date,
    aa80_tit_pend character(3),
    aa80_valor_maior_parcela numeric(15,3),
    aa80_data_maior_parcela date,
    aa80_maior_atraso integer,
    aa80_atraso_medio integer,
    aa80_conceito_cliente character(3),
    aa80_valor_ultimo_pedido numeric(15,3),
    aa80_data_ultimo_pedido date,
    aa80_valor_maior_fatura numeric(15,3),
    aa80_data_maior_fatura date,
    aa80_valor_ultima_fatura numeric(15,3),
    aa80_data_ultima_fatura date,
    aa80_perc_encargos numeric(15,3),
    aa80_validade_limite_credito date,
    aa80_ultima_atualizacao_limite_credito date,
    aa80_valor_compras_mensal numeric(15,3),
    aa80perc_comissao numeric(6,2),
    aa80cliente_isento_ipi character(1),
    aa80contato character(50),
    aa80mailmarketing character(150),
    aa80_plc_id integer,
    aa80tipo_pessoa character(1),
    aa80valor_maximo_faturamento_pedido numeric(20,2),
    aa80_bloqueio boolean DEFAULT false,
    aa80nao_imprimir_nosso_logo boolean DEFAULT false,
    aa80email_financeiro character(200),
    aa80facebook character(400),
    aa80instagram character(400),
    aa80user_cadastrou integer,
    aa80user_alterou integer,
    aa80user_data_cadastro date,
    aa80user_hora_cadastro character(10),
    aa80user_data_alteracao date,
    aa80user_hora_alteracao character(10),
    aa80whatsapp character(20),
    aa80linkedin character(200),
    aa80limitecredito numeric(18,2),
    aa80email_acesso_web character(300),
    aa80cadweb character(1),
    aa80tipo_representante integer,
    aa80classificacao_cliente integer DEFAULT 1,
    aa80_status integer DEFAULT 1,
    aa80limite_por_desenho integer,
    aa80_autenticacao_fv character(6),
    aa80_autenticacao_horas character(10),
    aa80_autenticacao_hora time without time zone,
    aa80_autenticacao_data date,
    aa80grupoid integer,
    aa80_nao_contabiliza_financeiro boolean,
    aa80_contarcomojet boolean DEFAULT false,
    aa80logo text,
    aa80ref_terceiro integer,
    aa80limite_remonte integer
);


ALTER TABLE public.aa80 OWNER TO postgres;

--
-- Name: TABLE aa80; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.aa80 IS 'Entidade';


--
-- Name: aa80_aa80redespachoid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80_aa80redespachoid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80_aa80redespachoid_seq OWNER TO postgres;

--
-- Name: aa80_aa80redespachoid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa80_aa80redespachoid_seq OWNED BY public.aa80.aa80redespachoid;


--
-- Name: aa80_serasa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa80_serasa (
    id integer NOT NULL,
    entidade integer,
    observacao text,
    usuario integer,
    hora character(10),
    data date
);


ALTER TABLE public.aa80_serasa OWNER TO postgres;

--
-- Name: aa80_serasa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80_serasa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80_serasa_id_seq OWNER TO postgres;

--
-- Name: aa80_serasa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa80_serasa_id_seq OWNED BY public.aa80_serasa.id;


--
-- Name: aa80_telefones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa80_telefones (
    aa80tel_id integer NOT NULL,
    aa80tel_aa80id integer NOT NULL,
    aa80tel_idtipo smallint NOT NULL,
    aa80tel_ddd smallint NOT NULL,
    aa80tel_contato character varying(30),
    aa80tel_numero character varying(15) NOT NULL
);


ALTER TABLE public.aa80_telefones OWNER TO postgres;

--
-- Name: aa80_telefones_aa80tel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80_telefones_aa80tel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80_telefones_aa80tel_id_seq OWNER TO postgres;

--
-- Name: aa80_telefones_aa80tel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa80_telefones_aa80tel_id_seq OWNED BY public.aa80_telefones.aa80tel_id;


--
-- Name: aa80classificacao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80classificacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80classificacao_id_seq OWNER TO postgres;

--
-- Name: aa80classificacao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa80classificacao (
    id integer DEFAULT nextval('public.aa80classificacao_id_seq'::regclass) NOT NULL,
    descricao character(200)
);


ALTER TABLE public.aa80classificacao OWNER TO postgres;

--
-- Name: aa80endcobra; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa80endcobra (
    aa80endcobra_cep character(11),
    aa80endcobra_endereco character(50),
    aa80endcobra_numero character(6),
    aa80endcobra_complemento character(50),
    aa80endcobra_cxcodigo integer,
    aa80endcobra_cxcep character(10),
    aa80endcobra_bairro character(50),
    aa80endcobra_municipio integer,
    aa80endcobra_pais integer,
    aa80endcobra_contato character(100),
    aa80endcobra_tipo character(1),
    aa80endcobra_entidade integer,
    aa80endcobra_empresa integer,
    aa80endcobra_id integer NOT NULL
);


ALTER TABLE public.aa80endcobra OWNER TO postgres;

--
-- Name: aa80endcobra_aa80endcobra_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80endcobra_aa80endcobra_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80endcobra_aa80endcobra_id_seq OWNER TO postgres;

--
-- Name: aa80endcobra_aa80endcobra_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa80endcobra_aa80endcobra_id_seq OWNED BY public.aa80endcobra.aa80endcobra_id;


--
-- Name: aa80endentr; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa80endentr (
    aa80endentr_cep character(11),
    aa80endentr_endereco character(50),
    aa80endentr_numero character(6),
    aa80endentr_complemento character(50),
    aa80endentr_cxcodigo integer,
    aa80endentr_cxcep character(10),
    aa80endentr_bairro character(50),
    aa80endentr_municipio integer,
    aa80endentr_pais integer,
    aa80endentr_contato character(100),
    aa80endentr_tipo character(1),
    aa80endentr_entidade integer,
    aa80endentr_empresa integer,
    aa80endentr_id integer NOT NULL
);


ALTER TABLE public.aa80endentr OWNER TO postgres;

--
-- Name: aa80endentr_aa80endentr_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80endentr_aa80endentr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80endentr_aa80endentr_id_seq OWNER TO postgres;

--
-- Name: aa80endentr_aa80endentr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa80endentr_aa80endentr_id_seq OWNED BY public.aa80endentr.aa80endentr_id;


--
-- Name: aa80grupo_aa80g_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80grupo_aa80g_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80grupo_aa80g_id_seq OWNER TO postgres;

--
-- Name: aa80grupo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa80grupo (
    aa80g_id integer DEFAULT nextval('public.aa80grupo_aa80g_id_seq'::regclass) NOT NULL,
    aa80g_descricao character(300)
);


ALTER TABLE public.aa80grupo OWNER TO postgres;

--
-- Name: aa80inf; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa80inf (
    aa80inf_id integer NOT NULL,
    aa80inf_fontebancaria character(3),
    aa80inf_agencia character(5),
    aa80inf_digito character(2),
    aa80inf_tipo_conta character(3),
    aa80inf_conta_corrente character(12),
    aa80inf_ordem_pref_bancaria character(2),
    aa80inf_telefone character(14),
    aa80inf_contato character(100),
    aa80inf_correntistadesde date,
    aa80inf_limite_credito character(20),
    aa80inf_vencimento_emp date,
    aa80inf_ultimo_cheque_sem_fundo date,
    aa80inf_cheques_sem_fundo character(4),
    aa80inf_observacoes text,
    aa80inf_tipo character(1),
    aa80inf_entida integer,
    "aa80Inf_valor_emprestimo" numeric(15,3),
    aa80inf_digito_conta integer
);


ALTER TABLE public.aa80inf OWNER TO postgres;

--
-- Name: aa80inf_aa80inf_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80inf_aa80inf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80inf_aa80inf_id_seq OWNER TO postgres;

--
-- Name: aa80inf_aa80inf_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa80inf_aa80inf_id_seq OWNED BY public.aa80inf.aa80inf_id;


--
-- Name: aa80mk; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa80mk (
    aa80mk_confeccao boolean,
    aa80mk_atacado_confeccao boolean,
    aa80mk_varejo_confeccao boolean,
    aa80mk_atacado_tecidos boolean,
    aa80mk_varejo_tecidos boolean,
    aa80mk_outros boolean,
    aa80mk_outros_desc character(50),
    aa80mk_camiseta boolean,
    aa80mk_senhora boolean,
    aa80mk_calca boolean,
    aa80mk_tunica boolean,
    aa80mk_saias boolean,
    aa80mk_monstruario_diversificado boolean,
    aa80mk_espe_outros boolean,
    aa80mk_espec_outros_desc character(50),
    aa80mk_feminino boolean,
    aa80mk_masculino boolean,
    aa80mk_infantil boolean,
    aa80mk_bebe boolean,
    aa80mk_pub_outros boolean,
    aa80mk_publ_outros_desc character(50),
    aa80mk_sportswear boolean,
    aa80mk_casualwear boolean,
    aa80mk_streetwear boolean,
    aa80mk_activewear boolean,
    aa80mk_linha_intima boolean,
    aa80mk_moda_praia boolean,
    aa80mk_fashion boolean,
    aa80mk_segm_outros boolean,
    aa80mk_segm_outros_desc character(50),
    aa80mk_distribuicao_multimarcas boolean,
    aa80mk_distribuicao_lojas_proprias boolean,
    aa80mk_distribuicao_franquias boolean,
    aa80mk_atacado_conf_propria boolean,
    aa80mk_atacado_conf_multimarcas boolean,
    aa80mk_terceriza boolean,
    aa80mk_forma_outros boolean,
    aa80mk_forma_outros_desc character(50),
    aa80mk_tecidos_estampado boolean,
    aa80mk_tecidos_lisos boolean,
    aa80mk_desenv_estampas boolean,
    aa80mk_desenv_tecidos_dife boolean,
    aa80mk_prod_comp_outros boolean,
    aa80mk_prod_comp_outros_desc character(50),
    aa80mk_viagens boolean,
    aa80mk_revistas_intenacionais boolean,
    aa80mk_video_internacionais boolean,
    aa80mk_bureau_internacionais boolean,
    aa80mk_pesq_cole_outros boolean,
    aa80mk_pesq_colec_outros_desc character(50),
    aa80mk_vera_ver_tecidos character(2),
    aa80mk_vera_lanc_cole character(2),
    "aa80mk_inve_verTeci" character(2),
    aa80mk_inv_lanca_colecao character(2),
    aa80mk_ultima_atua date,
    aa80mk_vip character(50),
    aa80mk_id integer NOT NULL,
    aa80mk_entidade integer,
    aa80mk_tipo character(1)
);


ALTER TABLE public.aa80mk OWNER TO postgres;

--
-- Name: aa80mk_aa80mk_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80mk_aa80mk_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80mk_aa80mk_id_seq OWNER TO postgres;

--
-- Name: aa80mk_aa80mk_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aa80mk_aa80mk_id_seq OWNED BY public.aa80mk.aa80mk_id;


--
-- Name: aa80tipo_fornecedor_aa80tpf_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aa80tipo_fornecedor_aa80tpf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aa80tipo_fornecedor_aa80tpf_id_seq OWNER TO postgres;

--
-- Name: aa80tipo_fornecedor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aa80tipo_fornecedor (
    aa80tpf_id integer DEFAULT nextval('public.aa80tipo_fornecedor_aa80tpf_id_seq'::regclass) NOT NULL,
    aa80tpf_tpf_id integer,
    aa80tpf_aa80id integer
);


ALTER TABLE public.aa80tipo_fornecedor OWNER TO postgres;

--
-- Name: ab15_ab15codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab15_ab15codigo_seq
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab15_ab15codigo_seq OWNER TO postgres;

--
-- Name: ab15; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ab15 (
    ab15codigo character varying(5) DEFAULT lpad(((nextval('public.ab15_ab15codigo_seq'::regclass))::character(5))::text, 5, '0'::text) NOT NULL,
    ab15nome character varying(100),
    ab15serie character varying(4),
    ab15tipo smallint,
    ab15codsci character varying(1),
    ab15liquidez smallint,
    ab15di date,
    ab15modelo character varying(2),
    ab15faturaidm character varying(100),
    ab15rotuloidm character varying(100),
    ab15na character varying(6),
    ab15enthomon smallint,
    ab15docidm character varying(100),
    ab15desconto integer DEFAULT 0,
    ab15id integer NOT NULL,
    ab15tipodocumento integer,
    ab15documento integer
);


ALTER TABLE public.ab15 OWNER TO postgres;

--
-- Name: TABLE ab15; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.ab15 IS 'Tipo de Documento
';


--
-- Name: ab15_ab15id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab15_ab15id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab15_ab15id_seq OWNER TO postgres;

--
-- Name: ab15_ab15id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ab15_ab15id_seq OWNED BY public.ab15.ab15id;


--
-- Name: ab20; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ab20 (
    ab20id bigint NOT NULL,
    ab20versao integer NOT NULL,
    ab20empresa bigint NOT NULL,
    ab20codigo character varying(7) NOT NULL,
    ab20nome character varying(30),
    ab20obs character varying(100),
    ab20di date,
    ab20du character varying(19) NOT NULL,
    ab20nv smallint NOT NULL,
    ab20ccsup bigint,
    ab20sco smallint NOT NULL,
    ab20tipo smallint NOT NULL
);


ALTER TABLE public.ab20 OWNER TO postgres;

--
-- Name: ab31_ab31codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab31_ab31codigo_seq
    START WITH 250
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab31_ab31codigo_seq OWNER TO postgres;

--
-- Name: ab31; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ab31 (
    ab31versao integer,
    ab31empresa bigint,
    ab31codigo character varying(5) DEFAULT lpad(((nextval('public.ab31_ab31codigo_seq'::regclass))::character(5))::text, 5, '0'::text) NOT NULL,
    ab31nome character varying(300),
    ab31database smallint,
    ab31diasdatabase1 smallint,
    ab31diasdatabase2 smallint,
    ab31diasdatabase3 smallint,
    ab31diasdatabase4 smallint,
    ab31diasdatabase5 smallint,
    ab31diasdatabase6 smallint,
    ab31diasdatabase7 smallint,
    ab31diasvctonom1 smallint,
    ab31diasvctonom2 smallint,
    ab31diasvctonom3 smallint,
    ab31diasvctonom4 smallint,
    ab31diasvctonom5 smallint,
    ab31diasvctonom6 smallint,
    ab31diasvctonom7 smallint,
    ab31diasvctoreal1 smallint,
    ab31diasvctoreal2 smallint,
    ab31diasvctoreal3 smallint,
    ab31diasvctoreal4 smallint,
    ab31diasvctoreal5 smallint,
    ab31diasvctoreal6 smallint,
    ab31diasvctoreal7 smallint,
    ab31di date,
    ab31du character varying(19),
    ab31nv smallint,
    ab31txencfin numeric(5,2) DEFAULT 0.00 NOT NULL,
    ab31calcencfin smallint DEFAULT 0 NOT NULL,
    ab31txjuros numeric(5,2) DEFAULT 0.00 NOT NULL,
    ab31txmulta numeric(5,2) DEFAULT 0.00 NOT NULL,
    ab31parcmin numeric(16,2) DEFAULT 0.00,
    ab31databaseprev smallint DEFAULT 0 NOT NULL,
    ab31descdias smallint DEFAULT 0 NOT NULL,
    ab31desctxcond numeric(5,2) DEFAULT 0 NOT NULL,
    ab31descdtbase smallint DEFAULT 0 NOT NULL,
    ab31id integer NOT NULL,
    ab31nomeinterno character(600),
    prazo_avista integer
);


ALTER TABLE public.ab31 OWNER TO postgres;

--
-- Name: TABLE ab31; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.ab31 IS 'Condicoes de Pagamentos
';


--
-- Name: ab311; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ab311 (
    ab311versao integer,
    ab311cond integer NOT NULL,
    ab311dias integer NOT NULL,
    ab311percentual numeric(9,6),
    ab311diavcto smallint,
    ab311vctoimpr character varying(15),
    ab311docfinanc smallint,
    ab311ref integer,
    ab311vencfixo date,
    ab311id integer NOT NULL
);


ALTER TABLE public.ab311 OWNER TO postgres;

--
-- Name: ab311_ab311id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab311_ab311id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab311_ab311id_seq OWNER TO postgres;

--
-- Name: ab311_ab311id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ab311_ab311id_seq OWNED BY public.ab311.ab311id;


--
-- Name: ab31_ab31id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab31_ab31id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab31_ab31id_seq OWNER TO postgres;

--
-- Name: ab31_ab31id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ab31_ab31id_seq OWNED BY public.ab31.ab31id;


--
-- Name: ab59_ab59codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab59_ab59codigo_seq
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab59_ab59codigo_seq OWNER TO postgres;

--
-- Name: ab59; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ab59 (
    ab59codigo character varying(3) DEFAULT lpad(((nextval('public.ab59_ab59codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    ab59du character varying(19),
    ab59nv integer,
    ab59requercc integer,
    ab59empresa integer,
    ab59mov integer,
    ab59tipo integer,
    ab59descr character varying(30),
    ab59versao integer,
    ab59di date,
    ab59requerent integer,
    ab59fcd integer,
    ab59prereserva integer,
    ab59saldodoc integer,
    ab59lctprinc integer,
    ab59requerdoc integer,
    ab59retorno integer,
    ab59prodcred integer,
    ab59prodfixacred integer,
    ab59matfixadeb integer,
    ab59mathp integer,
    ab59prodhp integer,
    ab59proddeb integer,
    ab59matdeb integer,
    ab59prodfixadeb integer,
    ab59matcred integer,
    ab59matfixacred integer,
    ab59scq integer,
    ab59prcmedio integer,
    ab59atuaestoq integer,
    ab59id integer NOT NULL
);


ALTER TABLE public.ab59 OWNER TO postgres;

--
-- Name: ab59_ab59id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab59_ab59id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab59_ab59id_seq OWNER TO postgres;

--
-- Name: ab59_ab59id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ab59_ab59id_seq OWNED BY public.ab59.ab59id;


--
-- Name: ab83_ab83id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab83_ab83id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab83_ab83id_seq OWNER TO postgres;

--
-- Name: ab83; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ab83 (
    ab83fone2 character varying(8),
    ab83fone1 character varying(8),
    ab83endereco character varying(60),
    ab83pais bigint,
    ab83deficiente bigint,
    ab83email character varying(50),
    ab83mae character varying(70),
    ab83pai character varying(70),
    ab83codigo character varying(10),
    ab83cp integer,
    ab83codaux character varying(15),
    ab83nasc date,
    ab83nat character varying(20),
    ab83dtcheg date,
    ab83complem character varying(30),
    ab83municipio bigint,
    ab83empresa bigint,
    ab83nac bigint,
    ab83bairro character varying(30),
    ab83numero integer,
    ab83nome character varying(70),
    ab83ddd2 character varying(2),
    ab83ddd1 character varying(2),
    ab83racacor bigint,
    ab83cep bigint,
    ab83versao integer,
    ab83gi bigint,
    ab83rgee character varying(2),
    ab83rgexped date,
    ab83rgoe character varying(10),
    ab83ecivil smallint,
    ab83cpf character varying(18),
    ab83rg character varying(18),
    ab83sexo smallint,
    ab83cnhcat character varying(6),
    ab83tezona character varying(5),
    ab83ctpsdtemis date,
    ab83ctpsnum character varying(8),
    ab83crnr character varying(20),
    ab83cnh character varying(18),
    ab83crsigla character varying(30),
    ab83nit character varying(18),
    ab83evalidctps date,
    ab83evaliv date,
    ab83tenum character varying(18),
    ab83ctpsee character varying(2),
    ab83tipo smallint,
    ab83crrr character varying(20),
    ab83evisto character varying(20),
    ab83habprof character varying(30),
    ab83sit smallint,
    ab83crnome character varying(30),
    ab83cnhdtvcto date,
    ab83ctpsserie character varying(5),
    ab83tesecao character varying(5),
    ab83dtnit date,
    ab83salfv smallint,
    ab83dtapos date,
    ab83sindsindical bigint,
    ab83cs smallint,
    ab83vt0 smallint,
    ab83vt2 smallint,
    ab83vt1 smallint,
    ab83vt4 smallint,
    ab83vt3 smallint,
    ab83ci smallint,
    ab83cc bigint,
    ab83txconf numeric(5,2),
    ab83dvt smallint,
    ab83dttmpserv date,
    ab83dttransf date,
    ab83salvlr numeric(16,2),
    ab83cargo bigint,
    ab83admiscaged bigint,
    ab83saltipo smallint,
    ab83hs smallint,
    ab83tmpserv bigint,
    ab83dtadmis date,
    ab83tsind smallint,
    ab83dthomol date,
    ab83aplichor smallint,
    ab83dtpgres date,
    ab83hc character varying(50),
    ab83divhe bigint,
    ab83saque character varying(2),
    ab83causa bigint,
    ab83dtres date,
    ab83homol character varying(20),
    ab83tabhor bigint,
    ab83revez character varying(25),
    ab83nv smallint,
    ab83foto character varying(100),
    ab83hd character varying(50),
    ab83txempr numeric(5,2),
    ab83categ bigint,
    ab83pat smallint,
    ab83admisrais bigint,
    ab83digcta character varying(2),
    ab83contafgts character varying(11),
    ab83vincemp bigint,
    ab83txsat numeric(5,2),
    ab83txauton numeric(5,2),
    ab83txfrete numeric(5,2),
    ab83alvara smallint,
    ab83ut character varying(15),
    ab83cipa character varying(20),
    ab83txfgts numeric(5,2),
    ab83dtexmedico date,
    ab83aprendiz smallint,
    ab83du character varying(19),
    ab83dtic date,
    ab83obscad text,
    ab83tsrais bigint,
    ab83txterc numeric(5,2),
    ab83contribinss smallint,
    ab83conta character varying(15),
    ab83obstrab text,
    ab83oco bigint,
    ab83dtfc date,
    ab83sdofgts numeric(16,2),
    ab83msg1 text,
    ab83msg0 text,
    ab83sca smallint,
    ab83str0 character varying(50),
    ab83str4 character varying(50),
    ab83str3 character varying(50),
    ab83str2 character varying(50),
    ab83str1 character varying(50),
    ab83data2 date,
    ab83data3 date,
    ab83data4 date,
    ab83data0 date,
    ab83data1 date,
    ab83vlr10 numeric(18,6),
    ab83vlr13 numeric(18,6),
    ab83vlr14 numeric(18,6),
    ab83vlr11 numeric(18,6),
    ab83vlr8 numeric(18,6),
    ab83vlr12 numeric(18,6),
    ab83vlr9 numeric(18,6),
    ab83vlr2 numeric(18,6),
    ab83vlr3 numeric(18,6),
    ab83vlr0 numeric(18,6),
    ab83vlr1 numeric(18,6),
    ab83vlr6 numeric(18,6),
    ab83vlr7 numeric(18,6),
    ab83vlr4 numeric(18,6),
    ab83vlr5 numeric(18,6),
    ab83pafgts numeric(5,2),
    ab83pares numeric(5,2),
    ab83tpcontrato bigint,
    ab83sindass2 bigint,
    ab83sindass1 bigint,
    ab83sindassist bigint,
    ab83sindconfed bigint,
    ab83cr bigint,
    ab83dtmolestia date,
    ab83banco bigint,
    ab83cargo_codigo character(5),
    ab83cargo_nome character(100),
    ab83_centrocusto character(10),
    ab83id integer DEFAULT nextval('public.ab83_ab83id_seq'::regclass) NOT NULL,
    ab83cargo_id integer,
    ab83codigo_integracao character(20),
    ab83salario numeric(18,2),
    ab83salario2 numeric(18,2),
    ab83vale_transporte numeric(18,2),
    ab83imagem_funcionario text,
    ab83apelido character(200),
    ab83imagem bytea,
    ab83conjuge character varying(100),
    ab83banco_deposito character varying(3),
    ab83banco_nome character varying(80),
    ab83banco_conta character varying(40),
    ab83banco_agencia character varying(40),
    ab83chave_pix character varying(400),
    ab83tipochave_pix integer,
    ab83_apontamentos boolean DEFAULT true
);


ALTER TABLE public.ab83 OWNER TO postgres;

--
-- Name: ab83_ab83codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab83_ab83codigo_seq
    START WITH 2031
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab83_ab83codigo_seq OWNER TO postgres;

--
-- Name: ab98_ab98codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab98_ab98codigo_seq
    START WITH 43
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab98_ab98codigo_seq OWNER TO postgres;

--
-- Name: ab98; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ab98 (
    ab98versao integer NOT NULL,
    ab98empresa bigint NOT NULL,
    ab98codigo character varying(5) DEFAULT lpad(((nextval('public.ab98_ab98codigo_seq'::regclass))::character(5))::text, 5, '0'::text) NOT NULL,
    ab98nome character varying(50),
    ab98superior bigint,
    ab98cbo bigint,
    ab98fixo smallint NOT NULL,
    ab98funcao text,
    ab98salario numeric(16,2) NOT NULL,
    ab98perfil text,
    ab98tarefa text,
    ab98du character varying(19) NOT NULL,
    ab98nv smallint NOT NULL,
    ab98superior_codigo character(5),
    ab98id integer NOT NULL
);


ALTER TABLE public.ab98 OWNER TO postgres;

--
-- Name: ab98_ab98id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ab98_ab98id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ab98_ab98id_seq OWNER TO postgres;

--
-- Name: ab98_ab98id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ab98_ab98id_seq OWNED BY public.ab98.ab98id;


--
-- Name: acabamento_acabamento_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.acabamento_acabamento_codigo_seq
    START WITH 5
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.acabamento_acabamento_codigo_seq OWNER TO postgres;

--
-- Name: acabamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.acabamento (
    acabamento_id integer NOT NULL,
    acabamento_descricao character(50) NOT NULL,
    acabamento_codigo character(3) DEFAULT lpad(((nextval('public.acabamento_acabamento_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    acabamento_selecionada character(1)
);


ALTER TABLE public.acabamento OWNER TO postgres;

--
-- Name: TABLE acabamento; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.acabamento IS 'Tipo do Acabamento de Tecido (TINTURARIA).';


--
-- Name: acabamento_acabamento_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.acabamento_acabamento_id_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.acabamento_acabamento_id_seq OWNER TO postgres;

--
-- Name: acabamento_acabamento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.acabamento_acabamento_id_seq OWNED BY public.acabamento.acabamento_id;


--
-- Name: acoes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.acoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.acoes_id_seq OWNER TO postgres;

--
-- Name: acoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.acoes (
    id integer DEFAULT nextval('public.acoes_id_seq'::regclass) NOT NULL,
    indice integer,
    descricao character(90)
);


ALTER TABLE public.acoes OWNER TO postgres;

--
-- Name: ambientes_amb_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ambientes_amb_id_seq
    START WITH 76
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ambientes_amb_id_seq OWNER TO postgres;

--
-- Name: ambientes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ambientes (
    amb_id integer DEFAULT nextval('public.ambientes_amb_id_seq'::regclass) NOT NULL,
    amb_descricao character(200)
);


ALTER TABLE public.ambientes OWNER TO postgres;

--
-- Name: amostra; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.amostra (
    amostra_id integer NOT NULL,
    amostra_imagem bytea,
    amostra_solicitacao_id integer NOT NULL,
    amostra_solicitacao character(10) NOT NULL,
    amostra_produto_id integer,
    amostra_tipo character(30) NOT NULL,
    amostra_quantidade numeric(15,4) NOT NULL,
    amostra_tipo_codigo integer,
    amostra_letras integer,
    amostra_imagem_endereco character(200)
);


ALTER TABLE public.amostra OWNER TO postgres;

--
-- Name: amostra_amostra_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.amostra_amostra_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.amostra_amostra_id_seq OWNER TO postgres;

--
-- Name: amostra_amostra_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.amostra_amostra_id_seq OWNED BY public.amostra.amostra_id;


--
-- Name: aparencias_aparencias_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aparencias_aparencias_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aparencias_aparencias_codigo_seq OWNER TO postgres;

--
-- Name: aparencias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aparencias (
    aparencias_id integer NOT NULL,
    aparencias_descricao character(50) NOT NULL,
    aparencias_codigo character(3) DEFAULT lpad(((nextval('public.aparencias_aparencias_codigo_seq'::regclass))::character(3))::text, 3, '0'::text)
);


ALTER TABLE public.aparencias OWNER TO postgres;

--
-- Name: aparencias_aparencias_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aparencias_aparencias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aparencias_aparencias_id_seq OWNER TO postgres;

--
-- Name: aparencias_aparencias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aparencias_aparencias_id_seq OWNED BY public.aparencias.aparencias_id;


--
-- Name: areas_producao_areas_producao_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.areas_producao_areas_producao_codigo_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.areas_producao_areas_producao_codigo_seq OWNER TO postgres;

--
-- Name: areas_producao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.areas_producao (
    areas_producao_id integer NOT NULL,
    areas_producao_descricao character(80) NOT NULL,
    areas_producao_codigo character(3) DEFAULT lpad(((nextval('public.areas_producao_areas_producao_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    areas_producao_estagio character(3),
    areas_producao_custo character(7),
    areas_producao_lote numeric(15,3)
);


ALTER TABLE public.areas_producao OWNER TO postgres;

--
-- Name: areas_producao_areas_producao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.areas_producao_areas_producao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.areas_producao_areas_producao_id_seq OWNER TO postgres;

--
-- Name: areas_producao_areas_producao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.areas_producao_areas_producao_id_seq OWNED BY public.areas_producao.areas_producao_id;


--
-- Name: arquivo_retorno; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.arquivo_retorno (
    id integer NOT NULL,
    data date,
    hora character(10),
    nome_arquivo character(1),
    user_id integer,
    recebido boolean DEFAULT false,
    banco integer
);


ALTER TABLE public.arquivo_retorno OWNER TO postgres;

--
-- Name: arquivo_retorno_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.arquivo_retorno_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.arquivo_retorno_id_seq OWNER TO postgres;

--
-- Name: arquivo_retorno_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.arquivo_retorno_id_seq OWNED BY public.arquivo_retorno.id;


--
-- Name: arquivo_retorno_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.arquivo_retorno_item (
    id integer NOT NULL,
    retorno_id integer,
    tipo character(2),
    documento_id integer,
    valor numeric(18,2),
    juros numeric(18,2),
    desconto numeric(18,2),
    valor_df10 numeric(18,2),
    recebido boolean DEFAULT false
);


ALTER TABLE public.arquivo_retorno_item OWNER TO postgres;

--
-- Name: arquivo_retorno_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.arquivo_retorno_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.arquivo_retorno_item_id_seq OWNER TO postgres;

--
-- Name: arquivo_retorno_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.arquivo_retorno_item_id_seq OWNED BY public.arquivo_retorno_item.id;


--
-- Name: artigosprodutos_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.artigosprodutos_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.artigosprodutos_codigo_seq OWNER TO postgres;

--
-- Name: artigosprodutos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.artigosprodutos (
    artigosprodutos_codigo character(4) DEFAULT lpad(((nextval('public.artigosprodutos_codigo_seq'::regclass))::character(4))::text, 4, '0'::text) NOT NULL,
    artigosprodutos_id integer NOT NULL,
    artigosprodutos_descricao character(50) NOT NULL,
    artigosprodutos_2 boolean,
    artigosprodutos_3 boolean,
    artigosprodutos_4 boolean,
    artigosprodutos_5 boolean,
    artigosprodutos_6 boolean,
    artigosprodutos_7 boolean,
    artigosprodutos_8 boolean,
    artigosprodutos_9 boolean,
    artigosprodutos_1 boolean
);


ALTER TABLE public.artigosprodutos OWNER TO postgres;

--
-- Name: artigosprodutos_artigosprodutos_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.artigosprodutos_artigosprodutos_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.artigosprodutos_artigosprodutos_codigo_seq OWNER TO postgres;

--
-- Name: artigosprodutos_artigosprodutos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.artigosprodutos_artigosprodutos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.artigosprodutos_artigosprodutos_id_seq OWNER TO postgres;

--
-- Name: artigosprodutos_artigosprodutos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.artigosprodutos_artigosprodutos_id_seq OWNED BY public.artigosprodutos.artigosprodutos_id;


--
-- Name: atividades_padrao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.atividades_padrao (
    ap_id integer NOT NULL,
    ap_tipo character(1),
    ap_descricao character(120)
);


ALTER TABLE public.atividades_padrao OWNER TO postgres;

--
-- Name: atividades_padrao_ap_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.atividades_padrao_ap_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.atividades_padrao_ap_id_seq OWNER TO postgres;

--
-- Name: atividades_padrao_ap_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.atividades_padrao_ap_id_seq OWNED BY public.atividades_padrao.ap_id;


--
-- Name: atividades_padrao_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.atividades_padrao_item (
    api_id integer NOT NULL,
    api_ap integer,
    api_atividades integer,
    api_ordem integer,
    api_prazos integer
);


ALTER TABLE public.atividades_padrao_item OWNER TO postgres;

--
-- Name: atividades_padrao_item_api_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.atividades_padrao_item_api_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.atividades_padrao_item_api_id_seq OWNER TO postgres;

--
-- Name: atividades_padrao_item_api_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.atividades_padrao_item_api_id_seq OWNED BY public.atividades_padrao_item.api_id;


--
-- Name: atv; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.atv (
    atv_id integer NOT NULL,
    atv_operacao_id integer,
    atv_dias integer,
    atv_sdc integer,
    atv_apontamento character(1),
    atv_dias_acumulados integer,
    atv_hfim time without time zone,
    atv_hini time without time zone,
    atv_observacao character(300),
    atv_dfim date,
    atv_dini date,
    atv_funcionario integer,
    atv_ob_id integer,
    atv_entidade integer,
    atv_desenho integer,
    atv_dias_original integer,
    atv_dias_acumulados_original integer,
    atv_previsao_entrega date,
    atv_produto integer,
    atv_representante integer,
    atv_qtde_placas numeric(18,2),
    atv_estampas_id integer,
    sdc_item_cor_id integer
);


ALTER TABLE public.atv OWNER TO postgres;

--
-- Name: atv_atv_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.atv_atv_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.atv_atv_id_seq OWNER TO postgres;

--
-- Name: atv_atv_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.atv_atv_id_seq OWNED BY public.atv.atv_id;


--
-- Name: balanca; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.balanca (
    bal_codigo integer NOT NULL,
    bal_descricao character(50),
    bal_baudrate integer,
    bal_parity integer,
    bal_stopbit integer,
    bal_databits integer,
    bal_porta character(5),
    bal_protocolo integer
);


ALTER TABLE public.balanca OWNER TO postgres;

--
-- Name: balanca_bal_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.balanca_bal_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.balanca_bal_codigo_seq OWNER TO postgres;

--
-- Name: balanca_bal_codigo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.balanca_bal_codigo_seq OWNED BY public.balanca.bal_codigo;


--
-- Name: bancos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bancos (
    bco_id integer NOT NULL,
    bco_codigo character(3),
    bco_nome character(60),
    bco_endereco character(80),
    bco_cidade character(40),
    bco_cep character(10),
    bco_classificacao integer DEFAULT 0,
    bco_codigo_integracao character(10),
    bco_agencia character(25),
    bco_banco character(3),
    bco_conta character(25),
    bco_digito character(10),
    bco_agencia_digito character(10),
    bco_carteira character(3),
    bco_acessorio_escritural character(25),
    bco_instrucao01 character(2),
    bco_instrucao02 character(2),
    bco_mensagem_local_pagamento character(200),
    bco_prioridade integer DEFAULT 1,
    bco_inativar boolean DEFAULT false,
    bco_tipo_cobranca integer DEFAULT 0,
    bco_envia_email_automatico boolean,
    bco_envia_anexo_automatico boolean DEFAULT true,
    bco_habilita_movimentacao boolean DEFAULT false,
    bco_limite numeric(18,2),
    bco_habilita_boleto boolean DEFAULT false
);


ALTER TABLE public.bancos OWNER TO postgres;

--
-- Name: bancos_bco_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bancos_bco_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bancos_bco_id_seq OWNER TO postgres;

--
-- Name: bancos_bco_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bancos_bco_id_seq OWNED BY public.bancos.bco_id;


--
-- Name: bancos_brasil_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bancos_brasil_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bancos_brasil_id_seq OWNER TO postgres;

--
-- Name: bancos_brasil; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bancos_brasil (
    id integer DEFAULT nextval('public.bancos_brasil_id_seq'::regclass) NOT NULL,
    codigo integer,
    nome character(200)
);


ALTER TABLE public.bancos_brasil OWNER TO postgres;

--
-- Name: bd_fixo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bd_fixo (
    id integer NOT NULL,
    descricao character(200),
    data date,
    entidade_id integer,
    user_id integer,
    obs_livre character(100),
    obs_sistema character(100),
    banco_id integer
);


ALTER TABLE public.bd_fixo OWNER TO postgres;

--
-- Name: bd_fixo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bd_fixo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bd_fixo_id_seq OWNER TO postgres;

--
-- Name: bd_fixo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bd_fixo_id_seq OWNED BY public.bd_fixo.id;


--
-- Name: bd_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bd_item (
    id integer NOT NULL,
    id_bordero integer,
    df10id integer,
    user_id integer,
    obs_sistema character(100)
);


ALTER TABLE public.bd_item OWNER TO postgres;

--
-- Name: bd_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bd_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bd_item_id_seq OWNER TO postgres;

--
-- Name: bd_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bd_item_id_seq OWNED BY public.bd_item.id;


--
-- Name: bloco_fixo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bloco_fixo (
    blf_id integer NOT NULL,
    blf_user integer,
    blf_data_hora character(150),
    blf_data_ini date,
    blf_data_fim date
);


ALTER TABLE public.bloco_fixo OWNER TO postgres;

--
-- Name: bloco_fixo_blf_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bloco_fixo_blf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bloco_fixo_blf_id_seq OWNER TO postgres;

--
-- Name: bloco_fixo_blf_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bloco_fixo_blf_id_seq OWNED BY public.bloco_fixo.blf_id;


--
-- Name: bloco_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bloco_item (
    bli_id integer NOT NULL,
    bli_id_bloco integer,
    bli_campo character(800),
    bli_bloco character(12),
    bli_produto_id integer,
    bli_estampa_id integer,
    bli_unitario numeric(18,2),
    bli_qtde numeric(18,2),
    bli_posse integer,
    bli_participante integer,
    bli_user integer,
    bli_data character(20),
    bli_aa50nivel integer,
    bli_classificacao_blocok character(2),
    bli_produto_descricao character(200),
    bli_item_descricao character(200),
    bli_ncm character(20),
    bli_cest character(20),
    bli_campos character(800)
);


ALTER TABLE public.bloco_item OWNER TO postgres;

--
-- Name: bloco_item_bli_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bloco_item_bli_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bloco_item_bli_id_seq OWNER TO postgres;

--
-- Name: bloco_item_bli_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bloco_item_bli_id_seq OWNED BY public.bloco_item.bli_id;


--
-- Name: bloqueios_pedidos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bloqueios_pedidos (
    bloq_id integer NOT NULL,
    bloq_descricao character(100),
    bloq_ativo "char",
    bloq_nivel integer,
    bloq_grupo integer,
    bloq_valor numeric(16,2)
);


ALTER TABLE public.bloqueios_pedidos OWNER TO postgres;

--
-- Name: bloqueios_pedidos_bloq_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bloqueios_pedidos_bloq_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bloqueios_pedidos_bloq_id_seq OWNER TO postgres;

--
-- Name: bloqueios_pedidos_bloq_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bloqueios_pedidos_bloq_id_seq OWNED BY public.bloqueios_pedidos.bloq_id;


--
-- Name: bolinhas_dash_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bolinhas_dash_id_seq
    START WITH 23
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bolinhas_dash_id_seq OWNER TO postgres;

--
-- Name: bolinhas_dash; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bolinhas_dash (
    id integer DEFAULT nextval('public.bolinhas_dash_id_seq'::regclass) NOT NULL,
    descricao character(100),
    cor_bolinha character(20),
    cor_texto character(20),
    funcao character(200),
    indice integer,
    idbolinha character(50),
    habilita boolean DEFAULT true
);


ALTER TABLE public.bolinhas_dash OWNER TO postgres;

--
-- Name: bordero_cheque; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bordero_cheque (
    bc_id integer NOT NULL,
    bc_data date,
    bc_descricao character(200),
    bc_user_id integer,
    bc_valor numeric(18,2),
    bc_tipo integer,
    bc_entidade_id integer,
    bc_cheque_dinheiro integer,
    bc_df10id integer,
    bc_obs_sistema character(100),
    bc_transferencia character(1)
);


ALTER TABLE public.bordero_cheque OWNER TO postgres;

--
-- Name: bordero_cheque_bc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bordero_cheque_bc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bordero_cheque_bc_id_seq OWNER TO postgres;

--
-- Name: bordero_cheque_bc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bordero_cheque_bc_id_seq OWNED BY public.bordero_cheque.bc_id;


--
-- Name: bordero_mvto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bordero_mvto (
    bmv_id integer NOT NULL,
    bmv_bordero character(6),
    bmv_data date,
    bmv_taxa_id integer,
    bmv_taxa_codigo character(3),
    bmv_taxa_nome character(60),
    bmv_percentual numeric(5,2),
    bmv_valor numeric(15,2),
    bmv_bordero_id integer,
    bmv_documento_df10id integer
);


ALTER TABLE public.bordero_mvto OWNER TO postgres;

--
-- Name: bordero_mvto_bmv_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bordero_mvto_bmv_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bordero_mvto_bmv_id_seq OWNER TO postgres;

--
-- Name: bordero_mvto_bmv_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bordero_mvto_bmv_id_seq OWNED BY public.bordero_mvto.bmv_id;


--
-- Name: caixas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.caixas (
    cai_id integer NOT NULL,
    cai_sequecial integer,
    cai_of_id integer NOT NULL,
    cai_qtde_cone integer,
    cai_peso_bruto numeric(7,2),
    cai_peso_liquido numeric(7,2),
    cai_data date,
    cai_status integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.caixas OWNER TO postgres;

--
-- Name: caixas_cai_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.caixas_cai_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.caixas_cai_id_seq OWNER TO postgres;

--
-- Name: caixas_cai_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.caixas_cai_id_seq OWNED BY public.caixas.cai_id;


--
-- Name: caixas_historico; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.caixas_historico (
    hc_id integer NOT NULL,
    hc_caixa_id integer NOT NULL,
    hc_pesador integer,
    hc_motivo_id integer,
    hc_justificativa text,
    hc_data_caixa date,
    hc_data_acao date,
    hc_hora_acao time without time zone,
    hc_acao integer,
    hc_of integer,
    hc_peso_bruto numeric(10,2),
    hc_peso_liquido numeric(10,2)
);


ALTER TABLE public.caixas_historico OWNER TO postgres;

--
-- Name: caixas_historico_hc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.caixas_historico_hc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.caixas_historico_hc_id_seq OWNER TO postgres;

--
-- Name: caixas_historico_hc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.caixas_historico_hc_id_seq OWNED BY public.caixas_historico.hc_id;


--
-- Name: campanhas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.campanhas_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.campanhas_id_seq OWNER TO postgres;

--
-- Name: campanhas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.campanhas (
    id integer DEFAULT nextval('public.campanhas_id_seq'::regclass) NOT NULL,
    descricao character(150),
    usuario integer,
    inicio date,
    fim date,
    criacao date,
    idbolinha character(50),
    cor_bolinha text,
    cor_texto text
);


ALTER TABLE public.campanhas OWNER TO postgres;

--
-- Name: carrinho; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.carrinho (
    id integer NOT NULL,
    cliente integer,
    representante integer,
    iddesenho integer,
    quantidade numeric(12,3),
    preco numeric(18,2),
    tipopedido character(40),
    obs character(200),
    bases character(1000)
);


ALTER TABLE public.carrinho OWNER TO postgres;

--
-- Name: cbenef_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cbenef_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbenef_id_seq OWNER TO postgres;

--
-- Name: cbenef; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cbenef (
    id integer DEFAULT nextval('public.cbenef_id_seq'::regclass) NOT NULL,
    aplica character varying(3),
    cbenef character varying(10),
    cst00 character varying(3),
    cst02 character varying(3),
    cst10 character varying(3),
    cst15 character varying(3),
    cst20 character varying(3),
    cst30 character varying(3),
    cst40 character varying(3),
    cst41 character varying(3),
    cst50 character varying(3),
    cst51 character varying(3),
    cst53 character varying(3),
    cst60 character varying(3),
    cst61 character varying(3),
    cst70 character varying(3),
    cst90 character varying(3),
    simples_nacional character varying(1),
    dispositivo character varying(1000),
    objeto_descricao character varying(5000),
    observacao character varying(5000),
    ativo character varying(1)
);


ALTER TABLE public.cbenef OWNER TO postgres;

--
-- Name: relacao_cbenef_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.relacao_cbenef_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.relacao_cbenef_id_seq OWNER TO postgres;

--
-- Name: cbenef_cst; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cbenef_cst (
    id integer DEFAULT nextval('public.relacao_cbenef_id_seq'::regclass) NOT NULL,
    cbenef_id integer,
    cst character varying(2)
);


ALTER TABLE public.cbenef_cst OWNER TO postgres;

--
-- Name: centro_custo_centro_custo_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.centro_custo_centro_custo_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.centro_custo_centro_custo_codigo_seq OWNER TO postgres;

--
-- Name: centro_custo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.centro_custo (
    centro_custo_id integer NOT NULL,
    centro_custo_codigo character(7) DEFAULT lpad(((nextval('public.centro_custo_centro_custo_codigo_seq'::regclass))::character(7))::text, 7, '0'::text) NOT NULL,
    centro_custo_descricao character(100) NOT NULL,
    centro_custoab20 integer,
    centro_custo_ccd_id integer
);


ALTER TABLE public.centro_custo OWNER TO postgres;

--
-- Name: centro_custo_centro_custo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.centro_custo_centro_custo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.centro_custo_centro_custo_id_seq OWNER TO postgres;

--
-- Name: centro_custo_centro_custo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.centro_custo_centro_custo_id_seq OWNED BY public.centro_custo.centro_custo_id;


--
-- Name: centro_custo_detalhes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.centro_custo_detalhes (
    ccd_id integer NOT NULL,
    ccd_centro_custo_id integer NOT NULL,
    ccd_descricao character varying(100) NOT NULL,
    ccd_codigo character varying(10),
    ccd_codigo_outro_sistema character(20),
    usar_189 boolean DEFAULT true
);


ALTER TABLE public.centro_custo_detalhes OWNER TO postgres;

--
-- Name: centro_custo_detalhes_ccd_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.centro_custo_detalhes_ccd_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.centro_custo_detalhes_ccd_id_seq OWNER TO postgres;

--
-- Name: centro_custo_detalhes_ccd_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.centro_custo_detalhes_ccd_id_seq OWNED BY public.centro_custo_detalhes.ccd_id;


--
-- Name: cf_funcionario_valor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cf_funcionario_valor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cf_funcionario_valor_id_seq OWNER TO postgres;

--
-- Name: cf_funcionario_valor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cf_funcionario_valor (
    id integer DEFAULT nextval('public.cf_funcionario_valor_id_seq'::regclass) NOT NULL,
    id_folha integer,
    considerar boolean,
    funcionario integer,
    obs text,
    situacao integer
);


ALTER TABLE public.cf_funcionario_valor OWNER TO postgres;

--
-- Name: cfop; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cfop (
    cfop_id integer NOT NULL,
    cfop_natureza character(4) NOT NULL,
    cfop_estado character(2),
    cfop_descricao character(100) NOT NULL,
    cfop_emite_duplicata character(1),
    cfop_livros_fiscais character(1),
    cfop_operacao_fiscal integer DEFAULT 0,
    cfop_icms numeric(6,2) DEFAULT 0.00,
    cfop_iss numeric(6,2) DEFAULT 0.00,
    cfop_substit_tributaria numeric(6,2) DEFAULT 0.00,
    cfop_reducao_icms numeric(15,2) DEFAULT 0.00000,
    cfop_dif_aliquota numeric(15,2) DEFAULT 0.000000,
    cfop_pis numeric(6,2) DEFAULT 0.00,
    cfop_subtrai_icms_custo integer DEFAULT 0,
    cfop_natureza_relacionada integer DEFAULT 0,
    cfop_situacao integer DEFAULT 0,
    cfop_cod_tributacao_icms integer DEFAULT 0,
    cfop_icms_cliente_isento numeric(6,2) DEFAULT 0.00,
    cfop_perc_icms_diferido numeric(6,2) DEFAULT 0.00,
    cfop_reducao_icms_substit numeric(6,2) DEFAULT 0.00,
    cfop_cofins numeric(6,2) DEFAULT 0.00,
    cfop_faturamento integer DEFAULT 0,
    cfop_observacao text,
    cfop_movimentacao_estoque character(3),
    cfop_tem_movimentacao_fisica character(1),
    cfop_cst_icms character(3),
    cfop_cst_cofins character(3),
    cfop_cst_csosn character(3),
    cfop_cst_pis character(3),
    cfop_csosn numeric(6,2),
    cfop_maodeobra numeric(6,2),
    cfop_insumos numeric(6,2),
    cfop_calc_maodeobra "char",
    cfop_tipo character(1),
    cfop_ipi numeric(6,2) DEFAULT 0,
    cfop_calcula_nota boolean DEFAULT true,
    cfopicms_id integer,
    cfopicms_codigo integer,
    cfopicms_tabela character(100),
    cfop_cst_ipi character(3),
    cfop_cst_icms_tabela_a character(1),
    cfop_cst_icms_tabela_b character(2),
    cfop_reducao numeric(15,2)
);


ALTER TABLE public.cfop OWNER TO postgres;

--
-- Name: COLUMN cfop.cfop_tipo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.cfop.cfop_tipo IS 'este campo vai dizer se o cfop eh do tipo E=ESTADUAL ou I=INTERESTADUAL';


--
-- Name: cfop_cfop_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cfop_cfop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cfop_cfop_id_seq OWNER TO postgres;

--
-- Name: cfop_cfop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cfop_cfop_id_seq OWNED BY public.cfop.cfop_id;


--
-- Name: cheque; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cheque (
    cheque_id integer NOT NULL,
    cheque_posse character(1),
    cheque_emissao date,
    cheque_entidade character(10),
    cheque_entidadeid integer,
    cheque_titular character(60),
    cheque_banco character(3),
    cheque_bancoid integer,
    cheque_agencia character(10),
    cheque_conta character(60),
    cheque_numero character(14),
    cheque_valor numeric(13,2),
    cheque_vencimento date,
    cheque_observacao text,
    cheque_pagamento date,
    cheque_primeiro_deposito date,
    cheque_primeira_devolucao date,
    cheque_motivo character(60),
    cheque_segundo_deposito date,
    cheque_segunda_devolucao date,
    cheque_motivo2 character(60),
    cheque_destino character(60),
    cheque_entidade_nome character(100),
    cheque_banco_nome character(60),
    cheque_marcar "char",
    cheque_conta_codigo character(3),
    cheque_liquido numeric(13,2) DEFAULT 0.00,
    cheque_desconto numeric(13,2) DEFAULT 0.00,
    cheque_sustado date,
    cheque_primeiro_deposito_conta character(10),
    cheque_primeiro_deposito_conta_codigo character(3),
    cheque_segundo_deposito_conta character(10),
    cheque_segundo_deposito_conta_codigo character(3),
    cheque_repasado date,
    cheque_destino2 character(60),
    cheque_descontado date,
    cheque_baixa date,
    cheque_compensado date,
    cheque_bordero character(6),
    cheque_bordero_data date,
    cheque_bordero_entidade_cod character(10),
    cheque_bordero_entidade_nome character(80),
    cheque_bordero_observacao text,
    cheque_lote_id integer,
    cheque_saldo numeric(15,2),
    cheque_pdf character(1),
    cheque_bordero_id integer,
    cheque_bordero_id_entrada integer,
    cheque_bordero_id_transferencia integer,
    cheque_ativo boolean DEFAULT true
);


ALTER TABLE public.cheque OWNER TO postgres;

--
-- Name: cheque_cheque_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cheque_cheque_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cheque_cheque_id_seq OWNER TO postgres;

--
-- Name: cheque_cheque_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cheque_cheque_id_seq OWNED BY public.cheque.cheque_id;


--
-- Name: cheque_historico; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cheque_historico (
    cheqhist_id integer NOT NULL,
    cheqhist_cheque integer,
    cheqhist_data date,
    cheqhist_conta character(60),
    cheqhist_observacao text,
    cheqhist_destino character(60),
    cheqhist_destino2 character(60),
    cheqhist_desconto numeric(13,2) DEFAULT 0.00,
    cheqhist_liquido numeric(13,2) DEFAULT 0.00,
    cheqhist_numero character(14),
    cheqhist_motivo character(60),
    cheqhist_motivo_cod character(1),
    cheqhist_motivo_codigo integer
);


ALTER TABLE public.cheque_historico OWNER TO postgres;

--
-- Name: cheque_historico_cheqhist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cheque_historico_cheqhist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cheque_historico_cheqhist_id_seq OWNER TO postgres;

--
-- Name: cheque_historico_cheqhist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cheque_historico_cheqhist_id_seq OWNED BY public.cheque_historico.cheqhist_id;


--
-- Name: chq_lote; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chq_lote (
    chq_id integer NOT NULL,
    chq_entidade_id integer,
    chq_data date,
    chq_valor_informado numeric(15,2)
);


ALTER TABLE public.chq_lote OWNER TO postgres;

--
-- Name: chq_lote_chq_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.chq_lote_chq_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chq_lote_chq_id_seq OWNER TO postgres;

--
-- Name: chq_lote_chq_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chq_lote_chq_id_seq OWNED BY public.chq_lote.chq_id;


--
-- Name: cidades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cidades (
    cidades_id integer NOT NULL,
    cidades_nome character(80),
    cidades_uf character(2),
    cidades_codigo character(6),
    cidades_ddd character(4),
    cidades_pais_codigo character(4),
    cidades_zona character(4),
    cidades_fiscal character(3),
    cidades_regiao character(4),
    cidades_codigo_uf character(2),
    cidades_uf_mun character(7),
    pais integer,
    cidades_ibs numeric(18,2)
);


ALTER TABLE public.cidades OWNER TO postgres;

--
-- Name: cidades_cidades_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cidades_cidades_id_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cidades_cidades_id_seq OWNER TO postgres;

--
-- Name: cidades_cidades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cidades_cidades_id_seq OWNED BY public.cidades.cidades_id;


--
-- Name: cidades_tipo_logradouro; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cidades_tipo_logradouro (
    cid_tipo_log_id integer NOT NULL,
    cid_tipo_log_descricao character varying(30) NOT NULL,
    cid_tipo_log_abreviatura character varying(10) NOT NULL
);


ALTER TABLE public.cidades_tipo_logradouro OWNER TO postgres;

--
-- Name: cidades_tipo_logradouro_cid_tipo_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cidades_tipo_logradouro_cid_tipo_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cidades_tipo_logradouro_cid_tipo_log_id_seq OWNER TO postgres;

--
-- Name: cidades_tipo_logradouro_cid_tipo_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cidades_tipo_logradouro_cid_tipo_log_id_seq OWNED BY public.cidades_tipo_logradouro.cid_tipo_log_id;


--
-- Name: classificacao_classificacao_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.classificacao_classificacao_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.classificacao_classificacao_codigo_seq OWNER TO postgres;

--
-- Name: classificacao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.classificacao (
    classificacao_id integer NOT NULL,
    classificacao_codigo character(8) DEFAULT lpad(((nextval('public.classificacao_classificacao_codigo_seq'::regclass))::character(8))::text, 8, '0'::text),
    classificacao_descricao character(100),
    classificacao_ipi numeric(6,2),
    classificacao_icms numeric(6,2),
    classificacao_cst_sai character(2),
    classificacao_cst_entra character(2),
    classificacao_cst_exporta character(2),
    classificacao_cst_saida_origem character(2),
    classificacao_cst_entra_origem character(2),
    classificacao_cst_exporta_origem character(2),
    classificacao_cst_sai_fora_estado character(2),
    classificacao_origem integer,
    classificacao_cst_sai_ipi character(2),
    classificacao_cst_entra_ipi character(2),
    classificacao_cest character(10),
    classificacao_gtin character(20),
    aliqfednacional_ibpt numeric(18,2),
    aliqfedimportado_ibpt numeric(18,2),
    aliqestadual_ibpt numeric(18,2),
    aliqmunicipal_ibpt numeric(18,2),
    classificacao_cstclasstrib character(3),
    classificacao_cclasstrib character(6)
);


ALTER TABLE public.classificacao OWNER TO postgres;

--
-- Name: classificacao_bloco_k; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.classificacao_bloco_k (
    cbk_id integer NOT NULL,
    cbk_descricao character(80)
);


ALTER TABLE public.classificacao_bloco_k OWNER TO postgres;

--
-- Name: classificacao_bloco_k_cbk_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.classificacao_bloco_k_cbk_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.classificacao_bloco_k_cbk_id_seq OWNER TO postgres;

--
-- Name: classificacao_bloco_k_cbk_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.classificacao_bloco_k_cbk_id_seq OWNED BY public.classificacao_bloco_k.cbk_id;


--
-- Name: classificacao_classificacao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.classificacao_classificacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.classificacao_classificacao_id_seq OWNER TO postgres;

--
-- Name: classificacao_classificacao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.classificacao_classificacao_id_seq OWNED BY public.classificacao.classificacao_id;


--
-- Name: cliente_aa80id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cliente_aa80id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cliente_aa80id_seq OWNER TO postgres;

--
-- Name: cliente_aa80id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cliente_aa80id_seq OWNED BY public.aa80.aa80id;


--
-- Name: colecoes_colecoes_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.colecoes_colecoes_codigo_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.colecoes_colecoes_codigo_seq OWNER TO postgres;

--
-- Name: colecoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.colecoes (
    colecoes_id integer NOT NULL,
    colecoes_descricao character(80) NOT NULL,
    colecoes_disponivel character(1),
    colecoes_desc_ingles character(80),
    colecoes_desc_espanhol character(80),
    colecoes_data_inicio date,
    colecoes_data_final date,
    colecoes_codigo character(3) DEFAULT lpad(((nextval('public.colecoes_colecoes_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    colecoes_cliente_codigo character(10),
    colecoes_exclusiva boolean DEFAULT false
);


ALTER TABLE public.colecoes OWNER TO postgres;

--
-- Name: colecoes_colecoes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.colecoes_colecoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.colecoes_colecoes_id_seq OWNER TO postgres;

--
-- Name: colecoes_colecoes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.colecoes_colecoes_id_seq OWNED BY public.colecoes.colecoes_id;


--
-- Name: comissoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.comissoes (
    id integer NOT NULL,
    representante_id integer,
    periodo character(12),
    comissao numeric(18,2)
);


ALTER TABLE public.comissoes OWNER TO postgres;

--
-- Name: comissoes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.comissoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.comissoes_id_seq OWNER TO postgres;

--
-- Name: comissoes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.comissoes_id_seq OWNED BY public.comissoes.id;


--
-- Name: composicao_composicao_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.composicao_composicao_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.composicao_composicao_codigo_seq OWNER TO postgres;

--
-- Name: composicao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.composicao (
    composicao_codigo character(3) DEFAULT lpad(((nextval('public.composicao_composicao_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    composicao_descricao character(100) NOT NULL,
    composicao_id integer NOT NULL,
    composicao_abreviacao character(5)
);


ALTER TABLE public.composicao OWNER TO postgres;

--
-- Name: composicao_composicao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.composicao_composicao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.composicao_composicao_id_seq OWNER TO postgres;

--
-- Name: composicao_composicao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.composicao_composicao_id_seq OWNED BY public.composicao.composicao_id;


--
-- Name: conservacao_conservacao_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.conservacao_conservacao_codigo_seq
    START WITH 12
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.conservacao_conservacao_codigo_seq OWNER TO postgres;

--
-- Name: conservacao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.conservacao (
    conservacao_id integer NOT NULL,
    conservacao_descricao character(50) NOT NULL,
    conservacao_simbolo character(50),
    conservacao_descr_simbolo_nota character(50),
    conservacao_obs_portugues text,
    conservacao_obs_ingles text,
    conservacao_imagem bytea,
    conservacao_codigo character(3) DEFAULT lpad(((nextval('public.conservacao_conservacao_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    conservacao_local character(150),
    conservacao_familia integer
);


ALTER TABLE public.conservacao OWNER TO postgres;

--
-- Name: conservacao_conservacao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.conservacao_conservacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.conservacao_conservacao_id_seq OWNER TO postgres;

--
-- Name: conservacao_conservacao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.conservacao_conservacao_id_seq OWNED BY public.conservacao.conservacao_id;


--
-- Name: conservacaoERR; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."conservacaoERR" (
    conservacao_id integer DEFAULT nextval('public.conservacao_conservacao_id_seq'::regclass) NOT NULL,
    conservacao_descricao character(50) NOT NULL,
    conservacao_simbolo character(50),
    conservacao_descr_simbolo_nota character(50),
    conservacao_obs_portugues text,
    conservacao_obs_ingles text,
    conservacao_imagem bytea,
    conservacao_codigo character(3) DEFAULT lpad(((nextval('public.conservacao_conservacao_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    conservacao_local character(150),
    conservacao_familia integer
);


ALTER TABLE public."conservacaoERR" OWNER TO postgres;

--
-- Name: conta_corrente_cc_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.conta_corrente_cc_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.conta_corrente_cc_codigo_seq OWNER TO postgres;

--
-- Name: conta_corrente; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.conta_corrente (
    cc_id integer NOT NULL,
    cc_codigo character(3) DEFAULT lpad(((nextval('public.conta_corrente_cc_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    cc_banco_cod character(3),
    cc_banco_nome character(60),
    cc_conta character(60),
    cc_titular character(100),
    cc_agencia character(6),
    cc_agencia_nome character(100)
);


ALTER TABLE public.conta_corrente OWNER TO postgres;

--
-- Name: conta_corrente_cc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.conta_corrente_cc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.conta_corrente_cc_id_seq OWNER TO postgres;

--
-- Name: conta_corrente_cc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.conta_corrente_cc_id_seq OWNED BY public.conta_corrente.cc_id;


--
-- Name: conta_estoque; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.conta_estoque (
    conta_estoque_id integer NOT NULL,
    conta_estoque_codigo character(4),
    conta_estoque_descricao character(50)
);


ALTER TABLE public.conta_estoque OWNER TO postgres;

--
-- Name: conta_estoque_conta_estoque_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.conta_estoque_conta_estoque_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.conta_estoque_conta_estoque_id_seq OWNER TO postgres;

--
-- Name: conta_estoque_conta_estoque_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.conta_estoque_conta_estoque_id_seq OWNED BY public.conta_estoque.conta_estoque_id;


--
-- Name: cst_cts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cst_cts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 99999
    CACHE 1;


ALTER TABLE public.cst_cts_id_seq OWNER TO postgres;

--
-- Name: cst; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cst (
    cts_id integer DEFAULT nextval('public.cst_cts_id_seq'::regclass) NOT NULL,
    cst_codigo character varying(3),
    cst_operacao "char",
    cst_tipo character(10),
    cst_descricao character varying(90)
);


ALTER TABLE public.cst OWNER TO postgres;

--
-- Name: cst_ipi; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cst_ipi (
    cst_ipi_id integer NOT NULL,
    cst_ipi_codigo character(2),
    cst_ipi_descricao character(90),
    cst_ipi_enquadramento character(3),
    cst_ipi_tipo character(1)
);


ALTER TABLE public.cst_ipi OWNER TO postgres;

--
-- Name: cst_ipi_cst_ipi_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cst_ipi_cst_ipi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cst_ipi_cst_ipi_id_seq OWNER TO postgres;

--
-- Name: cst_ipi_cst_ipi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cst_ipi_cst_ipi_id_seq OWNED BY public.cst_ipi.cst_ipi_id;


--
-- Name: customizacao_tela; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customizacao_tela (
    id integer NOT NULL,
    tipo text,
    corfundo text,
    cortexto text,
    textocard text,
    textofundopagina text,
    corfundopagina text,
    corfundorodape text,
    textorodape text,
    corfundocard text
);


ALTER TABLE public.customizacao_tela OWNER TO postgres;

--
-- Name: custos_folha; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.custos_folha (
    cf_id integer NOT NULL,
    cf_data_base character(8),
    cf_descricao character(60),
    cf_data date,
    cf_hora character(10),
    cf_usuario_id integer
);


ALTER TABLE public.custos_folha OWNER TO postgres;

--
-- Name: custos_folha_cf_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.custos_folha_cf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.custos_folha_cf_id_seq OWNER TO postgres;

--
-- Name: custos_folha_cf_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.custos_folha_cf_id_seq OWNED BY public.custos_folha.cf_id;


--
-- Name: custos_folha_funcionario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.custos_folha_funcionario (
    id integer DEFAULT nextval('public.cf_funcionario_valor_id_seq'::regclass) NOT NULL,
    id_folha integer,
    considerar boolean,
    funcionario integer,
    obs text,
    situacao integer
);


ALTER TABLE public.custos_folha_funcionario OWNER TO postgres;

--
-- Name: custos_folha_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.custos_folha_item (
    cfi_id integer NOT NULL,
    cfi_cf_id integer,
    cfi_custos_id integer,
    cfi_tipo integer,
    cfi_valor numeric(18,2),
    cfi_evento character(10),
    cfi_custo_minuto numeric(18,2),
    cfi_horas_trabalhadas integer,
    folha_id integer,
    folha_funcionarios_id integer,
    funcionario_id integer,
    evento_id integer,
    referencia character(100),
    operacao integer,
    tipo character(20)
);


ALTER TABLE public.custos_folha_item OWNER TO postgres;

--
-- Name: custos_folha_item_cfi_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.custos_folha_item_cfi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.custos_folha_item_cfi_id_seq OWNER TO postgres;

--
-- Name: custos_folha_item_cfi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.custos_folha_item_cfi_id_seq OWNED BY public.custos_folha_item.cfi_id;


--
-- Name: deposito_deposito_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deposito_deposito_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deposito_deposito_codigo_seq OWNER TO postgres;

--
-- Name: deposito; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deposito (
    deposito_id integer NOT NULL,
    deposito_codigo character(3) DEFAULT lpad(((nextval('public.deposito_deposito_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    deposito_posse character(2),
    deposito_tipo_estoque character(2),
    deposito_descricao character(50) NOT NULL,
    deposito_cilindro integer,
    deposito_entidade_id integer,
    deposito_entidade_1 boolean,
    deposito_entidade_2 boolean,
    deposito_entidade_3 boolean,
    deposito_entidade_4 boolean,
    deposito_entidade_5 boolean,
    deposito_entidade_6 boolean,
    deposito_entidade_7 boolean,
    deposito_entidade_8 boolean,
    deposito_entidade_9 boolean,
    deposito_malharia_consome boolean,
    deposito_confeccao boolean,
    deposito_disponivel boolean
);


ALTER TABLE public.deposito OWNER TO postgres;

--
-- Name: deposito_deposito_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deposito_deposito_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deposito_deposito_id_seq OWNER TO postgres;

--
-- Name: deposito_deposito_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deposito_deposito_id_seq OWNED BY public.deposito.deposito_id;


--
-- Name: deposito_endereco; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deposito_endereco (
    deposito_endereco_id integer NOT NULL,
    deposito_endereco_deposito integer NOT NULL,
    deposito_endereco_descricao character(80) NOT NULL,
    deposito_endereco_numero character(6) NOT NULL,
    deposito_endereco_deposito_cod character(4)
);


ALTER TABLE public.deposito_endereco OWNER TO postgres;

--
-- Name: deposito_endereco_deposito_endereco_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deposito_endereco_deposito_endereco_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deposito_endereco_deposito_endereco_id_seq OWNER TO postgres;

--
-- Name: deposito_endereco_deposito_endereco_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deposito_endereco_deposito_endereco_id_seq OWNED BY public.deposito_endereco.deposito_endereco_id;


--
-- Name: descontos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.descontos (
    id integer NOT NULL,
    data_desconto date,
    user_id integer,
    bf_id integer,
    banco_id integer,
    valor_lancamento numeric(18,2)
);


ALTER TABLE public.descontos OWNER TO postgres;

--
-- Name: descontos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.descontos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.descontos_id_seq OWNER TO postgres;

--
-- Name: descontos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.descontos_id_seq OWNED BY public.descontos.id;


--
-- Name: descontos_operacoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.descontos_operacoes (
    id integer NOT NULL,
    valor_operacao numeric(18,2),
    ab15_id integer,
    descontos_id integer
);


ALTER TABLE public.descontos_operacoes OWNER TO postgres;

--
-- Name: descontos_operacoes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.descontos_operacoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.descontos_operacoes_id_seq OWNER TO postgres;

--
-- Name: descontos_operacoes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.descontos_operacoes_id_seq OWNED BY public.descontos_operacoes.id;


--
-- Name: desenho_descricao_ddes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.desenho_descricao_ddes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.desenho_descricao_ddes_id_seq OWNER TO postgres;

--
-- Name: desenho_descricao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.desenho_descricao (
    ddes_id integer DEFAULT nextval('public.desenho_descricao_ddes_id_seq'::regclass) NOT NULL,
    ddesc_descricao character(100),
    ddesc_codigo character(3)
);


ALTER TABLE public.desenho_descricao OWNER TO postgres;

--
-- Name: despesas_fixas_des_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.despesas_fixas_des_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.despesas_fixas_des_id_seq OWNER TO postgres;

--
-- Name: despesas_fixas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.despesas_fixas (
    des_id integer DEFAULT nextval('public.despesas_fixas_des_id_seq'::regclass) NOT NULL,
    des_descricao character(100),
    des_data date,
    des_usuario integer,
    des_data_inicio date,
    des_data_final date
);


ALTER TABLE public.despesas_fixas OWNER TO postgres;

--
-- Name: despesas_item_dit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.despesas_item_dit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.despesas_item_dit_id_seq OWNER TO postgres;

--
-- Name: despesas_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.despesas_item (
    dit_id integer DEFAULT nextval('public.despesas_item_dit_id_seq'::regclass) NOT NULL,
    dit_des_id integer,
    dit_descricao character(200),
    dit_valor numeric(18,2)
);


ALTER TABLE public.despesas_item OWNER TO postgres;

--
-- Name: df10; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.df10 (
    df10id integer NOT NULL,
    df10empresaid integer,
    df10documento character(9),
    df10sequ character(3) NOT NULL,
    df10dtemissao date,
    df10dtvencimento date,
    df10valor numeric(16,2) DEFAULT 0.00,
    df10saldo numeric(16,2) DEFAULT 0.00,
    df10documentoid integer NOT NULL,
    df10dtpagamento date,
    df10multa numeric(16,2) DEFAULT 0.00,
    df10juros numeric(16,2) DEFAULT 0.00,
    df10encargos numeric(16,2) DEFAULT 0.00,
    df10desconto numeric(16,2) DEFAULT 0.00,
    df10liquido numeric(16,2) DEFAULT 0.00,
    df10agrupacheque character(5),
    df10historico character(3),
    df10pr character(1),
    df10cd character(1),
    df10entidadeid integer,
    df10entidade character(10),
    df10ativo integer DEFAULT 0,
    df10entidadedesc character varying(100),
    df10valor_pago numeric(16,2) DEFAULT 0.00,
    df10marcar character(1),
    df10dias integer,
    df10observacao text,
    df10historico_descricao character(100),
    df10banco_codigo character(3),
    df10banco_nome character varying(100),
    df10repres_cod character(10),
    df10repres_nome character varying(100),
    df10repres_comisao numeric(6,2) DEFAULT 0.00,
    df10repres_comisao_valor numeric(15,2) DEFAULT 0.00,
    df10bordero character(6),
    df10borderodata date,
    df10rec_pag "char",
    df10fornecedor character(10),
    df10fornecedor_nome character varying(100),
    df10impresso character(1),
    df10_dados_deposito character(70),
    df10_deposito_c_corrente_id integer,
    df10negociar character(1),
    df10tipo_documento integer,
    df10docemmaos boolean DEFAULT false,
    df10pd_id integer,
    df10_ccd_id integer,
    df10numero_banco character(20),
    df10acrescimos numeric(15,2) DEFAULT 0.00,
    df10fluxo character(1) DEFAULT '0'::bpchar,
    df10plano_contas_id integer,
    df10documento_invoice_id integer,
    df10recibo boolean DEFAULT false,
    df10operacao integer,
    df10bordero_id integer DEFAULT 0,
    df10imprimiu_bordero character(200),
    df10enviou_bordero character(200),
    df10gerou_remessa character(200),
    df10dt_ultimoaviso date,
    df10banco_id integer,
    df10id_vendas_especificas integer,
    df10obs_recompra text,
    comissao_reserva numeric(18,2),
    df10observa_parcelas character(100),
    df10tipo_cobranca integer,
    representante2_id integer,
    comissao2_percentual numeric(18,2),
    comissao2_valor numeric(18,2),
    df10range integer,
    df10_idorcamento integer,
    df10provisao boolean,
    df10romaneio_id integer,
    df10obs_de_baixa text,
    df10rmt_id integer,
    df10dtvencimento_original date,
    df10tipo_mvto integer,
    df10dtlancamento date DEFAULT ('now'::text)::date,
    df10horalancamento character(8) DEFAULT "substring"((('now'::text)::time with time zone)::text, 1, 8)
);


ALTER TABLE public.df10 OWNER TO postgres;

--
-- Name: TABLE df10; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.df10 IS 'Contas a Receber & Contas a Pagar  ( Duplicata )';


--
-- Name: df10_df10documentoid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.df10_df10documentoid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.df10_df10documentoid_seq OWNER TO postgres;

--
-- Name: df10_df10documentoid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.df10_df10documentoid_seq OWNED BY public.df10.df10documentoid;


--
-- Name: df10_df10id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.df10_df10id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.df10_df10id_seq OWNER TO postgres;

--
-- Name: df10_df10id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.df10_df10id_seq OWNED BY public.df10.df10id;


--
-- Name: df10_temp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.df10_temp (
    df10id integer NOT NULL,
    df10empresaid integer,
    df10documento character(9),
    df10sequ character(1) NOT NULL,
    df10dtemissao date,
    df10dtvencimento date,
    df10valor numeric(16,2) DEFAULT 0.00,
    df10saldo numeric(16,2) DEFAULT 0.00,
    df10documentoid integer NOT NULL,
    df10dtpagamento date,
    df10multa numeric(16,2) DEFAULT 0.00,
    df10juros numeric(16,2) DEFAULT 0.00,
    df10encargos numeric(16,2) DEFAULT 0.00,
    df10desconto numeric(16,2) DEFAULT 0.00,
    df10liquido numeric(16,2) DEFAULT 0.00,
    df10agrupacheque character(5),
    df10historico character(3),
    df10pr character(1),
    df10cd character(1),
    df10entidadeid integer,
    df10entidade character(10),
    df10ativo integer DEFAULT 0,
    df10entidadedesc character varying(100),
    df10valor_pago numeric(16,2) DEFAULT 0.00,
    df10marcar character(1),
    df10dias integer,
    df10observacao text,
    df10historico_descricao character(100),
    df10banco_codigo character(3),
    df10banco_nome character varying(100),
    df10repres_cod character(10),
    df10repres_nome character varying(100),
    df10repres_comisao numeric(6,2) DEFAULT 0.00,
    df10repres_comisao_valor numeric(15,2) DEFAULT 0.00,
    df10bordero character(6),
    df10borderodata date,
    df10rec_pag "char",
    df10fornecedor character(10),
    df10fornecedor_nome character varying(100),
    df10impresso character(1),
    df10_dados_deposito character(70),
    df10_deposito_c_corrente_id integer,
    df10negociar character(1),
    df10tipo_documento integer,
    df10docemmaos boolean DEFAULT false,
    df10pd_id integer,
    df10_ccd_id integer,
    df10numero_banco character(20),
    df10acrescimos numeric(15,2) DEFAULT 0.00,
    df10fluxo character(1) DEFAULT '0'::bpchar,
    df10plano_contas_id integer,
    df10documento_invoice_id integer
);


ALTER TABLE public.df10_temp OWNER TO postgres;

--
-- Name: df10_temp_df10id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.df10_temp_df10id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.df10_temp_df10id_seq OWNER TO postgres;

--
-- Name: df10_temp_df10id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.df10_temp_df10id_seq OWNED BY public.df10_temp.df10id;


--
-- Name: df10documento_id118; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.df10documento_id118
    START WITH 200000
    INCREMENT BY 1
    MINVALUE 200000
    MAXVALUE 400000
    CACHE 1;


ALTER TABLE public.df10documento_id118 OWNER TO postgres;

--
-- Name: df20; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.df20 (
    df20id integer NOT NULL,
    df20empresaid integer,
    df20documento character(9),
    df20sequ character(3),
    df20dtemissao date,
    df20dtvencimento date,
    df20valor numeric(16,2) DEFAULT 0.00,
    df20saldo numeric(16,2) DEFAULT 0.00,
    df20documentoid integer NOT NULL,
    df20dtpagamento date,
    df20multa numeric(16,2) DEFAULT 0.00,
    df20juros numeric(16,2) DEFAULT 0.00,
    df20encargos numeric(16,2) DEFAULT 0.00,
    df20desconto numeric(16,2) DEFAULT 0.00,
    df20liquido numeric(16,2) DEFAULT 0.00,
    df20agrupacheque character(5),
    df20historico character(3),
    df20pr character(1),
    df20cd character(1),
    df20entidadeid integer,
    df20entidade character(10),
    df20ativo integer DEFAULT 0,
    df20entidadedesc character varying(100),
    df20valor_pago numeric(16,2) DEFAULT 0.00,
    df20marcar character(1),
    df20dias integer,
    df20observacao text,
    df20historico_descricao character(100),
    df20banco_codigo character(3),
    df20banco_nome character varying(100),
    df20repres_cod character(10),
    df20repres_nome character varying(100),
    df20repres_comisao numeric(6,2) DEFAULT 0.00,
    df20repres_comisao_valor numeric(15,2) DEFAULT 0.00,
    df20bordero character(6),
    df20borderodata date,
    df20rec_pag "char",
    df20_dados_deposito character(70),
    df20_deposito_c_corrente_id integer,
    df20negociar character(1),
    df20tipo_documento integer,
    df20impresso character(1),
    df20docemmaos boolean DEFAULT false,
    df20pd_id integer,
    df20_ccd_id integer,
    df20numero_banco character(20),
    df20acrescimos numeric(15,2) DEFAULT 0.00,
    df20fluxo character(1) DEFAULT '0'::bpchar,
    df20plano_contas_id integer,
    df20documento_invoice_id integer,
    df20recibo boolean DEFAULT false,
    df20operacao integer,
    df20bordero_id integer DEFAULT 0,
    df20imprimiu_bordero character(200),
    df20enviou_bordero character(200),
    df20gerou_remessa character(200),
    df20banco_id integer,
    df20id_vendas_especificas integer,
    df20romaneio_id integer,
    df20obs_recompra text,
    df20observa_parcelas character(100),
    df20dt_ultimoaviso date,
    comissao_reserva numeric(18,2),
    df20tipo_cobranca integer,
    representante2_id integer,
    comissao2_percentual numeric(18,2),
    comissao2_valor numeric(18,2),
    df20range integer,
    df20_idorcamento integer,
    df20provisao boolean,
    df20obs_de_baixa text,
    df20rmt_id integer,
    df20dtvencimento_original date,
    df20tipo_mvto integer,
    df20dtlancamento date DEFAULT ('now'::text)::date,
    df20horalancamento character(8) DEFAULT "substring"((('now'::text)::time with time zone)::text, 1, 8)
);


ALTER TABLE public.df20 OWNER TO postgres;

--
-- Name: df20_df20id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.df20_df20id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.df20_df20id_seq OWNER TO postgres;

--
-- Name: df20_df20id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.df20_df20id_seq OWNED BY public.df20.df20id;


--
-- Name: dfcc_dfcc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dfcc_dfcc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dfcc_dfcc_id_seq OWNER TO postgres;

--
-- Name: dfcc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dfcc (
    dfcc_id integer DEFAULT nextval('public.dfcc_dfcc_id_seq'::regclass) NOT NULL,
    dfcc_tipo integer,
    dfcc_idduplicata integer,
    dfcc_percentual numeric(18,4),
    dfcc_valor numeric(18,4),
    dfcc_idccd integer,
    dfcc_iduser integer,
    dfcc_data_user date,
    dfcc_hora_user character(12),
    dfcc_observacoes text,
    dfcc_valor_proporcional numeric(18,4),
    dfcc_documentoid integer
);


ALTER TABLE public.dfcc OWNER TO postgres;

--
-- Name: dfe_cclas_tributacao_ibs_cbs_id_cclas_ibs_cbs_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dfe_cclas_tributacao_ibs_cbs_id_cclas_ibs_cbs_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dfe_cclas_tributacao_ibs_cbs_id_cclas_ibs_cbs_seq OWNER TO postgres;

--
-- Name: dfe_cclas_tributacao_ibs_cbs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dfe_cclas_tributacao_ibs_cbs (
    id_cclas_ibs_cbs integer DEFAULT nextval('public.dfe_cclas_tributacao_ibs_cbs_id_cclas_ibs_cbs_seq'::regclass) NOT NULL,
    id_cst_ibs_cbs integer,
    cst_ibs_cbs character(255),
    descricao_cst_ibs_cbs text,
    cclasstrib text,
    nome_cclasstrib text,
    descricao_cclasstrib text,
    lc_redacao text,
    lc_214_25 text,
    tipo_de_aliquota text,
    predibs numeric(18,4),
    predcbs numeric(18,4),
    pred_ibs_cbs numeric(18,4),
    ind_redutorbc character(3) DEFAULT 'NAO'::bpchar,
    ind_gtribregular character(3) DEFAULT 'NAO'::bpchar,
    ind_credpres character(3) DEFAULT 'NAO'::bpchar,
    indmono character(3) DEFAULT 'NAO'::bpchar,
    indmonoreten character(3) DEFAULT 'NAO'::bpchar,
    indmonoret character(3) DEFAULT 'NAO'::bpchar,
    indmonodif character(3) DEFAULT 'NAO'::bpchar,
    credito_para text,
    ind_gestornocred character(3) DEFAULT 'NAO'::bpchar,
    indnfeabi character(3) DEFAULT 'NAO'::bpchar,
    indnfe character(3) DEFAULT 'NAO'::bpchar,
    indnfce character(3) DEFAULT 'NAO'::bpchar,
    indcte character(3) DEFAULT 'NAO'::bpchar,
    indcteos character(3) DEFAULT 'NAO'::bpchar,
    indbpe character(3) DEFAULT 'NAO'::bpchar,
    indbpeta character(3) DEFAULT 'NAO'::bpchar,
    indbpetm character(3) DEFAULT 'NAO'::bpchar,
    indnf3e character(3) DEFAULT 'NAO'::bpchar,
    indnfse character(3) DEFAULT 'NAO'::bpchar,
    indnfse_via character(3) DEFAULT 'NAO'::bpchar,
    indnfcom character(3) DEFAULT 'NAO'::bpchar,
    indnfag character(3) DEFAULT 'NAO'::bpchar,
    indnfgas character(3) DEFAULT 'NAO'::bpchar,
    inddere character(3) DEFAULT 'NAO'::bpchar,
    dinivig date,
    dfimvig date,
    dataatualizacao time without time zone
);


ALTER TABLE public.dfe_cclas_tributacao_ibs_cbs OWNER TO postgres;

--
-- Name: dfe_credito_presumido_ibs_cbs_id_credito_presumido_ibs_cbs_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dfe_credito_presumido_ibs_cbs_id_credito_presumido_ibs_cbs_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dfe_credito_presumido_ibs_cbs_id_credito_presumido_ibs_cbs_seq OWNER TO postgres;

--
-- Name: dfe_credito_presumido_ibs_cbs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dfe_credito_presumido_ibs_cbs (
    id_credito_presumido_ibs_cbs integer DEFAULT nextval('public.dfe_credito_presumido_ibs_cbs_id_credito_presumido_ibs_cbs_seq'::regclass) NOT NULL,
    codigo_credito_presumido_ibs_cbs integer,
    descricao_credito_presumido_ibs_cbs text,
    dfe_credito_presumido_ibs_cbs character(3) DEFAULT 'NAO'::bpchar,
    evento_credito_presumido_ibs_cbs character(3) DEFAULT 'NAO'::bpchar,
    deduz_valor_total_credito_presumido_ibs_cbs character(3) DEFAULT 'NAO'::bpchar,
    tributo_ibs_credito_presumido_ibs_cbs character(3) DEFAULT 'NAO'::bpchar,
    tributado_cbs_credito_presumido_ibs_cbs character(3) DEFAULT 'NAO'::bpchar
);


ALTER TABLE public.dfe_credito_presumido_ibs_cbs OWNER TO postgres;

--
-- Name: dfe_cst_tributacao_ibs_cbs_id_cst_ibs_cbs_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dfe_cst_tributacao_ibs_cbs_id_cst_ibs_cbs_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dfe_cst_tributacao_ibs_cbs_id_cst_ibs_cbs_seq OWNER TO postgres;

--
-- Name: dfe_cst_tributacao_ibs_cbs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dfe_cst_tributacao_ibs_cbs (
    id_cst_ibs_cbs integer DEFAULT nextval('public.dfe_cst_tributacao_ibs_cbs_id_cst_ibs_cbs_seq'::regclass) NOT NULL,
    cst_ibs_cbs text,
    descricao_cst_ibs_cbs text,
    ind_gibscbs character(3) DEFAULT 'NAO'::bpchar,
    ind_gibscbsmono character(3) DEFAULT 'NAO'::bpchar,
    ind_gred character(3) DEFAULT 'NAO'::bpchar,
    ind_gdif character(3) DEFAULT 'NAO'::bpchar,
    ind_gtransfcred character(3) DEFAULT 'NAO'::bpchar,
    ind_gcredpresibszfm character(3) DEFAULT 'NAO'::bpchar,
    ind_gajustecompet character(3) DEFAULT 'NAO'::bpchar
);


ALTER TABLE public.dfe_cst_tributacao_ibs_cbs OWNER TO postgres;

--
-- Name: dfe_ncm_nbs_ibs_cbs_id_ncm_nbs_ibs_cbs_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dfe_ncm_nbs_ibs_cbs_id_ncm_nbs_ibs_cbs_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dfe_ncm_nbs_ibs_cbs_id_ncm_nbs_ibs_cbs_seq OWNER TO postgres;

--
-- Name: dfe_ncm_nbs_ibs_cbs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dfe_ncm_nbs_ibs_cbs (
    id_ncm_nbs_ibs_cbs integer DEFAULT nextval('public.dfe_ncm_nbs_ibs_cbs_id_ncm_nbs_ibs_cbs_seq'::regclass) NOT NULL,
    id_cclass_ibs_cbs integer,
    cclass_trib character(6),
    ncm_nbs_ibs_cbs character(9),
    nome_ncm_nbs_ibs_cbs text,
    tipo_ncm_nbs_ibs_cbs character(3),
    inicio_vigencia_ncm_nbs_ibs_cbs date,
    terminino_vigencia_ncm_nbs_ibs_cbs date,
    cst_ibs_cbs character(3)
);


ALTER TABLE public.dfe_ncm_nbs_ibs_cbs OWNER TO postgres;

--
-- Name: COLUMN dfe_ncm_nbs_ibs_cbs.id_cclass_ibs_cbs; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.dfe_ncm_nbs_ibs_cbs.id_cclass_ibs_cbs IS 'id da tabela dfe_cclass_tributacao_ibs_cbs';


--
-- Name: dfgc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dfgc (
    dfgcid integer NOT NULL,
    dfgcdocumento character(10),
    dfgcdata_emissao date,
    dfgcdata_vencimento date,
    dfgcdata_pagamento date,
    dfgcvalor numeric(18,2),
    dfgcobservacao character varying(160),
    dfgcentidade integer,
    dfgcrepresentante integer,
    dfgctipo integer,
    dfgcnotafiscal character(10),
    dfgcpedido character(6),
    dfgcrepresentante_cod character(10),
    dfgcreentidade_cod character(10),
    dfgcvalortitulo numeric(18,2),
    dfgccomissao numeric(18,2)
);


ALTER TABLE public.dfgc OWNER TO postgres;

--
-- Name: dfgc_dfgcid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dfgc_dfgcid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dfgc_dfgcid_seq OWNER TO postgres;

--
-- Name: dfgc_dfgcid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dfgc_dfgcid_seq OWNED BY public.dfgc.dfgcid;


--
-- Name: dflog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dflog (
    dflog_id integer NOT NULL,
    dflog_tipo integer NOT NULL,
    dflog_entidade character(10),
    dflog_documento character(10),
    dflog_seq character(3),
    dflog_valor_liquido numeric(17,5),
    dflog_desconto numeric(17,5),
    dflog_juros numeric(10,5),
    dflog_valor_pago numeric(17,5),
    dflog_saldo numeric(17,5),
    dflog_dfid integer,
    dflog_usuario integer,
    dflog_data date,
    dflog_hora time without time zone,
    dflog_dflogtm_id integer,
    dflog_acrescimos numeric(10,5),
    dflog_observa text
);


ALTER TABLE public.dflog OWNER TO postgres;

--
-- Name: dflog_dflog_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dflog_dflog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dflog_dflog_id_seq OWNER TO postgres;

--
-- Name: dflog_dflog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dflog_dflog_id_seq OWNED BY public.dflog.dflog_id;


--
-- Name: dflog_tipos_mov; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dflog_tipos_mov (
    dflogtm_id integer NOT NULL,
    dflogtm_descricao character varying(50) NOT NULL
);


ALTER TABLE public.dflog_tipos_mov OWNER TO postgres;

--
-- Name: dflog_tipos_mov_dflogtm_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dflog_tipos_mov_dflogtm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dflog_tipos_mov_dflogtm_id_seq OWNER TO postgres;

--
-- Name: dflog_tipos_mov_dflogtm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dflog_tipos_mov_dflogtm_id_seq OWNED BY public.dflog_tipos_mov.dflogtm_id;


--
-- Name: dfplano_contas_dfplc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dfplano_contas_dfplc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dfplano_contas_dfplc_id_seq OWNER TO postgres;

--
-- Name: dfplano_contas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dfplano_contas (
    dfplc_id integer DEFAULT nextval('public.dfplano_contas_dfplc_id_seq'::regclass) NOT NULL,
    dfplc_tipo integer,
    dfplc_idduplicata integer,
    dfplc_percentual numeric(18,4),
    dfplc_valor numeric(18,4),
    dfplc_idplano_detalhe integer,
    dfplc_iduser integer,
    dfplc_data_user date,
    dfplc_hora_user character(12),
    dfplc_observacoes text,
    dfplc_valor_proporcional numeric(18,4),
    dfplc_documentoid integer
);


ALTER TABLE public.dfplano_contas OWNER TO postgres;

--
-- Name: dfterceiro; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dfterceiro (
    dfterceiro_id integer NOT NULL,
    dfterceiro_cliente_id integer,
    dfterceiro_sacado character(120),
    dfterceiro_representante_id integer,
    dfterceiro_numero_banco character(20),
    dfterceiro_emissao date,
    dfterceiro_vencimento date,
    dfterceiro_pagamento date,
    dfterceiro_liquido numeric(12,2) DEFAULT 0.00,
    dfterceiro_saldo numeric(12,2) DEFAULT 0.00,
    dfterceiro_juros numeric(12,2) DEFAULT 0.00,
    dfterceiro_desconto numeric(12,2) DEFAULT 0.00,
    dfterceiro_observacao character(150),
    dfterceiro_documento character(15),
    dfterceiro_nota_fiscal character(15),
    dfterceiro_carteira character(3)
);


ALTER TABLE public.dfterceiro OWNER TO postgres;

--
-- Name: dfterceiro_dfterceiro_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dfterceiro_dfterceiro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dfterceiro_dfterceiro_id_seq OWNER TO postgres;

--
-- Name: dfterceiro_dfterceiro_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dfterceiro_dfterceiro_id_seq OWNED BY public.dfterceiro.dfterceiro_id;


--
-- Name: divisoes_producao_divisoes_producao_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.divisoes_producao_divisoes_producao_codigo_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.divisoes_producao_divisoes_producao_codigo_seq OWNER TO postgres;

--
-- Name: divisoes_producao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.divisoes_producao (
    divisoes_producao_id integer NOT NULL,
    divisoes_producao_descricao character(50),
    divisoes_producao_vlr_dia numeric(15,3),
    divisoes_producao_qtd_dia numeric(15,3),
    divisoes_producao_efic numeric(3,3),
    divisoes_producao_time numeric(3,2),
    divisoes_producao_abast numeric(3,0),
    divisoes_producao_qtd_max numeric(3,0),
    divisoes_producao_rota numeric(3,0),
    divisoes_producao_linha numeric(4,0),
    divisoes_producao_codigo character(3) DEFAULT lpad(((nextval('public.divisoes_producao_divisoes_producao_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    divisoes_producao_producao_codigo character(4),
    divisoes_producao_deposito character(3),
    divisoes_producao_custo character(7)
);


ALTER TABLE public.divisoes_producao OWNER TO postgres;

--
-- Name: divisoes_producao_divisoes_producao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.divisoes_producao_divisoes_producao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.divisoes_producao_divisoes_producao_id_seq OWNER TO postgres;

--
-- Name: divisoes_producao_divisoes_producao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.divisoes_producao_divisoes_producao_id_seq OWNED BY public.divisoes_producao.divisoes_producao_id;


--
-- Name: email; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.email (
    email_id integer NOT NULL,
    email_nome character(50) NOT NULL,
    email_email character(80) NOT NULL,
    email_observacao text
);


ALTER TABLE public.email OWNER TO postgres;

--
-- Name: email_email_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.email_email_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.email_email_id_seq OWNER TO postgres;

--
-- Name: email_email_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.email_email_id_seq OWNED BY public.email.email_id;


--
-- Name: emails_artigo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emails_artigo (
    emails_artigo_id integer NOT NULL,
    emails_artigo_codigo integer NOT NULL,
    emails_artigo_descricao character(50) NOT NULL,
    emails_artigo_responsavel character(80)
);


ALTER TABLE public.emails_artigo OWNER TO postgres;

--
-- Name: emails_artigo_emails_artigo_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.emails_artigo_emails_artigo_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emails_artigo_emails_artigo_codigo_seq OWNER TO postgres;

--
-- Name: emails_artigo_emails_artigo_codigo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.emails_artigo_emails_artigo_codigo_seq OWNED BY public.emails_artigo.emails_artigo_codigo;


--
-- Name: emails_artigo_emails_artigo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.emails_artigo_emails_artigo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emails_artigo_emails_artigo_id_seq OWNER TO postgres;

--
-- Name: emails_artigo_emails_artigo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.emails_artigo_emails_artigo_id_seq OWNED BY public.emails_artigo.emails_artigo_id;


--
-- Name: embalagens_embalagens_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.embalagens_embalagens_codigo_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.embalagens_embalagens_codigo_seq OWNER TO postgres;

--
-- Name: embalagens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.embalagens (
    embalagens_id integer NOT NULL,
    embalagens_descricao character(50) NOT NULL,
    embalagens_peso_fixo numeric(15,4),
    embalagens_qtd_pc numeric(15,4),
    embalagens_peso_emp numeric(15,4),
    embalagens_peso numeric(15,4),
    embalagens_metros numeric(15,5),
    embalagens_dimensoes character(50),
    embalagens_unidade_medida character(2),
    embalagens_aq numeric(1,0),
    embalagens_peso_minimo numeric(15,4),
    embalagens_peso_maximo numeric(15,4),
    embalagens_apresentacao character(50),
    embalagens_codigo character(3) DEFAULT lpad(((nextval('public.embalagens_embalagens_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    embalagens_alt character(2)
);


ALTER TABLE public.embalagens OWNER TO postgres;

--
-- Name: embalagens_embalagens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.embalagens_embalagens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.embalagens_embalagens_id_seq OWNER TO postgres;

--
-- Name: embalagens_embalagens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.embalagens_embalagens_id_seq OWNED BY public.embalagens.embalagens_id;


--
-- Name: empresa_empresa_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresa_empresa_codigo_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.empresa_empresa_codigo_seq OWNER TO postgres;

--
-- Name: empresa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empresa (
    empresa_nome character varying(50) NOT NULL,
    empresa_id integer NOT NULL,
    empresa_codigo character(3) DEFAULT lpad(((nextval('public.empresa_empresa_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    empresa_tipo character(10),
    empresa_fantasia character(50),
    empresa_endereco character(50),
    empresa_nro character(20),
    empresa_complemento character(50),
    empresa_bairro character(50),
    empresa_cidade_id integer NOT NULL,
    empresa_fone character(18),
    empresa_cep character(20),
    empresa_fax character(20),
    empresa_email character(50),
    empresa_ie character(20),
    empresa_cnpj character(20),
    empresa_sci character(20),
    empresa_junta character(20),
    empresa_data_junta date,
    empresa_im character(20),
    empresa_imagem bytea,
    empresa_imagem_local character(100),
    empresa_area character(20),
    empresa_nfe character(9) DEFAULT 1,
    empresa_modelo character(5),
    empresa_tipo_tributacao integer DEFAULT 0,
    empresa_permitir_alterar_entidade boolean DEFAULT true NOT NULL,
    empresa_pis numeric(6,2) DEFAULT 0.00,
    empresa_cofins numeric(6,2) DEFAULT 0.00,
    empresa_permite_nfe character(1),
    empresa_contribuicao_social numeric(5,2),
    empresa_custo_operacional numeric(15,6),
    empresa_comissoes numeric(5,2),
    empresa_energia numeric(15,6),
    empresa_custo_produto character(1),
    empresa_cidade_nome character(100),
    empresa_uf character(2),
    empresa_bordero_texto text,
    empresa_site character(35),
    empresa_cnae character(7),
    empresa_local_fci character(300),
    empresa_tabela_icms_id integer,
    empresa_layout_fin0119 integer DEFAULT 0,
    empresa_etq_layout_pcpt0165 integer,
    empresa_etq_layout_pcpt0160 integer DEFAULT 0,
    empresa_dep_um character(3),
    empresa_dep_tres_tec character(3),
    empresa_dep_quatro_tec character(3),
    empresa_dep_tres_malha character(3),
    empresa_dep_quatro_malha character(3),
    empresa_layout_fin0117 integer DEFAULT 0,
    empresa_tara_165a numeric,
    empresa_layout_romaneio_166 integer DEFAULT 0,
    empresa_entidade_id integer,
    empresa_romaneio_simples166 boolean DEFAULT false,
    empresa_layout158 integer DEFAULT 0,
    empresa_pedido_direto boolean,
    empresa_romaneio_direto boolean,
    empresa_consulta_estoque166 integer DEFAULT 0,
    empresa_vale_166 integer DEFAULT 0,
    empresa_vale_direto boolean,
    empresa_pedido_166 integer DEFAULT 0,
    empresa_banco character(3),
    empresa_imagem_painel character(100),
    empresa_imagem_painel_figura bytea,
    empresa_layout208 integer DEFAULT 0,
    empresa_id_balanca_160 integer,
    empresa_id_balanca_165 integer,
    empresa_zera_operador_165 integer,
    empresa_romaneio_completo boolean,
    empresa_atualiza_pedidos_segundos integer,
    empresa_aa80id integer,
    empresa_layout174analitico integer DEFAULT 0,
    empresa_cscsn numeric(6,2),
    empresa_corrige_total158 boolean,
    empresa_sistema_expira date,
    empresa_baixa_estoque_182 boolean DEFAULT true,
    empresa_layout_182 integer,
    empresa_forma_pagamento character(3),
    empresa_tipo_documento character(5),
    empresa_carteira character(3),
    empresa_remessa_216 boolean,
    empresa_usar_fundo_para_calc_partida boolean,
    empresa_abreviada character(4),
    empresa_widget1_funcao integer,
    empresa_widget1_titulo character(80),
    empresa_widget1_figura character(80),
    empresa_widget2_funcao integer,
    empresa_widget2_titulo character(80),
    empresa_widget2_figura character(80),
    empresa_widget3_funcao integer,
    empresa_widget3_titulo character(80),
    empresa_widget3_figura character(80),
    empresa_widget4_funcao integer,
    empresa_widget4_titulo character(80),
    empresa_widget4_figura character(80),
    empresa_libera_venda_pecas_todos98 boolean DEFAULT false,
    empresa_romaneio_imprime boolean DEFAULT true,
    empresa_layout_157 integer DEFAULT 0,
    empresa_habilita_bloco0 boolean DEFAULT false,
    empresa_habilita_blocok boolean DEFAULT true,
    empresa_layout_romaneio_simples_166 integer,
    empresa_serie character(2),
    empresa_monta_codigo boolean,
    empresa_visualiza_home integer DEFAULT 0,
    empresa_manual boolean,
    empresa_terceiro boolean,
    empresa_planilha boolean,
    empresa_terceiro_nome character(100),
    empresa_planilha_nome character(100)
);


ALTER TABLE public.empresa OWNER TO postgres;

--
-- Name: TABLE empresa; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.empresa IS 'Tabela aonde guarda o nomes da empresa';


--
-- Name: empresa_empresa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresa_empresa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.empresa_empresa_id_seq OWNER TO postgres;

--
-- Name: empresa_empresa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empresa_empresa_id_seq OWNED BY public.empresa.empresa_id;


--
-- Name: encargos_enc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.encargos_enc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.encargos_enc_id_seq OWNER TO postgres;

--
-- Name: encargos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.encargos (
    enc_id integer DEFAULT nextval('public.encargos_enc_id_seq'::regclass) NOT NULL,
    enc_idcenario integer,
    enc_descricao character(150),
    enc_tipo integer,
    enc_tipo_valor character(10),
    enc_valor numeric(18,2)
);


ALTER TABLE public.encargos OWNER TO postgres;

--
-- Name: espessuras; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.espessuras (
    esp_id integer NOT NULL,
    esp_espessura numeric(10,2),
    esp_metro_minuto integer
);


ALTER TABLE public.espessuras OWNER TO postgres;

--
-- Name: espessuras_esp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.espessuras_esp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.espessuras_esp_id_seq OWNER TO postgres;

--
-- Name: espessuras_esp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.espessuras_esp_id_seq OWNED BY public.espessuras.esp_id;


--
-- Name: estagios_estagios_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estagios_estagios_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.estagios_estagios_codigo_seq OWNER TO postgres;

--
-- Name: estagios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estagios (
    estagios_id integer NOT NULL,
    estagios_codigo character(2) DEFAULT lpad(((nextval('public.estagios_estagios_codigo_seq'::regclass))::character(2))::text, 2, '0'::text),
    estagios_descricao character(40),
    estagios_consumo numeric(12,6),
    estagios_cm_homem numeric(12,6),
    estagios_cm_maquina numeric(12,6),
    estagios_cm_energia numeric(12,6),
    estagios_area character(3),
    estagios_aponta character(1),
    estagios_cm_outros numeric(12,6),
    estagios_area_tipo character(3),
    exibe_scrum boolean DEFAULT true
);


ALTER TABLE public.estagios OWNER TO postgres;

--
-- Name: estagios_estagios_serial_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estagios_estagios_serial_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.estagios_estagios_serial_seq OWNER TO postgres;

--
-- Name: estagios_estagios_serial_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estagios_estagios_serial_seq OWNED BY public.estagios.estagios_id;


--
-- Name: estampa_cilindro; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estampa_cilindro (
    estampa_cilindro_id integer NOT NULL,
    estampa_cilindro_estampa integer,
    estampa_cilindro_quadro_codigo character(3)
);


ALTER TABLE public.estampa_cilindro OWNER TO postgres;

--
-- Name: estampa_cilindro_estampa_cilindro_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estampa_cilindro_estampa_cilindro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.estampa_cilindro_estampa_cilindro_id_seq OWNER TO postgres;

--
-- Name: estampa_cilindro_estampa_cilindro_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estampa_cilindro_estampa_cilindro_id_seq OWNED BY public.estampa_cilindro.estampa_cilindro_id;


--
-- Name: estampas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estampas (
    estampas_id integer NOT NULL,
    estampas_descricao character(50) NOT NULL,
    estampas_cor_representativa character(50),
    estampas_observacao text,
    estampas_codigo character(6) DEFAULT 0 NOT NULL,
    estampas_serie character(3) DEFAULT 999,
    estampas_cor_fundo character(3),
    estampas_cor_estampa character(50),
    estampas_cor_fundo_descricao character(50),
    estampas_pantone character(10),
    estampa_lisa character(1),
    estampa_estampa character(1),
    estampas_cliente character(13),
    estampas_cilindro character(3),
    estampas_log_usuario character(50),
    estampas_receitaid integer,
    estampas_receita character(45),
    estampa_codigo_importacao character(20),
    estampas_classificacao integer DEFAULT 0,
    estampas_codigo_referencia character(10),
    estampas_imagem character(300),
    estampas_inativar boolean DEFAULT false,
    estampas_data date,
    estampas_status integer DEFAULT 1
);


ALTER TABLE public.estampas OWNER TO postgres;

--
-- Name: TABLE estampas; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.estampas IS 'cor';


--
-- Name: estampas_estampas_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estampas_estampas_codigo_seq
    START WITH 1000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.estampas_estampas_codigo_seq OWNER TO postgres;

--
-- Name: estampas_estampas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estampas_estampas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.estampas_estampas_id_seq OWNER TO postgres;

--
-- Name: estampas_estampas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estampas_estampas_id_seq OWNED BY public.estampas.estampas_id;


--
-- Name: estoque_estoque_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estoque_estoque_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.estoque_estoque_codigo_seq OWNER TO postgres;

--
-- Name: estoque; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estoque (
    estoque_id integer NOT NULL,
    estoque_codigo character(3) DEFAULT lpad(((nextval('public.estoque_estoque_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    estoque_descricao character(50),
    estoque_depid integer,
    estoque_depcodigo character(3),
    estoque_depnome character(60),
    estoque_produtoid integer,
    estoque_produtoreferencia character(8),
    estoque_produtonivel character(1),
    estoque_produtodescricao character(60),
    estoque_itemid integer,
    estoque_itemcodigo character(6),
    estoque_itemnome character(60),
    estoque_qtde numeric(15,4),
    estoque_seguranca numeric(15,4)
);


ALTER TABLE public.estoque OWNER TO postgres;

--
-- Name: estoque_estoque_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estoque_estoque_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.estoque_estoque_id_seq OWNER TO postgres;

--
-- Name: estoque_estoque_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estoque_estoque_id_seq OWNED BY public.estoque.estoque_id;


--
-- Name: estrutura_custo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estrutura_custo (
    id integer NOT NULL,
    aa50id integer,
    aa50nivel integer,
    estrutura character(5),
    seq integer,
    componente integer,
    estampa_id integer,
    base_id integer,
    variacao_id integer,
    unidade character(5),
    qtde numeric(18,2),
    valor numeric(18,2),
    exibe boolean DEFAULT false,
    marca boolean DEFAULT false,
    mkf_id integer,
    mkf_descricao character(100),
    mki_id integer,
    descricao character(100),
    percentual numeric(18,2),
    mao_de_obra numeric(18,2),
    preco numeric(18,2),
    quebra_custo numeric(18,2)
);


ALTER TABLE public.estrutura_custo OWNER TO postgres;

--
-- Name: estrutura_custo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estrutura_custo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.estrutura_custo_id_seq OWNER TO postgres;

--
-- Name: estrutura_custo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estrutura_custo_id_seq OWNED BY public.estrutura_custo.id;


--
-- Name: eventos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eventos (
    id integer NOT NULL,
    ocorrencia_id integer,
    inicio timestamp without time zone,
    fim timestamp without time zone,
    observacao text,
    os_id integer,
    obt_id integer,
    data time without time zone,
    operador integer,
    maquina integer,
    minutos integer,
    user_alterou integer,
    user_alterou_data timestamp without time zone,
    turno integer
);


ALTER TABLE public.eventos OWNER TO postgres;

--
-- Name: eventos_folha_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.eventos_folha_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eventos_folha_id_seq OWNER TO postgres;

--
-- Name: eventos_folha; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eventos_folha (
    id integer DEFAULT nextval('public.eventos_folha_id_seq'::regclass) NOT NULL,
    descricao character(150),
    folha_simulacao boolean DEFAULT false,
    percentual numeric(18,4),
    valor_fixo numeric(18,4),
    ordem integer,
    tipo character(20)
);


ALTER TABLE public.eventos_folha OWNER TO postgres;

--
-- Name: eventos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.eventos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eventos_id_seq OWNER TO postgres;

--
-- Name: eventos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.eventos_id_seq OWNED BY public.eventos.id;


--
-- Name: exc_entidade; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.exc_entidade (
    exc_entidade_id integer NOT NULL,
    exc_entidade_entidade integer,
    exc_entidade_sdc integer,
    exc_entidade_desenho integer,
    exc_importado_pelo_sistema integer
);


ALTER TABLE public.exc_entidade OWNER TO postgres;

--
-- Name: exc_entidade_exc_entidade_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.exc_entidade_exc_entidade_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.exc_entidade_exc_entidade_id_seq OWNER TO postgres;

--
-- Name: exc_entidade_exc_entidade_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.exc_entidade_exc_entidade_id_seq OWNED BY public.exc_entidade.exc_entidade_id;


--
-- Name: exc_produto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.exc_produto (
    exc_produto_id integer NOT NULL,
    exc_produto_produto integer,
    exc_produto_sdc integer,
    exc_produto_desenho integer,
    exc_produto_liberacao date,
    exc_produto_nao_liberacao date,
    exc_produto_qtde_padrao numeric(7,2) DEFAULT 0,
    exc_importado_pelo_sistema integer
);


ALTER TABLE public.exc_produto OWNER TO postgres;

--
-- Name: exc_produto_exc_produto_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.exc_produto_exc_produto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.exc_produto_exc_produto_id_seq OWNER TO postgres;

--
-- Name: exc_produto_exc_produto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.exc_produto_exc_produto_id_seq OWNED BY public.exc_produto.exc_produto_id;


--
-- Name: expira; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.expira (
    exp_id integer NOT NULL,
    exp_chave character(10),
    exp_usou integer
);


ALTER TABLE public.expira OWNER TO postgres;

--
-- Name: expira_exp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.expira_exp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.expira_exp_id_seq OWNER TO postgres;

--
-- Name: expira_exp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.expira_exp_id_seq OWNED BY public.expira.exp_id;


--
-- Name: favoritos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.favoritos (
    favoritos_id integer NOT NULL,
    favoritos_usuario integer,
    favoritos_funcao character(50),
    favoritos_tarefa character(80),
    favoritos_acessos integer,
    favoritos_data date
);


ALTER TABLE public.favoritos OWNER TO postgres;

--
-- Name: favoritos_favoritos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.favoritos_favoritos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.favoritos_favoritos_id_seq OWNER TO postgres;

--
-- Name: favoritos_favoritos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.favoritos_favoritos_id_seq OWNED BY public.favoritos.favoritos_id;


--
-- Name: fcp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fcp (
    fcp_id integer NOT NULL,
    fcp_ncm character(20),
    fcp_uf character(2),
    fcp_aliquota1 numeric(18,2),
    fcp_aliquota2 numeric(18,2),
    fcp_aliquota3 numeric(18,2)
);


ALTER TABLE public.fcp OWNER TO postgres;

--
-- Name: fcp_fcp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fcp_fcp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fcp_fcp_id_seq OWNER TO postgres;

--
-- Name: fcp_fcp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fcp_fcp_id_seq OWNED BY public.fcp.fcp_id;


--
-- Name: finalidade_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.finalidade_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.finalidade_id_seq OWNER TO postgres;

--
-- Name: finalidade; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.finalidade (
    id integer DEFAULT nextval('public.finalidade_id_seq'::regclass) NOT NULL,
    descricao character(50),
    finalidade_capa text,
    tipo integer,
    tema_bolinha integer,
    cor_bolinha text,
    idbolinha character(50),
    cor_texto character(20)
);


ALTER TABLE public.finalidade OWNER TO postgres;

--
-- Name: fluxo_fixo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fluxo_fixo (
    flx_id integer NOT NULL,
    flx_data date,
    flx_produto integer,
    flx_usuario integer,
    flx_ativo boolean DEFAULT true,
    flx_servico integer
);


ALTER TABLE public.fluxo_fixo OWNER TO postgres;

--
-- Name: fluxo_fixo_flx_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fluxo_fixo_flx_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fluxo_fixo_flx_id_seq OWNER TO postgres;

--
-- Name: fluxo_fixo_flx_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fluxo_fixo_flx_id_seq OWNED BY public.fluxo_fixo.flx_id;


--
-- Name: fluxo_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fluxo_item (
    flxi_id integer NOT NULL,
    flxi_flx_id integer,
    flxi_ordem integer,
    flxi_cor integer,
    flxi_receita integer,
    flxi_estagio integer,
    flxi_tempo integer,
    flxi_observa character(150),
    flxi_grupomaquina_id integer,
    flxi_exiger_apontamento character(1) DEFAULT 'N'::bpchar,
    flxi_geral_individual character(1),
    flxi_etapa character(1),
    flxi_metros_minuto numeric(20,2),
    flxi_passadas integer
);


ALTER TABLE public.fluxo_item OWNER TO postgres;

--
-- Name: fluxo_item_flxi_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fluxo_item_flxi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fluxo_item_flxi_id_seq OWNER TO postgres;

--
-- Name: fluxo_item_flxi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fluxo_item_flxi_id_seq OWNED BY public.fluxo_item.flxi_id;


--
-- Name: fnc_comentarios_fnc_comentarios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fnc_comentarios_fnc_comentarios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fnc_comentarios_fnc_comentarios_id_seq OWNER TO postgres;

--
-- Name: fnc_comentarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fnc_comentarios (
    fnc_comentarios_id integer DEFAULT nextval('public.fnc_comentarios_fnc_comentarios_id_seq'::regclass) NOT NULL,
    fnc_comentarios_fnc_id integer,
    fnc_comentarios_item integer,
    fnc_comentarios_usuario integer,
    fnc_comentarios_data character(10),
    fnc_comentarios_hora character(10),
    fnc_comentarios_comentario character(300),
    fnc_comentarios_ativo boolean DEFAULT true,
    fnc_comentarios_tipo_setor character(40),
    fnc_comentarios_tipo_solucao integer
);


ALTER TABLE public.fnc_comentarios OWNER TO postgres;

--
-- Name: fnc_creditos_fcre_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fnc_creditos_fcre_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fnc_creditos_fcre_id_seq OWNER TO postgres;

--
-- Name: fnc_creditos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fnc_creditos (
    fcre_id integer DEFAULT nextval('public.fnc_creditos_fcre_id_seq'::regclass) NOT NULL,
    fcre_fnc_id integer,
    fcre_idcliente integer,
    fcre_tipo character(1),
    fcre_data date,
    fcre_valor numeric(18,2),
    fcre_idusuario integer,
    fcre_observacoes character(400),
    fcre_obs_sistema character(400),
    fcre_romaneio character(10)
);


ALTER TABLE public.fnc_creditos OWNER TO postgres;

--
-- Name: fnc_fixo_fnc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fnc_fixo_fnc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fnc_fixo_fnc_id_seq OWNER TO postgres;

--
-- Name: fnc_fixo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fnc_fixo (
    fnc_id integer DEFAULT nextval('public.fnc_fixo_fnc_id_seq'::regclass) NOT NULL,
    fnc_data date,
    fcn_hora character(10),
    fnc_user integer,
    fnc_observacao character(300),
    fnc_nota character(9),
    fnc_nota_id integer,
    fnc_metro_defeito numeric(18,2),
    fnc_os_codigo integer,
    fnc_motivo_id integer,
    fnc_status integer,
    fnc_user_analisou integer,
    fnc_data_analise date,
    fnc_hora_analise character(10),
    fnc_ativo boolean DEFAULT true,
    fnc_tipo integer,
    fnc_codigo character(10),
    fnc_idcliente integer,
    fnc_idrepresentante integer,
    fnc_origem_problema character(30),
    fnc_user_finalizou integer,
    fcn_data_finalizou timestamp without time zone,
    fnc_data_finalizou timestamp without time zone
);


ALTER TABLE public.fnc_fixo OWNER TO postgres;

--
-- Name: fnc_imagem_fnc_imagem_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fnc_imagem_fnc_imagem_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fnc_imagem_fnc_imagem_id_seq OWNER TO postgres;

--
-- Name: fnc_imagem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fnc_imagem (
    fnc_imagem_id integer DEFAULT nextval('public.fnc_imagem_fnc_imagem_id_seq'::regclass) NOT NULL,
    fnc_id_da_fnc integer,
    fnc_imagem_caminho text
);


ALTER TABLE public.fnc_imagem OWNER TO postgres;

--
-- Name: fnc_item_fnci_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fnc_item_fnci_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fnc_item_fnci_id_seq OWNER TO postgres;

--
-- Name: fnc_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fnc_item (
    fnci_id integer DEFAULT nextval('public.fnc_item_fnci_id_seq'::regclass) NOT NULL,
    fnci_fnc_id integer,
    fnci_id_nota integer,
    fnci_id_item integer,
    fnci_unitario numeric(18,2),
    fnci_unidade character(10),
    fnci_valor numeric(18,2),
    fnci_qtde_devolvido numeric(18,2),
    fnci_qtde_vendida numeric(18,2),
    fnci_valor_devolvido numeric(18,2),
    fnci_anotacoes text,
    fnci_imagem integer,
    fnci_percentual_ipi numeric(18,2),
    fnci_valor_total numeric(18,2),
    fnci_valor_total_devolvido numeric(18,2),
    fnci_ipi numeric(18,2),
    fnci_ipi_devolvido numeric(18,2),
    fnci_codigo_item character(2),
    fnci_unitario_pf numeric(18,2),
    fnci_valor_pf numeric(18,2),
    fnci_valor_total_pf_devolvido numeric(18,2)
);


ALTER TABLE public.fnc_item OWNER TO postgres;

--
-- Name: fnc_ocorrencia_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fnc_ocorrencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fnc_ocorrencia_id_seq OWNER TO postgres;

--
-- Name: fnc_ocorrencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fnc_ocorrencia (
    id integer DEFAULT nextval('public.fnc_ocorrencia_id_seq'::regclass) NOT NULL,
    idfnc integer,
    idfnc_item integer,
    idocorrencia integer
);


ALTER TABLE public.fnc_ocorrencia OWNER TO postgres;

--
-- Name: frequencia_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.frequencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.frequencia_id_seq OWNER TO postgres;

--
-- Name: frequencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.frequencia (
    id integer DEFAULT nextval('public.frequencia_id_seq'::regclass) NOT NULL,
    indice integer,
    descricao character(90)
);


ALTER TABLE public.frequencia OWNER TO postgres;

--
-- Name: genero_genero_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.genero_genero_codigo_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.genero_genero_codigo_seq OWNER TO postgres;

--
-- Name: genero; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.genero (
    genero_id integer NOT NULL,
    genero_descricao character(50) NOT NULL,
    genero_codigo character(3) DEFAULT lpad(((nextval('public.genero_genero_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL
);


ALTER TABLE public.genero OWNER TO postgres;

--
-- Name: genero_genero_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.genero_genero_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.genero_genero_id_seq OWNER TO postgres;

--
-- Name: genero_genero_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.genero_genero_id_seq OWNED BY public.genero.genero_id;


--
-- Name: gera_mvto_estoque; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.gera_mvto_estoque
    START WITH 80000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.gera_mvto_estoque OWNER TO postgres;

--
-- Name: grafico_grafico_codigo_grafico_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.grafico_grafico_codigo_grafico_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.grafico_grafico_codigo_grafico_seq OWNER TO postgres;

--
-- Name: grafico; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.grafico (
    grafico_id integer NOT NULL,
    grafico_codigo_grafico character(6) DEFAULT lpad(((nextval('public.grafico_grafico_codigo_grafico_seq'::regclass))::character(6))::text, 6, '0'::text),
    grafico_descricao character(50) NOT NULL,
    grafico_codigo_integracao character(10),
    grafico_padrao character(5) NOT NULL,
    grafico_maquina character(3),
    grafico_imagem text,
    grafico_processo_industrial character(3),
    grafico_observacao text,
    grafico_serie_cor character(3)
);


ALTER TABLE public.grafico OWNER TO postgres;

--
-- Name: grafico_grafico_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.grafico_grafico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.grafico_grafico_id_seq OWNER TO postgres;

--
-- Name: grafico_grafico_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.grafico_grafico_id_seq OWNED BY public.grafico.grafico_id;


--
-- Name: grid_layouts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.grid_layouts_id_seq
    START WITH 13
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.grid_layouts_id_seq OWNER TO postgres;

--
-- Name: grid_layouts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.grid_layouts (
    id integer DEFAULT nextval('public.grid_layouts_id_seq'::regclass) NOT NULL,
    usuario integer,
    tela character varying(100) NOT NULL,
    layout bytea NOT NULL,
    data_salvo timestamp without time zone DEFAULT now()
);


ALTER TABLE public.grid_layouts OWNER TO postgres;

--
-- Name: grupo_encolhimento_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.grupo_encolhimento_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.grupo_encolhimento_codigo_seq OWNER TO postgres;

--
-- Name: grupo_encolhimento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.grupo_encolhimento (
    grupo_encolhimento_id integer NOT NULL,
    grupo_encolhimento_largura_minimo numeric(15,2) DEFAULT 0.00,
    grupo_encolhimento_largura_maximo numeric(15,2) DEFAULT 0.00,
    grupo_encolhimento_comprimento_minimo numeric(15,2) DEFAULT 0.00,
    grupo_encolhimento_comprimento_maximo numeric(15,2) DEFAULT 0.00,
    grupo_encolhimento_codigo character(3) DEFAULT lpad(((nextval('public.grupo_encolhimento_codigo_seq'::regclass))::character(3))::text, 3, '0'::text)
);


ALTER TABLE public.grupo_encolhimento OWNER TO postgres;

--
-- Name: grupo_encolhimento_grupo_encolhimento_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.grupo_encolhimento_grupo_encolhimento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.grupo_encolhimento_grupo_encolhimento_id_seq OWNER TO postgres;

--
-- Name: grupo_encolhimento_grupo_encolhimento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.grupo_encolhimento_grupo_encolhimento_id_seq OWNED BY public.grupo_encolhimento.grupo_encolhimento_id;


--
-- Name: grupo_maquinas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.grupo_maquinas (
    grupo_maquinas_codigo character(4) NOT NULL,
    grupo_maquinas_descricao character(60),
    grupo_maquinas_automatica character(1) DEFAULT 1,
    grupo_maquinas_unidade character(4),
    grupo_maquinas_qtde integer,
    grupo_maquinas_carga integer,
    grupo_maquinas_operacao integer,
    grupo_maquinas_aponta character(1),
    grupo_maquinas_id integer NOT NULL,
    tipo_calculo integer,
    grupo_ordem integer
);


ALTER TABLE public.grupo_maquinas OWNER TO postgres;

--
-- Name: grupo_maquinas_grupo_maquinas_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.grupo_maquinas_grupo_maquinas_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.grupo_maquinas_grupo_maquinas_codigo_seq OWNER TO postgres;

--
-- Name: grupo_maquinas_grupo_maquinas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.grupo_maquinas_grupo_maquinas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.grupo_maquinas_grupo_maquinas_id_seq OWNER TO postgres;

--
-- Name: grupo_maquinas_grupo_maquinas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.grupo_maquinas_grupo_maquinas_id_seq OWNED BY public.grupo_maquinas.grupo_maquinas_id;


--
-- Name: grupo_ocorrencia_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.grupo_ocorrencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.grupo_ocorrencia_id_seq OWNER TO postgres;

--
-- Name: grupo_ocorrencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.grupo_ocorrencia (
    id integer DEFAULT nextval('public.grupo_ocorrencia_id_seq'::regclass) NOT NULL,
    descricao character(60)
);


ALTER TABLE public.grupo_ocorrencia OWNER TO postgres;

--
-- Name: historico_historico_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.historico_historico_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.historico_historico_codigo_seq OWNER TO postgres;

--
-- Name: historico; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historico (
    historico_id integer NOT NULL,
    historico_codigo character(3) DEFAULT lpad(((nextval('public.historico_historico_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    historico_descricao character(100) NOT NULL
);


ALTER TABLE public.historico OWNER TO postgres;

--
-- Name: historico_fci; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historico_fci (
    historico_fci_id integer NOT NULL,
    historico_fci_codigo character(40),
    historico_fci_prodid integer DEFAULT 0,
    historico_fci_corid integer DEFAULT 0,
    historico_fci_data date,
    historico_fci_hora time with time zone,
    historico_fci_usuarioid integer,
    historico_fci_observacao text,
    historico_fci_mediacusto numeric(15,4) DEFAULT 0,
    historico_fci_mediavalorci numeric(15,4) DEFAULT 0,
    historico_fci_mediavalorvenda numeric(15,4) DEFAULT 0,
    historico_fci_porcentagem numeric(15,2) DEFAULT 0,
    historico_fci_hora_lancamento character(20),
    historico_fci_user integer,
    historico_fci_acao character(20),
    historico_fci_obs character(200),
    historico_fci_percentual_papel numeric(18,2)
);


ALTER TABLE public.historico_fci OWNER TO postgres;

--
-- Name: historico_fci_historico_fci_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.historico_fci_historico_fci_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.historico_fci_historico_fci_id_seq OWNER TO postgres;

--
-- Name: historico_fci_historico_fci_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.historico_fci_historico_fci_id_seq OWNED BY public.historico_fci.historico_fci_id;


--
-- Name: historico_historico_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.historico_historico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.historico_historico_id_seq OWNER TO postgres;

--
-- Name: historico_historico_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.historico_historico_id_seq OWNED BY public.historico.historico_id;


--
-- Name: pecas_historico; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pecas_historico (
    hp_id integer NOT NULL,
    hp_tipo character(20),
    hp_documento character(6),
    hp_item character(3),
    hp_usuario character(20),
    hp_data date,
    hp_hora time without time zone,
    hp_autorizado1 character(20),
    hp_autorizado1_data date,
    hp_autorizado1_hora time with time zone,
    hp_autorizado2 character(20),
    hp_autorizado2_data date,
    "hp_autorizado2_hora" time with time zone,
    hp_autorizado3 character(20),
    hp_autorizado3_data date,
    hp_autorizado3_hora time with time zone,
    hp_ocorrencia_id character(3),
    hp_descricao character(80),
    hp_observacao text,
    hp_acao character(100),
    hp_teclas character(20),
    hp_tarefa character(50),
    hp_pecas integer,
    hp_pecas_seq character(2),
    hp_cor_acab_codigo character varying(6),
    hp_revisor_codigo character varying(6),
    hp_maquina_codigo character varying(3),
    hp_pecaid integer,
    hp_metros numeric(15,2),
    hp_peso numeric(15,2),
    hp_data_peca date,
    hp_acao_id integer,
    hp_pecaid_pai integer,
    hp_pd_id integer
);


ALTER TABLE public.pecas_historico OWNER TO postgres;

--
-- Name: TABLE pecas_historico; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.pecas_historico IS 'Históricos dos eventos das peças. Deleção, inserserção de obts e pedidos.';


--
-- Name: historico_pecas_hp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.historico_pecas_hp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.historico_pecas_hp_id_seq OWNER TO postgres;

--
-- Name: historico_pecas_hp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.historico_pecas_hp_id_seq OWNED BY public.pecas_historico.hp_id;


--
-- Name: horas_padrao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.horas_padrao_id_seq
    START WITH 7
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.horas_padrao_id_seq OWNER TO postgres;

--
-- Name: horas_padrao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.horas_padrao (
    id integer DEFAULT nextval('public.horas_padrao_id_seq'::regclass) NOT NULL,
    dia_semana character(3),
    inicio character(5),
    final character(5)
);


ALTER TABLE public.horas_padrao OWNER TO postgres;

--
-- Name: icms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.icms (
    icms_id integer NOT NULL,
    icms_empresa integer,
    icms_tabela character(60),
    icms_codigo integer NOT NULL
);


ALTER TABLE public.icms OWNER TO postgres;

--
-- Name: icms01; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.icms01 (
    icms01_id integer NOT NULL,
    icms01_id_tabela integer,
    icms01_empresa integer,
    icms01_uf character(2),
    icms01_aliquota numeric(10,2),
    icms01_codigo_tabela integer,
    icms01_reducao numeric(5,2) DEFAULT 0
);


ALTER TABLE public.icms01 OWNER TO postgres;

--
-- Name: icms01_icms01_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.icms01_icms01_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.icms01_icms01_id_seq OWNER TO postgres;

--
-- Name: icms01_icms01_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.icms01_icms01_id_seq OWNED BY public.icms01.icms01_id;


--
-- Name: icms_icms_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.icms_icms_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.icms_icms_codigo_seq OWNER TO postgres;

--
-- Name: icms_icms_codigo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.icms_icms_codigo_seq OWNED BY public.icms.icms_codigo;


--
-- Name: icms_icms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.icms_icms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.icms_icms_id_seq OWNER TO postgres;

--
-- Name: icms_icms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.icms_icms_id_seq OWNED BY public.icms.icms_id;


--
-- Name: item_simula; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.item_simula (
    item_simula_id integer NOT NULL,
    item_simula_aa50item integer,
    item_simula_sequencia integer,
    item_simula_descricao character(100),
    item_simula_data character(20),
    item_simula_user integer
);


ALTER TABLE public.item_simula OWNER TO postgres;

--
-- Name: item_simula_item_simula_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.item_simula_item_simula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.item_simula_item_simula_id_seq OWNER TO postgres;

--
-- Name: item_simula_item_simula_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.item_simula_item_simula_id_seq OWNED BY public.item_simula.item_simula_id;


--
-- Name: lancamento_bancario_lb_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lancamento_bancario_lb_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lancamento_bancario_lb_id_seq OWNER TO postgres;

--
-- Name: lancamento_bancario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lancamento_bancario (
    lb_id integer DEFAULT nextval('public.lancamento_bancario_lb_id_seq'::regclass) NOT NULL,
    lb_bco_id integer,
    lb_data date,
    lb_hora time without time zone,
    lb_obs_sistema text,
    lb_obs text,
    lb_duplicata_id integer,
    lb_nf_id integer,
    lb_valor numeric(18,2),
    lb_entsai integer,
    lb_iduser integer,
    lb_credito_debito character(1),
    lb_plano_de_conta_id integer,
    lb_classificacao_id integer,
    lb_tipo_movto integer,
    lb_empresa_id integer,
    lb_favorecido_id integer,
    lb_favorecido text,
    lb_historico text,
    lb_data_baixa date,
    lb_data_sistema date,
    lb_previsao boolean DEFAULT false,
    lb_descontos_id integer,
    lc_duplicata_id integer
);


ALTER TABLE public.lancamento_bancario OWNER TO postgres;

--
-- Name: lancamento_bancario_classificacao_lbc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lancamento_bancario_classificacao_lbc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lancamento_bancario_classificacao_lbc_id_seq OWNER TO postgres;

--
-- Name: lancamento_bancario_classificacao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lancamento_bancario_classificacao (
    lbc_id integer DEFAULT nextval('public.lancamento_bancario_classificacao_lbc_id_seq'::regclass) NOT NULL,
    lbc_descricao text
);


ALTER TABLE public.lancamento_bancario_classificacao OWNER TO postgres;

--
-- Name: lancamento_bancario_log_lbl_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lancamento_bancario_log_lbl_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lancamento_bancario_log_lbl_id_seq OWNER TO postgres;

--
-- Name: lancamento_bancario_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lancamento_bancario_log (
    lbl_id integer DEFAULT nextval('public.lancamento_bancario_log_lbl_id_seq'::regclass) NOT NULL,
    lbl_iduser integer,
    lbl_data date,
    lbl_hora character(20),
    lbl_motivo text,
    lbl_obs text,
    lbl_bco_id integer
);


ALTER TABLE public.lancamento_bancario_log OWNER TO postgres;

--
-- Name: lancamento_bancario_tipo_lbt_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lancamento_bancario_tipo_lbt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lancamento_bancario_tipo_lbt_id_seq OWNER TO postgres;

--
-- Name: lancamento_bancario_tipo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lancamento_bancario_tipo (
    lbt_id integer DEFAULT nextval('public.lancamento_bancario_tipo_lbt_id_seq'::regclass) NOT NULL,
    lbt_descricao text
);


ALTER TABLE public.lancamento_bancario_tipo OWNER TO postgres;

--
-- Name: lancamento_ocorrencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lancamento_ocorrencia (
    lo_id integer NOT NULL,
    lo_ordem_id integer,
    lo_metros numeric(15,2),
    lo_peso numeric(15,2),
    lo_data date,
    lo_ocorrencia integer,
    lo_pdi_id integer
);


ALTER TABLE public.lancamento_ocorrencia OWNER TO postgres;

--
-- Name: lancamento_ocorrencia_lo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lancamento_ocorrencia_lo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lancamento_ocorrencia_lo_id_seq OWNER TO postgres;

--
-- Name: lancamento_ocorrencia_lo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lancamento_ocorrencia_lo_id_seq OWNED BY public.lancamento_ocorrencia.lo_id;


--
-- Name: liberacao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.liberacao (
    liberacao_id integer NOT NULL,
    liberacao_usuario integer,
    liberacao_ocorrencia character(3),
    liberacao_observacao text,
    liberacao_nota character(10),
    liberacao_item integer
);


ALTER TABLE public.liberacao OWNER TO postgres;

--
-- Name: liberacao_liberacao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.liberacao_liberacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.liberacao_liberacao_id_seq OWNER TO postgres;

--
-- Name: liberacao_liberacao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.liberacao_liberacao_id_seq OWNED BY public.liberacao.liberacao_id;


--
-- Name: liberacoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.liberacoes (
    lib_id integer NOT NULL,
    lib_usuario_liberador integer,
    lib_data date,
    lib_hora character(10),
    lib_observa character(200),
    lib_flag boolean DEFAULT true NOT NULL,
    lib_usuario_solicitador integer,
    lib_motivo_solicitacao character(200),
    id_campo_pesquisa integer,
    lib_data_solicitacao date,
    lib_hora_solicitacao character(10)
);


ALTER TABLE public.liberacoes OWNER TO postgres;

--
-- Name: liberacoes_lib_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.liberacoes_lib_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.liberacoes_lib_id_seq OWNER TO postgres;

--
-- Name: liberacoes_lib_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.liberacoes_lib_id_seq OWNED BY public.liberacoes.lib_id;


--
-- Name: log_atualizacao_banco_dados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.log_atualizacao_banco_dados (
    labd_idatualizacao integer NOT NULL,
    versao character varying(20) NOT NULL,
    dthratualizacao timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.log_atualizacao_banco_dados OWNER TO postgres;

--
-- Name: log_atualizacao_banco_dados_labd_idatualizacao_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.log_atualizacao_banco_dados_labd_idatualizacao_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_atualizacao_banco_dados_labd_idatualizacao_seq OWNER TO postgres;

--
-- Name: log_atualizacao_banco_dados_labd_idatualizacao_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.log_atualizacao_banco_dados_labd_idatualizacao_seq OWNED BY public.log_atualizacao_banco_dados.labd_idatualizacao;


--
-- Name: lote_333_lte_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lote_333_lte_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lote_333_lte_id_seq OWNER TO postgres;

--
-- Name: lote_apontamento_lta_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lote_apontamento_lta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lote_apontamento_lta_id_seq OWNER TO postgres;

--
-- Name: lote_apontamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lote_apontamento (
    lta_id integer DEFAULT nextval('public.lote_apontamento_lta_id_seq'::regclass) NOT NULL,
    lta_idformula integer,
    lta_formula_descricao character(100),
    lta_os_id integer,
    lta_os_codigo character(20),
    lta_data date,
    lta_hora character(20),
    lta_iduser integer,
    lta_sublote_id integer,
    lta_tbl character(2),
    lta_tipo character(20)
);


ALTER TABLE public.lote_apontamento OWNER TO postgres;

--
-- Name: lote_apontamento_log_lal_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lote_apontamento_log_lal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lote_apontamento_log_lal_id_seq OWNER TO postgres;

--
-- Name: lote_apontamento_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lote_apontamento_log (
    lal_id integer DEFAULT nextval('public.lote_apontamento_log_lal_id_seq'::regclass) NOT NULL,
    lal_os_id integer,
    lal_iduser integer,
    lal_data date,
    lal_hora character(20),
    lal_obs_sistema character(120),
    lal_obs_usuario character(120)
);


ALTER TABLE public.lote_apontamento_log OWNER TO postgres;

--
-- Name: lote_espalmadeira; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lote_espalmadeira (
    lte_id integer DEFAULT nextval('public.lote_333_lte_id_seq'::regclass) NOT NULL,
    lte_idordem integer,
    lte_idlote integer,
    lte_iduser integer,
    lte_datauser date,
    lte_horauser character(20),
    lte_obs character(120),
    lte_ativo boolean DEFAULT true,
    lte_iduserdesativou integer,
    lte_datadesativou date,
    lte_horadesativou character(20),
    lte_motivodesativou character(120)
);


ALTER TABLE public.lote_espalmadeira OWNER TO postgres;

--
-- Name: lote_log_llog_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lote_log_llog_id_seq
    START WITH 46
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lote_log_llog_id_seq OWNER TO postgres;

--
-- Name: lote_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lote_log (
    llog_id integer DEFAULT nextval('public.lote_log_llog_id_seq'::regclass) NOT NULL,
    llog_lote_id integer,
    llog_iduser integer,
    llog_data date,
    llog_hora character(20),
    llog_obs text,
    llog_status integer,
    llog_tipo_controle integer,
    llog_metodo integer,
    llog_criterio integer,
    llog_tipo character(50),
    llog_os_id integer
);


ALTER TABLE public.lote_log OWNER TO postgres;

--
-- Name: lote_produto_lote_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lote_produto_lote_id_seq
    START WITH 44
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lote_produto_lote_id_seq OWNER TO postgres;

--
-- Name: lote_produto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lote_produto (
    lote_id integer DEFAULT nextval('public.lote_produto_lote_id_seq'::regclass) NOT NULL,
    lote_entidade integer,
    lote_do_fornecedor character(60),
    lote_data date,
    lote_hora character(20),
    lote_nota_numero_doc character(12),
    lote_nota_id integer,
    lote_obs character(150),
    lote_iduser integer,
    lote_idproduto integer,
    lote_iditem integer,
    lote_data_lote date,
    lote_gerou_etiqueta character(60),
    lote_status integer,
    lote_status_data date,
    lote_status_hora character(20),
    lote_status_observacao text,
    lote_status_iduser integer,
    lote_validade date,
    lote_depositoid integer,
    lote_enderecoid integer,
    lote_codigo character(20)
);


ALTER TABLE public.lote_produto OWNER TO postgres;

--
-- Name: lote_sublote_lts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lote_sublote_lts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lote_sublote_lts_id_seq OWNER TO postgres;

--
-- Name: lote_sublote; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lote_sublote (
    lts_id integer DEFAULT nextval('public.lote_sublote_lts_id_seq'::regclass) NOT NULL,
    lts_codigo character(15),
    lts_data date,
    lts_hora character(20),
    lts_iduser integer,
    lts_descricao character(100),
    lts_produto_base integer,
    lts_validadeinicial date,
    lts_validadefinal date
);


ALTER TABLE public.lote_sublote OWNER TO postgres;

--
-- Name: lote_sublote_item_lsi_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lote_sublote_item_lsi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lote_sublote_item_lsi_id_seq OWNER TO postgres;

--
-- Name: lote_sublote_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lote_sublote_item (
    lsi_id integer DEFAULT nextval('public.lote_sublote_item_lsi_id_seq'::regclass) NOT NULL,
    lsi_sublote_id integer,
    lsi_produtoid integer,
    lsi_produtodescricao text,
    lsi_itemid integer,
    lsi_itemdescricao text,
    lsi_qtde numeric(18,4),
    lsi_qtde_aplicada numeric(18,4),
    lsi_lote_mp integer,
    lsi_lote_sl integer
);


ALTER TABLE public.lote_sublote_item OWNER TO postgres;

--
-- Name: maquinas_maquinas_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.maquinas_maquinas_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.maquinas_maquinas_codigo_seq OWNER TO postgres;

--
-- Name: maquinas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maquinas (
    maquinas_grupo character(4),
    maquinas_sub_grupo character(3),
    maquinas_codigo character(3) DEFAULT lpad(((nextval('public.maquinas_maquinas_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    maquinas_imobilizado character(15),
    maquinas_modelo character(50),
    maquinas_num_fabricacao character(15),
    maquinas_data_fabricacao date,
    maquinas_fabricante character(60),
    maquinas_unidade_medida character(4),
    maquinas_manutencao numeric(16,2),
    maquinas_temperatura_max integer,
    maquinas_pressao_ar integer,
    maquinas_pressao_vapor integer,
    maquinas__pressao_agua integer,
    maquinas_pressao_trabalho integer,
    maquinas__tensao integer,
    maquinas__potencia_kva integer,
    maquinas_potencia_kw integer,
    maquinas_amper integer,
    maquinas_pressao_vareta integer,
    maquinas_id integer NOT NULL,
    maquinas_descricao character(80) NOT NULL,
    maquinas_carga_minima integer,
    maquinas_carga_maxima integer,
    maquinas_ccusto character(7),
    maquinas_rel_banho numeric(15,4) DEFAULT 0.0000,
    maquinas_volume_maximo numeric(5,0) DEFAULT 0,
    maquinas_pickup numeric(3,0) DEFAULT 0,
    maquinas_foulard numeric(5,0) DEFAULT 0,
    maquinas_peso_minimo numeric(5,0) DEFAULT 0,
    maquinas_peso_maximo numeric(5,0) DEFAULT 0,
    maquinas_habilita_balanca character(1),
    maquinas_velocidade numeric(7,2),
    maquinas_fundo integer,
    maquinas_balanca smallint,
    maquinas_databits smallint,
    maquinas_parity smallint,
    maquinas_handshaking smallint,
    maquinas_stopbits smallint,
    maquinas_timeout integer,
    maquinas_baud integer,
    maquinas_portaserial character varying(5),
    maquinas_reprocesso character varying(1) DEFAULT 'N'::character varying,
    maquinas_grupo_id integer,
    maquinas_ccusto_id integer,
    maquinas_capacidade_de_trabalho_horas integer,
    maquinas_domingo integer DEFAULT 0,
    maquinas_segunda integer DEFAULT 0,
    maquinas_terca integer DEFAULT 0,
    maquinas_quarta integer DEFAULT 0,
    maquinas_quinta integer DEFAULT 0,
    maquinas_sexta integer DEFAULT 0,
    maquinas_sabado integer DEFAULT 0,
    maquinas_horas_disponiveis integer,
    maquinas_empresa_id integer
);


ALTER TABLE public.maquinas OWNER TO postgres;

--
-- Name: maquinas_capacidade; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maquinas_capacidade (
    mcp_id integer NOT NULL,
    mcp_maquina_id integer,
    mcp_grupo_id integer,
    mcp_rolo_maximo integer,
    mcp_rolo_minimo integer,
    mcp_kg_minimo numeric(18,2),
    mcp_kg_maximo numeric(18,2),
    mcp_relacao_banho numeric(18,2),
    mcp_absorcao integer,
    mcp_rpm integer,
    mcp_pressao_jato real,
    mcp_temperatura real,
    mcp_velocidade_molinete integer,
    mcp_giros_cordas integer,
    mcp_unidade_medida character(2),
    mcp_produto_id integer,
    mcp_cor_id integer,
    mcp_pickup integer,
    mcp_volume real,
    mcp_peso real,
    mcp_fundo real,
    mcp_cab1_temp1 numeric(18,2),
    mcp_cab1_temp2 numeric(18,2),
    mcp_cab1_temp3 numeric(18,2),
    mcp_cab2_temp1 numeric(18,2),
    mcp_cab2_temp2 numeric(18,2),
    mcp_cab2_temp3 numeric(18,2),
    mcp_cab3_temp1 numeric(18,2),
    mcp_cab3_temp2 numeric(18,2),
    mcp_cab3_temp3 numeric(18,2)
);


ALTER TABLE public.maquinas_capacidade OWNER TO postgres;

--
-- Name: maquinas_capacidade_mcp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.maquinas_capacidade_mcp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.maquinas_capacidade_mcp_id_seq OWNER TO postgres;

--
-- Name: maquinas_capacidade_mcp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.maquinas_capacidade_mcp_id_seq OWNED BY public.maquinas_capacidade.mcp_id;


--
-- Name: maquinas_maquinas_serial_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.maquinas_maquinas_serial_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.maquinas_maquinas_serial_seq OWNER TO postgres;

--
-- Name: maquinas_maquinas_serial_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.maquinas_maquinas_serial_seq OWNED BY public.maquinas.maquinas_id;


--
-- Name: maquinas_regulagem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maquinas_regulagem (
    maquinas_regulagem_grupo character(3),
    maquinas_regulagem_sub character(3),
    maquinas_regulagem_maq character(3),
    maquinas_regulagem_serial integer NOT NULL,
    maquinas_regulagem_sequencia character(2),
    maquinas_regulagem_ativa character(1),
    maquinas_regulagem_descricao text
);


ALTER TABLE public.maquinas_regulagem OWNER TO postgres;

--
-- Name: maquinas_regulagem_maquinas_regulagem_serial_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.maquinas_regulagem_maquinas_regulagem_serial_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.maquinas_regulagem_maquinas_regulagem_serial_seq OWNER TO postgres;

--
-- Name: maquinas_regulagem_maquinas_regulagem_serial_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.maquinas_regulagem_maquinas_regulagem_serial_seq OWNED BY public.maquinas_regulagem.maquinas_regulagem_serial;


--
-- Name: menu; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.menu (
    id integer NOT NULL,
    idmodulo integer,
    item character(10),
    descricao character(50),
    nivelmenu character(15),
    icone character(50),
    nomeform character(50),
    ativo character(1)
);


ALTER TABLE public.menu OWNER TO postgres;

--
-- Name: menu_base_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.menu_base_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.menu_base_id_seq OWNER TO postgres;

--
-- Name: menu_base; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.menu_base (
    id integer DEFAULT nextval('public.menu_base_id_seq'::regclass) NOT NULL,
    descricao character(150) DEFAULT NULL::bpchar,
    modulo character(100) DEFAULT NULL::bpchar,
    html text,
    ordem integer,
    agrupador character(1) DEFAULT NULL::bpchar
);


ALTER TABLE public.menu_base OWNER TO postgres;

--
-- Name: menu_desktop_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.menu_desktop_id_seq
    START WITH 980
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.menu_desktop_id_seq OWNER TO postgres;

--
-- Name: menu_desktop; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.menu_desktop (
    id integer DEFAULT nextval('public.menu_desktop_id_seq'::regclass) NOT NULL,
    empresa integer,
    codigo_programa character(100),
    nome_programa character(200),
    habilitado boolean
);


ALTER TABLE public.menu_desktop OWNER TO postgres;

--
-- Name: menu_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.menu_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.menu_id_seq OWNER TO postgres;

--
-- Name: menu_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.menu_id_seq OWNED BY public.menu.id;


--
-- Name: mkf; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mkf (
    mkf_id integer NOT NULL,
    mkf_nometabela character(80),
    mkf_data_validade date,
    mkf_data_criacao date,
    mkf_data_revisao date,
    mkf_observacoes character(300),
    mkf_indice_coeficiente integer,
    mkf_coeficiente numeric(15,4),
    mkf_seq character(2),
    mkf_compor_custos boolean,
    mkf_fator integer,
    mkf_padrao boolean DEFAULT false,
    mkf_coeficiente2 numeric(15,4),
    mkf_coeficiente_sem_icms numeric(15,4)
);


ALTER TABLE public.mkf OWNER TO postgres;

--
-- Name: mkf_mkf_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mkf_mkf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mkf_mkf_id_seq OWNER TO postgres;

--
-- Name: mkf_mkf_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mkf_mkf_id_seq OWNED BY public.mkf.mkf_id;


--
-- Name: mki; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mki (
    mki_id integer NOT NULL,
    mki_seq character(3),
    mki_categoria character(80),
    mki_percentual numeric(5,2) DEFAULT 0.00,
    mki_valor numeric(15,6) DEFAULT 0.000000,
    mki_mkf_id integer,
    mki_mkf_nometabela character(80),
    mki_permite_alterar boolean DEFAULT true,
    mki_calcula_preco_custo character(15)
);


ALTER TABLE public.mki OWNER TO postgres;

--
-- Name: mki_mki_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mki_mki_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mki_mki_id_seq OWNER TO postgres;

--
-- Name: mki_mki_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mki_mki_id_seq OWNED BY public.mki.mki_id;


--
-- Name: moeda_cotacao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.moeda_cotacao (
    moeda_cotacao_id integer NOT NULL,
    moeda_cotacao_tipo integer,
    moeda_cotacao_data date,
    moeda_cotacao_valor numeric(15,4)
);


ALTER TABLE public.moeda_cotacao OWNER TO postgres;

--
-- Name: moeda_cotacao_moeda_cotacao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.moeda_cotacao_moeda_cotacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.moeda_cotacao_moeda_cotacao_id_seq OWNER TO postgres;

--
-- Name: moeda_cotacao_moeda_cotacao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.moeda_cotacao_moeda_cotacao_id_seq OWNED BY public.moeda_cotacao.moeda_cotacao_id;


--
-- Name: motivo_uso_producao_motivo_uso_producao_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.motivo_uso_producao_motivo_uso_producao_codigo_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.motivo_uso_producao_motivo_uso_producao_codigo_seq OWNER TO postgres;

--
-- Name: motivo_uso_producao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.motivo_uso_producao (
    motivo_uso_producao_id integer NOT NULL,
    motivo_uso_producao_descricao character(50),
    motivo_uso_producao_codigo character(3) DEFAULT lpad(((nextval('public.motivo_uso_producao_motivo_uso_producao_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL
);


ALTER TABLE public.motivo_uso_producao OWNER TO postgres;

--
-- Name: motivo_uso_producao_motivo_uso_producao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.motivo_uso_producao_motivo_uso_producao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.motivo_uso_producao_motivo_uso_producao_id_seq OWNER TO postgres;

--
-- Name: motivo_uso_producao_motivo_uso_producao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.motivo_uso_producao_motivo_uso_producao_id_seq OWNED BY public.motivo_uso_producao.motivo_uso_producao_id;


--
-- Name: motivos_bloqueios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.motivos_bloqueios (
    mot_id integer NOT NULL,
    mot_descricao character(70),
    mot_financeiro boolean DEFAULT false,
    mot_comercial boolean DEFAULT false,
    mot_producao boolean DEFAULT false,
    mot_pcp boolean DEFAULT false,
    mot_diretoria boolean DEFAULT false
);


ALTER TABLE public.motivos_bloqueios OWNER TO postgres;

--
-- Name: motivos_bloqueios_mot_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.motivos_bloqueios_mot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.motivos_bloqueios_mot_id_seq OWNER TO postgres;

--
-- Name: motivos_bloqueios_mot_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.motivos_bloqueios_mot_id_seq OWNED BY public.motivos_bloqueios.mot_id;


--
-- Name: mov_estoque; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mov_estoque (
    movest_id integer NOT NULL,
    movest_prod_id integer NOT NULL,
    movest_item_id integer,
    movest_tipo_movimento integer NOT NULL,
    movest_movimentacao integer NOT NULL,
    movest_qtde numeric(15,3),
    movest_data_mov date,
    movest_data_sistema date,
    movest_usuario character(100),
    movest_usuario_id integer,
    movest_obs character(100),
    movest_deposito_id integer,
    movest_tipo_documento integer,
    movest_documento character(15),
    movest_nf_item_id integer,
    movest_pd_item_id integer,
    movest_cai_id integer,
    movest_pec_id integer,
    movest_lote character(10),
    movest_os_id integer,
    movest_pbi_id integer,
    movest_empenhado boolean DEFAULT false,
    movest_od_id integer,
    movest_centro_custo integer,
    movest_valor numeric(18,4),
    movest_obs_sistema character(300),
    movest_retorno_confeccao integer
);


ALTER TABLE public.mov_estoque OWNER TO postgres;

--
-- Name: mov_estoque_movest_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mov_estoque_movest_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mov_estoque_movest_id_seq OWNER TO postgres;

--
-- Name: mov_estoque_movest_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mov_estoque_movest_id_seq OWNED BY public.mov_estoque.movest_id;


--
-- Name: moveis_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.moveis_id_seq
    START WITH 91
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.moveis_id_seq OWNER TO postgres;

--
-- Name: moveis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.moveis (
    id integer DEFAULT nextval('public.moveis_id_seq'::regclass) NOT NULL,
    movel character(200)
);


ALTER TABLE public.moveis OWNER TO postgres;

--
-- Name: movimentacao_roteiro; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.movimentacao_roteiro (
    movimentacao_roteiro_id integer NOT NULL,
    movimentacao_roteiro_obt character(6),
    movimentacao_roteiro_obt_data date,
    movimentacao_roteiro_roteiro_id integer,
    movimentacao_roteiro_roteiro_tempo_maquina character(7),
    movimentacao_roteiro_roteiro_temo_homem character(7),
    movimentacao_roteiro_roteiro_voltas integer,
    movimentacao_roteiro_roteiro_velocidade numeric(8,2),
    movimentacao_roteiro_roteiro_ordem numeric(2,0),
    movimentacao_roteiro_estagio_cod character(2),
    movimentacao_roteiro_estagio_descricao character(100),
    movimentacao_roteiro_temperatura numeric(5,3),
    movimentacao_roteiro_operador_codigo character(5),
    movimentacao_roteiro_operador_descricao character(80),
    movimentacao_roteiro_turno_id integer,
    movimentacao_roteiro_usuario character(30),
    movimentacao_roteiro_data_sistema date,
    movimentacao_roteiro_data_inicial date,
    movimentacao_roteiro_data_final date,
    movimentacao_roteiro_hora_final time without time zone,
    movimentacao_roteiro_hora_inicial time without time zone
);


ALTER TABLE public.movimentacao_roteiro OWNER TO postgres;

--
-- Name: movimentacao_roteiro_movimentacao_roteiro_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.movimentacao_roteiro_movimentacao_roteiro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.movimentacao_roteiro_movimentacao_roteiro_id_seq OWNER TO postgres;

--
-- Name: movimentacao_roteiro_movimentacao_roteiro_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.movimentacao_roteiro_movimentacao_roteiro_id_seq OWNED BY public.movimentacao_roteiro.movimentacao_roteiro_id;


--
-- Name: msg; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.msg (
    msg_id integer NOT NULL,
    msg_user_remetente_id integer,
    msg_user_destino_id integer,
    msg_data date,
    msg_hora time with time zone,
    msg_texto text,
    msg_assunto character(600),
    msg_obs_sistema character(120),
    msg_status integer DEFAULT 0,
    msg_prioridade integer DEFAULT 0,
    msg_hora_mensagem character(10),
    msg_funcao integer
);


ALTER TABLE public.msg OWNER TO postgres;

--
-- Name: msg_msg_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.msg_msg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.msg_msg_id_seq OWNER TO postgres;

--
-- Name: msg_msg_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.msg_msg_id_seq OWNED BY public.msg.msg_id;


--
-- Name: mvta_estoque; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mvta_estoque (
    mvta_estoque_id integer NOT NULL,
    mvta_estoque_produtoid integer,
    mvta_estoque_produtonivel integer,
    mvta_estoque_produtoreferencia character(8),
    mvta_estoque_produtodescricao character(60),
    mvta_estoque_itemid integer,
    mvta_estoque_itemcodigo character(6),
    mvta_estoque_itemnome character(60),
    mvta_estoque_data date,
    mvta_estoque_depid1 integer,
    mvta_estoque_depcodigo1 character(3),
    mvta_estoque_depnome1 character(60),
    mvta_estoque_depid2 integer,
    mvta_estoque_depcodigo2 character(3),
    mvta_estoque_depnome2 character(60),
    mvta_estoque_mvtoid integer,
    mvta_estoque_mvtodescricao character(60),
    mvta_estoque_mvtocodigo character(3),
    mvta_estoque_mvtomov integer,
    mvta_estoque_mvtomovnome character(8),
    mvta_estoque_mvtotipo integer,
    mvta_estoque_mvtotiponome character(25),
    mvta_estoque_qtde numeric(15,4),
    mvta_estoque_obse text,
    mvta_estoque_entidade integer,
    mvta_estoque_usuarioid integer,
    mvta_estoque_datasistema date,
    mvta_estoque_usuarionome character varying(80),
    mvta_estoque_horasistema character(10)
);


ALTER TABLE public.mvta_estoque OWNER TO postgres;

--
-- Name: mvta_estoque_mvta_estoque_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mvta_estoque_mvta_estoque_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mvta_estoque_mvta_estoque_id_seq OWNER TO postgres;

--
-- Name: mvta_estoque_mvta_estoque_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mvta_estoque_mvta_estoque_id_seq OWNED BY public.mvta_estoque.mvta_estoque_id;


--
-- Name: nf_canceladas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nf_canceladas (
    nfcan_id integer NOT NULL,
    nfcan_nf_id integer,
    nfcan_protocolo character(1000),
    nfcan_xml character(1000),
    nfcan_codigostatus integer,
    nfcan_motivostatus character(1000),
    nfcan_usuario integer,
    nfcan_data date,
    nfcan_hora time with time zone,
    nfcan_hora_cancelamento character(60)
);


ALTER TABLE public.nf_canceladas OWNER TO postgres;

--
-- Name: nf_canceladas_nfcan_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nf_canceladas_nfcan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nf_canceladas_nfcan_id_seq OWNER TO postgres;

--
-- Name: nf_canceladas_nfcan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.nf_canceladas_nfcan_id_seq OWNED BY public.nf_canceladas.nfcan_id;


--
-- Name: nf_complememtar; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nf_complememtar (
    nfc_id integer NOT NULL,
    nfc_nf_id integer NOT NULL,
    nfc_chave_nota character(50) NOT NULL
);


ALTER TABLE public.nf_complememtar OWNER TO postgres;

--
-- Name: nf_complememtar_nfc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nf_complememtar_nfc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nf_complememtar_nfc_id_seq OWNER TO postgres;

--
-- Name: nf_complememtar_nfc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.nf_complememtar_nfc_id_seq OWNED BY public.nf_complememtar.nfc_id;


--
-- Name: nf_devolucao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nf_devolucao (
    nfd_id integer NOT NULL,
    nfd_nf_id integer,
    nfd_chave_nota character(50)
);


ALTER TABLE public.nf_devolucao OWNER TO postgres;

--
-- Name: nf_devolucao_nfd_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nf_devolucao_nfd_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nf_devolucao_nfd_id_seq OWNER TO postgres;

--
-- Name: nf_devolucao_nfd_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.nf_devolucao_nfd_id_seq OWNED BY public.nf_devolucao.nfd_id;


--
-- Name: nf_fixa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nf_fixa (
    cliente_cpf_cnpj character(18),
    cliente_tipo_pessoa smallint,
    cliente_nome character(120),
    cliente_ie character(22),
    cliente_logradouro character varying(60),
    cliente_insc_suframa character(9),
    cliente_complemento character varying(60),
    cliente_bairro character varying(60),
    cliente_numero character varying(60),
    cliente_telefone character(25),
    cliente_nm_pais character varying(60),
    cliente_cod_pais character(4),
    cliente_cep character(10),
    cliente_uf character(2),
    cliente_nm_municipio character(60),
    cliente_cod_municipio character(7),
    cliente_email character(80),
    imposto_vbc numeric(15,6) DEFAULT 0.000000,
    imposto_vicms numeric(15,6) DEFAULT 0.000000,
    imposto_vbcst numeric(15,6) DEFAULT 0.000000,
    imposto_vst numeric(15,6) DEFAULT 0.000000,
    imposto_prod numeric(15,6) DEFAULT 0.000000,
    imposto_vfrete numeric(15,6) DEFAULT 0.000000,
    imposto_vseg numeric(15,6) DEFAULT 0.000000,
    imposto_vdesc numeric(15,6) DEFAULT 0.000000,
    imposto_vii numeric(15,6) DEFAULT 0.000000,
    imposto_vipi numeric(15,6) DEFAULT 0.000000,
    imposto_vpis numeric(15,6) DEFAULT 0.000000,
    imposto_vcofins numeric(15,6) DEFAULT 0.000000,
    imposto_voutro numeric(15,6) DEFAULT 0.000000,
    imposto_vnf numeric(15,6) DEFAULT 0.000000,
    nota_uf_emitente character(2),
    nota_dt_emissao date,
    nota_forma_pagto smallint,
    nota_desc_nat_op character(60),
    nota_serie_doc character(3),
    nota_numero_doc character(9),
    nota_forma_emissao smallint,
    nota_tipo_impressao smallint,
    nota_cod_municipio character(7),
    nota_dt_saida_entrad date,
    nota_finalidade_emissao smallint,
    nota_modelo character(2),
    nota_cid_nota_fiscal integer,
    nota_tipo_operacao smallint,
    nota_codigo_acesso character(8),
    nota_chave_acesso character varying(47),
    nota_versao_layout numeric(4,2),
    status_cod_situacao integer,
    status_tipo_entrada character varying(100),
    status_data date,
    status_hora time without time zone,
    status_autorizacao_uso character(100),
    status_autorizacao_uso_cod integer,
    status_deposito_codigo character(3),
    status_empresa_codigo character(3),
    status_cnpj_masc character(20),
    nota_fiscal_cpf_cnpj character(20),
    cliente_cpf_cnpj_masc character(20),
    emitente_codigo character(10),
    transportadora_codigo character(10),
    transportadora_qtd_vol integer,
    transportadora_especie character(30),
    transportadora_marca character(100),
    transportadora_numero_volume character(100),
    transportadora_peso_liquido numeric(15,4),
    transportadora_peso_bruto numeric(15,4),
    transportadora_cnpj character(18),
    transportadora_cnpj_masc character(18),
    nota_natureza character(80),
    nota_cond_pagto character(10),
    transportadora_tipo_frete character(1),
    transportadora_via_transporte character(10),
    imposto_acrescimos numeric(15,4),
    imposto_itens numeric(15,4),
    imposto_base_dif numeric(15,4),
    imposto_base_icms_sub numeric(15,4),
    imposto_base_icms numeric(15,4),
    imposto_icms_sub numeric(15,4),
    id_nota_fiscal character(9),
    nota_confirmacao date,
    nota_romaneio character(10),
    nota_metro numeric(15,4),
    imposto_tfrete numeric(15,2),
    usuario_id integer,
    usuario_codigo character(3),
    usuario_nome character(100),
    usuario_data date,
    usuario_hora time without time zone,
    empresa_id integer,
    nf_id integer NOT NULL,
    cliente_codigo character(10),
    nota_tipo_documento character(5),
    cliente_cobranca_logradouro character varying(60),
    cliente_cobranca_complemento character varying(60),
    cliente_cobranca_bairro character varying(60),
    cliente_cobranca_numero character varying(60),
    cliente_cobranca_telefone character(10),
    cliente_cobranca_nm_pais character varying(60),
    cliente_cobranca_cod_pais character(4),
    cliente_cobranca_cep character(10),
    cliente_cobranca_uf character(2),
    cliente_cobranca_nm_municipio character(60),
    cliente_cobranca_cod_municipio character(7),
    cliente_id_pais integer,
    cliente_id_municipio integer,
    cliente_cobranca_id_pais integer,
    cliente_cobranca_id_municipio integer,
    nota_tipo_documento_descricao character(100),
    nota_cfop_codigo character(4),
    nota_cfop_descricao character(100),
    nota_cfop2_codigo character(4),
    nota_cfop2_descricao character(100),
    transportadora2_codigo character(10),
    transportadora2_qtd_vol integer,
    transportadora2_especie character(10),
    transportadora2_marca character(100),
    transportadora2_numero_volume character(100),
    transportadora2_peso_liquido numeric(15,4),
    transportadora2_peso_bruto numeric(15,4),
    transportadora2_cnpj character(18),
    transportadora2_cnpj_masc character(18),
    transportadora_descricao character(100),
    transportadora_motorista character(100),
    transportadora_cpf character(20),
    transportadora2_descricao character(100),
    transportadora2_motorista character(100),
    transportadora2_cpf character(20),
    transportadora_placa_uf character(2),
    transportadora_placa character(7),
    transportadora_placa2_uf character(2),
    transportadora_placa2 character(7),
    transportadora2_placa_uf character(2),
    transportadora2_placa character(7),
    transportadora2_placa2_uf character(2),
    transportadora2_placa2 character(7),
    transportadora_antt character(17),
    transportadora2_antt character(17),
    cliente_codpagto character(4),
    cliente_codpagto_nome character(300),
    cliente_repres1 character(10),
    cliente_repres1n character(60),
    cliente_repres1comi numeric(6,2),
    cliente_repres2 character(10),
    cliente_repres2n character(60),
    cliente_repres2comi numeric(6,2),
    cliente_repres3 character(10),
    cliente_repres3n character(60),
    cliente_repres3comi numeric(6,2),
    nota_hora_ent_sai time without time zone,
    transportadora_id integer,
    transportadora2_id integer,
    cliente_repres1id integer,
    cliente_repres2id integer,
    cliente_repres3id integer,
    nota_cfop_id integer,
    nota_cfop2_id integer,
    nota_tipo_documento_na character(6),
    cliente_codpagto_id integer,
    duplicata_total numeric(15,2),
    nota_saen character(1),
    nota_obs_doc_interno text,
    nota_obs_dadosadcionais text,
    nota_obs_reservadofisco text,
    nota_obs_sistema text,
    nfe_xml character(800),
    cliente_id integer,
    nota_tpamb character(2),
    nota_chnfe character(60),
    nota_dhrecbto date,
    nota_nprot character(30),
    nota_digval character(100),
    nota_cstat character(100),
    nota_xmotivo character(100),
    nota_veraplic character(10),
    transportadora_endereco character(100),
    transportadora_municipio character(100),
    transportadora_uf character(2),
    transportadora_ie character(18),
    transportadora_tipo_frete_nome character(30),
    marcar character(1),
    nota_bancos_codigo character(3),
    nota_bancos_nome character(60),
    nota_situacao_faturamento character(20),
    nota_email_enviado character(150),
    tipoperc integer DEFAULT 0,
    imposto_maodeobra numeric(15,2) DEFAULT 0.00,
    imposto_insumos numeric(15,2) DEFAULT 0.00,
    imposto_cofins numeric(15,2) DEFAULT 0.00,
    imposto_pis numeric(15,2) DEFAULT 0.00,
    pes_fat numeric(15,2),
    qtd_fat numeric(15,2),
    um_fat character(6),
    nf_volume integer,
    nota_seq_carta_correcao integer DEFAULT 0,
    nota_doc_importacao_data date,
    nota_tipo_importacao integer,
    nota_local_desembaraco character(250),
    nota_data_desembaraco date,
    nota_doc_importacao character(15),
    nota_uf_desembaraco character(2),
    nota_taxa_dolar numeric(5,4),
    nota_adquirente character(10),
    nota_ccd_id integer,
    nota_peso_rateio_frete numeric(15,2) DEFAULT 0.00,
    nota_cce_impressa smallint,
    nota_vr_ii numeric(9,2),
    nota_tx_siscomex numeric(9,2),
    nota_vr_iof numeric(9,2),
    cliente_entrega_logradouro character varying(60),
    cliente_entrega_complemento character varying(60),
    cliente_entrega_bairro character varying(60),
    cliente_entrega_numero character varying(60),
    cliente_entrega_uf character(2),
    cliente_entrega_nm_municipio character(60),
    cliente_entrega_cod_municipio character(7),
    cliente_entrega_email character(80),
    cliente_entrega_cep character(10),
    nota_email_espelhamento_representante character(150),
    nota_plc_id integer,
    nf_tipo_entrada_xml_manual character(3),
    indfinal integer,
    indiedest integer,
    nota_tipo_mvto integer,
    nf_indicador_presenca character(1),
    nf_iddest integer,
    nf_pedido character(15),
    nfe_finalidade_complemento integer
);


ALTER TABLE public.nf_fixa OWNER TO postgres;

--
-- Name: nf_fixa_cce; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nf_fixa_cce (
    cce_id integer NOT NULL,
    cce_nf_id integer NOT NULL,
    cce_nr_envio smallint DEFAULT 0 NOT NULL,
    cce_descricao character varying(1000) NOT NULL,
    cce_dtcorrecao timestamp without time zone DEFAULT now() NOT NULL,
    cce_chave_acesso_nfe character varying(50) NOT NULL
);


ALTER TABLE public.nf_fixa_cce OWNER TO postgres;

--
-- Name: nf_fixa_cce_cce_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nf_fixa_cce_cce_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nf_fixa_cce_cce_id_seq OWNER TO postgres;

--
-- Name: nf_fixa_cce_cce_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.nf_fixa_cce_cce_id_seq OWNED BY public.nf_fixa_cce.cce_id;


--
-- Name: nf_fixa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nf_fixa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nf_fixa_id_seq OWNER TO postgres;

--
-- Name: nf_fixa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.nf_fixa_id_seq OWNED BY public.nf_fixa.nf_id;


--
-- Name: nf_inutilizadas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nf_inutilizadas (
    id integer NOT NULL,
    ano character(4),
    modelo character(30),
    serie character(30),
    nro_inicial character(12),
    nro_final character(12),
    justificativa character(300),
    data_inutiliza date,
    hora character(10),
    user_id integer,
    retornoxml character(2000)
);


ALTER TABLE public.nf_inutilizadas OWNER TO postgres;

--
-- Name: nf_inutilizadas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nf_inutilizadas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nf_inutilizadas_id_seq OWNER TO postgres;

--
-- Name: nf_inutilizadas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.nf_inutilizadas_id_seq OWNED BY public.nf_inutilizadas.id;


--
-- Name: nf_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nf_item (
    id_item integer,
    id integer NOT NULL,
    nfi_codigo_sistema character(60),
    nfi_unidade_sistema character(4),
    nfi_qtd_sistema numeric(15,4),
    nfi_vr_unit_sistema numeric(15,4),
    nfi_id_nota_fiscal character(10),
    nfi_total_sistema numeric(11,2),
    nfi_produto_codigo integer,
    nfi_cor_sistema character(10),
    nfi_ocorrencia boolean DEFAULT false,
    nfi_deposito character(3),
    nfi_item_deposito character(3),
    nfi_entra_programacao character(1) DEFAULT 1,
    nfi_qtd_pecas_rolos_caixas numeric(15,4) DEFAULT 0.0000,
    nfi_qtd_pecas integer DEFAULT 0,
    nfi_total_metros numeric(15,3) DEFAULT 0.000,
    nfi_total_kg numeric(15,3) DEFAULT 0.000,
    nfi_ped_volumes integer DEFAULT 0,
    nfi_ped_metros numeric(15,3) DEFAULT 0.000,
    nfi_ped_kg numeric(15,3) DEFAULT 0.000,
    nfi_codigo character(60),
    nfi_item_ocorrencia character(20),
    nfi_ean character(14),
    nfi_descricao character(120),
    nfi_ncm character(8),
    nfi_ex_tipi character(3),
    nfiv_cfop character(4),
    nfi_un_comercial character(6),
    nfi_qtde_comercial numeric(11,4),
    nfi_vlr_un_comercial numeric(11,4),
    nfi_vlr_total numeric(11,4),
    nfi_ean_trib character(14),
    nfi_un_trib character(6),
    nfi_qtde_un_trib numeric(11,4),
    nfi_vlr_un_trib numeric(11,4),
    nfi_vlr_frete numeric(11,6) DEFAULT 0.000000,
    nfi_vlr_seguro numeric(11,6) DEFAULT 0.000000,
    nfi_vlr_desconto numeric(11,6) DEFAULT 0.000000,
    nfi_nota_fiscal_cpf_cnpj character(14),
    nfiv_produto_id integer,
    nfiv_produto_nivel integer,
    nfiv_produto_referencia character(10),
    nfiv_cor_id integer,
    nfiv_cor_codigo character(6),
    nfiv_volumes integer,
    nfiv_metros numeric(15,4),
    nfiv_peso numeric(15,4),
    nfiv_vlr_unitario numeric(15,4),
    nfiv_unidade_compra character(4),
    nfiv_deposito character(3),
    nfiv_codigo_nota character(10),
    nfiv_nota_id integer,
    nfiv_entidade_codigo character(10),
    nfiv_usuario_id integer,
    nfiv_hora time without time zone,
    nfiv_vlr_total numeric(15,4),
    nfiv_qtde numeric(15,4),
    nfi_id_nota integer,
    nfi_entidade character(10),
    nfiv_volumes_conferido integer,
    nfiv_total_metros numeric(15,3) DEFAULT 0.000,
    nfiv_total_kg numeric(15,3) DEFAULT 0.000,
    nfiv_ped_metros numeric(15,3) DEFAULT 0.000,
    nfiv_ped_kg numeric(15,3) DEFAULT 0.000,
    nfiv_ped_volumes integer DEFAULT 0,
    nfiv_cfop_descricao character(100),
    nfiv_duplicata character(1),
    nfiv_cst_icms character(3),
    nfiv_icms numeric(6,2) DEFAULT 0.00,
    nfiv_cfop_id integer,
    nfiv_livros_fiscais character(1),
    nfiv_operacao_fiscal integer DEFAULT 0,
    nfiv_iss numeric(6,2) DEFAULT 0.00,
    nfiv_substit_tributaria numeric(6,2) DEFAULT 0.00,
    nfiv_reducao_icms numeric(15,2) DEFAULT 0.00000,
    nfiv_dif_aliquota numeric(15,2) DEFAULT 0.000000,
    nfiv_pis numeric(6,2) DEFAULT 0.00,
    nfiv_subtrai_icms_custo integer DEFAULT 0,
    nfiv_natureza_relacionada integer DEFAULT 0,
    nfiv_situacao integer DEFAULT 0,
    nfiv_cod_tributacao_icms integer DEFAULT 0,
    nfiv_icms_cliente_isento numeric(6,2) DEFAULT 0.00,
    nfiv_perc_icms_diferido numeric(6,2) DEFAULT 0.00,
    nfiv_reducao_icms_substit numeric(6,2) DEFAULT 0.00,
    nfiv_cofins numeric(6,2) DEFAULT 0.00,
    nfiv_faturamento integer DEFAULT 0,
    nfiv_observacao text,
    nfiv_movimentacao_estoque character(3),
    nfiv_tem_movimentacao_fisica character(1),
    nfiv_cst_cofins character(3),
    nfiv_cst_csosn character(3),
    nfiv_cst_pis character(3),
    nfiv_csosn numeric(6,2),
    nfiv_maodeobra numeric(15,2) DEFAULT 0.00,
    nfiv_insumos numeric(15,2) DEFAULT 0.00,
    nfiv_calc_maodeobra "char",
    nfiv_tipo character(1),
    nfiv_ipi numeric(6,2) DEFAULT 0,
    nfiv_sub_total numeric(15,6) DEFAULT 0.00,
    nfiv_desc_porcentagem numeric(6,2) DEFAULT 0.00,
    nfiv_desc_valor numeric(15,4) DEFAULT 0.00,
    nfiv_produto_unidade character(4),
    nfiv_qtde_fracionada numeric(15,6) DEFAULT 1,
    nfiv_produto_classificacao_fiscal character(10),
    nfiv_qtde_comprada numeric(15,4),
    nfiv_icms_base_calculo numeric(15,6),
    nfiv_icms_valor numeric(15,6) DEFAULT 0.00,
    nfiv_produto_descricao character(500),
    nfiv_ipi_valor numeric(15,6) DEFAULT 0.00,
    nfiv_cor_descricao character(50),
    nfiv_peso_bruto numeric(15,3) DEFAULT 0.00,
    nfiv_peso_liquido numeric(15,3) DEFAULT 0.00,
    nfiv_icmssobreipi boolean DEFAULT false,
    nfiv_base_icms_sub numeric(15,2),
    nfiv_icms_sub numeric(15,2),
    nfiv_pis_base numeric(15,2) DEFAULT 0.00,
    nfiv_pis_valor numeric(15,2) DEFAULT 0.00,
    nfiv_cofins_base numeric(15,2) DEFAULT 0.00,
    nfiv_cofins_valor numeric(15,2) DEFAULT 0.00,
    nfiv_isentas numeric(15,2) DEFAULT 0.00,
    nfiv_outras numeric(15,2) DEFAULT 0.00,
    nfiv_acabamento character(50),
    nfiv_acabamento_codigo character(3),
    nfiv_orig numeric(11,4) DEFAULT 0.0000,
    nfiv_prod_cliente boolean DEFAULT false,
    nfiv_cod_prod_cliente character(20),
    nfiv_calcula boolean DEFAULT false,
    nfiv_insumos_perc numeric(6,2) DEFAULT 0.00,
    nfiv_maodeobra_perc numeric(6,2) DEFAULT 0.00,
    nfiv_infadprod character(500),
    nfiv_cst_ipi character(3),
    nfi_gramatura_m2 numeric(15,2),
    nfi_rendimento numeric(15,2),
    nfiv_pdi_id integer,
    nfiv_fabricante character(20),
    "nfiv_codANP" integer,
    "nfiv_UF_combustivel" character(2),
    nfiv_fci character(36),
    nfiv_valor_rateio numeric(15,6) DEFAULT 0.00,
    nfiv_fabricante_id integer,
    nfiv_base_ipi numeric(15,2),
    nfiv_cenq character(3),
    nfvi_csosn_valor numeric(18,2),
    nfiv_vbcfcp numeric(18,2),
    nfiv_pfcp numeric(18,2),
    nfiv_bcfcpst numeric(18,2),
    nfiv_fcpst numeric(18,2),
    nfiv_pst numeric(18,2),
    nfiv_vbcfcpstret numeric(18,2),
    nfiv_pfcpstret numeric(18,2),
    nfiv_vfcpstret numeric(18,2),
    nfiv_difal_vbcfcpufdest numeric(18,2),
    nfiv_difal_vfcp numeric(18,2),
    nfiv_difal_vfcpst numeric(18,2),
    nfiv_difal_vfcpstret numeric(18,2),
    nfiv_escala_relevante character(1) DEFAULT 'N'::bpchar,
    nfiv_vfcpst numeric(18,2),
    nfiv_vbcfcpst numeric(18,2),
    nfiv_vfcp numeric(18,2),
    vbcufdest numeric(18,2) DEFAULT 0,
    pfcpufdest numeric(18,2) DEFAULT 0,
    vbcfcpufdest numeric(18,2) DEFAULT 0,
    picmsufdest numeric(18,2) DEFAULT 0,
    picmsinter numeric(18,2) DEFAULT 0,
    picmsinterpart numeric(18,2) DEFAULT 0,
    vfcpufdest numeric(18,2) DEFAULT 0,
    vicmsufdest numeric(18,2) DEFAULT 0,
    vicmsufremet numeric(18,2) DEFAULT 0,
    nfiv_grupo integer,
    nfiv_idorcamento integer,
    nfiv_idambiente integer,
    nfiv_tipo_pedido integer,
    nfiv_data_alterou character(30),
    nfiv_usuario_alterou integer,
    nfiv_qtde_estoque numeric(24,6),
    nfiv_un_estoque character(6),
    valor_aproximado_ibpt numeric(18,2),
    percentual_ibpt numeric(18,2),
    nfiv_cst_cbs_ibs character(3),
    nfiv_cbs_aliquota numeric(18,2),
    nfiv_cbs_reducao numeric(18,2),
    nfiv_cbs_valor numeric(18,2),
    nfiv_ibs_mun_aliquota numeric(18,2),
    nfiv_ibs_mun_reducao numeric(18,2),
    nfiv_ibs_mun_valor numeric(18,2),
    nfiv_ibs_uf_aliquota numeric(18,2),
    nfiv_ibs_uf_reducao numeric(18,2),
    nfiv_ibs_uf_valor numeric(18,2),
    nfiv_iva_valor numeric(18,6),
    nfiv_cclasstrib character(6),
    nfiv_cbs_aliquota_efetiva numeric(18,2),
    nfiv_ibs_uf_aliquota_efetiva numeric(18,2),
    nfiv_ibs_mun_aliquota_efetiva numeric(18,2),
    nfiv_cbenef_id integer
);


ALTER TABLE public.nf_item OWNER TO postgres;

--
-- Name: nf_produtos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nf_produtos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nf_produtos_id_seq OWNER TO postgres;

--
-- Name: nf_produtos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.nf_produtos_id_seq OWNED BY public.nf_item.id;


--
-- Name: nfe_lote_envio_evento; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nfe_lote_envio_evento
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nfe_lote_envio_evento OWNER TO postgres;

--
-- Name: nomearq; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nomearq (
    id integer NOT NULL,
    nomeparcial character(8)
);


ALTER TABLE public.nomearq OWNER TO postgres;

--
-- Name: nomearq_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nomearq_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nomearq_id_seq OWNER TO postgres;

--
-- Name: nomearq_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.nomearq_id_seq OWNED BY public.nomearq.id;


--
-- Name: observacoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.observacoes (
    obs_id integer NOT NULL,
    obs_descricao character(100),
    obs_texto character(1000),
    obs_usuario integer,
    obs_data date,
    qual_tipo_nota integer
);


ALTER TABLE public.observacoes OWNER TO postgres;

--
-- Name: observacoes_obs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.observacoes_obs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.observacoes_obs_id_seq OWNER TO postgres;

--
-- Name: observacoes_obs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.observacoes_obs_id_seq OWNED BY public.observacoes.obs_id;


--
-- Name: ocorrencia_ocorrencia_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ocorrencia_ocorrencia_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ocorrencia_ocorrencia_codigo_seq OWNER TO postgres;

--
-- Name: ocorrencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ocorrencia (
    ocorrencia_id integer NOT NULL,
    ocorrencia_codigo character(3) DEFAULT lpad(((nextval('public.ocorrencia_ocorrencia_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    ocorrencia_descricao character(150) NOT NULL,
    ocorrencia_pontuacao integer DEFAULT 0,
    ocorrencia_producao boolean,
    ocorrencia_devolucoes boolean DEFAULT true,
    ocorrencia_comercial boolean DEFAULT false,
    ocorrencia_espalmagem boolean,
    ocorrencia_paradas boolean DEFAULT false,
    ocorrencia_391 boolean DEFAULT true,
    ocorrencia_origem integer
);


ALTER TABLE public.ocorrencia OWNER TO postgres;

--
-- Name: ocorrencia_ocorrencia_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ocorrencia_ocorrencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ocorrencia_ocorrencia_id_seq OWNER TO postgres;

--
-- Name: ocorrencia_ocorrencia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ocorrencia_ocorrencia_id_seq OWNED BY public.ocorrencia.ocorrencia_id;


--
-- Name: ocorrencia_papel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ocorrencia_papel (
    ocorrencia_papel_id integer NOT NULL,
    ocorrencia_papel_rev_papel_id integer,
    ocorrencia_papel_ocorrencia integer,
    ocorrencia_papel_observacao character(300),
    ocorrencia_papel_data date,
    ocorrencia_papel_hora character(12),
    ocorrencia_papel_operador integer
);


ALTER TABLE public.ocorrencia_papel OWNER TO postgres;

--
-- Name: ocorrencia_papel_ocorrencia_papel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ocorrencia_papel_ocorrencia_papel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ocorrencia_papel_ocorrencia_papel_id_seq OWNER TO postgres;

--
-- Name: ocorrencia_papel_ocorrencia_papel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ocorrencia_papel_ocorrencia_papel_id_seq OWNED BY public.ocorrencia_papel.ocorrencia_papel_id;


--
-- Name: operacoes_operacoes_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.operacoes_operacoes_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.operacoes_operacoes_codigo_seq OWNER TO postgres;

--
-- Name: operacoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.operacoes (
    operacoes_id integer NOT NULL,
    operacoes_codigo character(5) DEFAULT lpad(((nextval('public.operacoes_operacoes_codigo_seq'::regclass))::character(5))::text, 5, '0'::text),
    operacoes_grupo_maquina character(4),
    operacoes_subgrupo character(3),
    operacoes_tm numeric(12,5),
    operacoes_th numeric(12,5),
    operacoes_descricao character(70),
    operacoes_observacao text,
    operacoes_classificacao character(50),
    operacoes_esforco character(1) DEFAULT 2,
    operacoes_apontamento character(1) DEFAULT 1,
    operacoes_automatico character(1)
);


ALTER TABLE public.operacoes OWNER TO postgres;

--
-- Name: operacoes_operacoes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.operacoes_operacoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.operacoes_operacoes_id_seq OWNER TO postgres;

--
-- Name: operacoes_operacoes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.operacoes_operacoes_id_seq OWNED BY public.operacoes.operacoes_id;


--
-- Name: orcamento_fixo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orcamento_fixo (
    of_id integer NOT NULL,
    of_sc_id integer,
    of_data date,
    of_aprovado boolean,
    of_data_aprovado date,
    of_quem_aprovou integer,
    of_observacao character(150),
    of_prazo_pagto integer,
    of_tipo_documento integer,
    of_fornecedor integer,
    of_previsao_faturamento date,
    of_previsao_entrega date,
    of_moeda integer,
    of_observacao_nf character(150),
    of_recebido boolean DEFAULT false,
    of_observacao_recebimento character(150),
    of_data_recebimento date,
    of_recebedor_id integer,
    of_nf_id integer,
    of_ativo boolean DEFAULT true,
    of_enviou_email character(200),
    of_codigo character(12),
    of_frete character(3),
    of_recebimento integer DEFAULT 0,
    of_nome_vendedor character(200),
    of_desconto numeric(18,2),
    of_hora_aprovado character(10),
    of_tipo_frete integer,
    of_valor_frete numeric(18,4)
);


ALTER TABLE public.orcamento_fixo OWNER TO postgres;

--
-- Name: orcamento_fixo_of_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orcamento_fixo_of_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orcamento_fixo_of_id_seq OWNER TO postgres;

--
-- Name: orcamento_fixo_of_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orcamento_fixo_of_id_seq OWNED BY public.orcamento_fixo.of_id;


--
-- Name: orcamento_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orcamento_item (
    oi_id integer NOT NULL,
    oi_of_id integer,
    oi_produto integer,
    oi_cor integer,
    oi_data date,
    oi_valor numeric(18,2),
    oi_icms numeric(18,2),
    oi_ipi numeric(18,2),
    oi_observacao character(150),
    oi_aprovado boolean,
    oi_qtde numeric(18,2),
    oi_unitario_real numeric(18,4),
    oi_cotacao numeric(18,4),
    oi_data_cotacao date,
    oi_unitario_na_moeda numeric(18,4),
    oi_moeda integer DEFAULT 0,
    oi_recebido integer DEFAULT 0
);


ALTER TABLE public.orcamento_item OWNER TO postgres;

--
-- Name: orcamento_item_oi_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orcamento_item_oi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orcamento_item_oi_id_seq OWNER TO postgres;

--
-- Name: orcamento_item_oi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orcamento_item_oi_id_seq OWNED BY public.orcamento_item.oi_id;


--
-- Name: orcamento_recebido; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orcamento_recebido (
    or_id integer NOT NULL,
    or_oi_id integer,
    or_data date,
    or_unitario numeric(18,4),
    or_qtde numeric(18,4),
    or_observacao character(200),
    or_user integer,
    or_data_user time without time zone,
    or_nota_fiscal character(10),
    or_trocou_produto_id integer,
    or_nota_fiscal_id integer,
    or_recebimento integer DEFAULT 0
);


ALTER TABLE public.orcamento_recebido OWNER TO postgres;

--
-- Name: orcamento_recebido_or_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orcamento_recebido_or_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orcamento_recebido_or_id_seq OWNER TO postgres;

--
-- Name: orcamento_recebido_or_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orcamento_recebido_or_id_seq OWNED BY public.orcamento_recebido.or_id;


--
-- Name: orcamento_recebidos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orcamento_recebidos (
    or_id integer NOT NULL,
    or_codigo character(25),
    or_oi_id integer,
    or_nota_id integer,
    or_quantidade numeric(18,2),
    or_unidade character(4),
    or_unitario numeric(18,2),
    or_data date,
    or_hora character(20),
    or_usuario integer
);


ALTER TABLE public.orcamento_recebidos OWNER TO postgres;

--
-- Name: orcamento_recebidos_or_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orcamento_recebidos_or_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orcamento_recebidos_or_id_seq OWNER TO postgres;

--
-- Name: orcamento_recebidos_or_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orcamento_recebidos_or_id_seq OWNED BY public.orcamento_recebidos.or_id;


--
-- Name: orcamento_vencimentos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orcamento_vencimentos_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orcamento_vencimentos_id_seq OWNER TO postgres;

--
-- Name: orcamento_vencimentos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orcamento_vencimentos (
    id integer DEFAULT nextval('public.orcamento_vencimentos_id_seq'::regclass) NOT NULL,
    of_id integer,
    vencimento date,
    valor numeric(18,2),
    exibe_apagar boolean DEFAULT false,
    obs character(200)
);


ALTER TABLE public.orcamento_vencimentos OWNER TO postgres;

--
-- Name: ordem_beneficiamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_beneficiamento (
    ob_id integer NOT NULL,
    ob_aa50id integer NOT NULL,
    ob_estampas_id integer NOT NULL,
    ob_data_emissao date,
    ob_observacao text,
    ob_volumes integer,
    ob_quantidade numeric(8,2),
    ob_impresso integer DEFAULT 0,
    ob_pdi_id integer,
    ob_tipo integer DEFAULT 0,
    ob_ordem integer NOT NULL,
    ob_obs_sistema character(150),
    ob_statusamostra integer,
    ob_data_programacao date,
    ob_fluxo integer,
    ob_data_entrega date,
    ob_processo_industrial integer,
    ob_revisar boolean DEFAULT false,
    ob_bloqueio_amostra_internet boolean DEFAULT false,
    ob_data_desbloqueio_amostra_internet date,
    ob_liberou character(100)
);


ALTER TABLE public.ordem_beneficiamento OWNER TO postgres;

--
-- Name: ordem_beneficiamento_bloqueios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_beneficiamento_bloqueios (
    obb_id integer NOT NULL,
    obb_ocorrencia integer,
    obb_data date,
    obb_hora time without time zone,
    obb_usuario integer,
    obb_operador integer,
    obb_partida_ob integer,
    obb_tipo character(1),
    obb_peca integer,
    obb_qtde numeric(15,2),
    obb_observacao character(300),
    obb_bloqueio boolean,
    obb_operador_liberador integer,
    obb_data_liberacao date,
    obb_hora_liberacao time without time zone,
    obb_justificativa character(300),
    obb_qtde_revisado numeric(15,2),
    obb_gramatura numeric(10,3),
    obb_maquina_id integer
);


ALTER TABLE public.ordem_beneficiamento_bloqueios OWNER TO postgres;

--
-- Name: ordem_beneficiamento_bloqueios_obb_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_beneficiamento_bloqueios_obb_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_beneficiamento_bloqueios_obb_id_seq OWNER TO postgres;

--
-- Name: ordem_beneficiamento_bloqueios_obb_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordem_beneficiamento_bloqueios_obb_id_seq OWNED BY public.ordem_beneficiamento_bloqueios.obb_id;


--
-- Name: ordem_beneficiamento_fluxo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_beneficiamento_fluxo (
    obf_id integer NOT NULL,
    obf_ob_id integer,
    obf_ordem integer,
    obf_estagio integer,
    obf_tempo integer,
    obf_aponta character(1),
    obf_receita integer,
    obf_flx_id integer,
    obf_observa character(150),
    obf_grupo_maquinas integer,
    obf_data_inicio date,
    obf_data_final date,
    obf_supervisor integer,
    obf_fase_extra character(1) DEFAULT 'N'::bpchar,
    obf_partida integer,
    obf_maquina_id integer,
    obf_etapa character(1),
    obf_hora_inicio character(10),
    obf_hora_final character(10),
    obf_operador character(10),
    obf_operador_final character(10),
    obf_operador_inicio_id integer,
    obf_operador_final_id integer,
    obf_passadas integer,
    obf_metros_minutos numeric(17,2),
    obf_inicio timestamp without time zone,
    obf_final timestamp without time zone,
    obf_minutos integer,
    obf_operador_inicio character(25),
    obf_parada integer,
    obf_user_deletou integer,
    obf_data_deletou text,
    obf_obs_deletou text
);


ALTER TABLE public.ordem_beneficiamento_fluxo OWNER TO postgres;

--
-- Name: ordem_beneficiamento_fluxo_obf_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_beneficiamento_fluxo_obf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_beneficiamento_fluxo_obf_id_seq OWNER TO postgres;

--
-- Name: ordem_beneficiamento_fluxo_obf_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordem_beneficiamento_fluxo_obf_id_seq OWNED BY public.ordem_beneficiamento_fluxo.obf_id;


--
-- Name: ordem_beneficiamento_historicos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_beneficiamento_historicos (
    obh_id integer NOT NULL,
    obh_ob_id integer NOT NULL,
    obh_aa50id integer NOT NULL,
    obh_estampas_id integer NOT NULL,
    obh_dthora timestamp without time zone DEFAULT now() NOT NULL,
    obh_usuario_id integer,
    obh_descricao character varying(100) NOT NULL
);


ALTER TABLE public.ordem_beneficiamento_historicos OWNER TO postgres;

--
-- Name: ordem_beneficiamento_historicos_obh_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_beneficiamento_historicos_obh_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_beneficiamento_historicos_obh_id_seq OWNER TO postgres;

--
-- Name: ordem_beneficiamento_historicos_obh_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordem_beneficiamento_historicos_obh_id_seq OWNED BY public.ordem_beneficiamento_historicos.obh_id;


--
-- Name: ordem_beneficiamento_lote; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_beneficiamento_lote (
    obl_id integer NOT NULL,
    obl_ob_id integer NOT NULL,
    obl_os_id integer,
    obl_volume integer NOT NULL,
    obl_lote_referencia character(20),
    obl_quantidade numeric(15,2),
    obl_programacao_original_qtde numeric(15,2)
);


ALTER TABLE public.ordem_beneficiamento_lote OWNER TO postgres;

--
-- Name: ordem_beneficiamento_lote_obl_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_beneficiamento_lote_obl_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_beneficiamento_lote_obl_id_seq OWNER TO postgres;

--
-- Name: ordem_beneficiamento_lote_obl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordem_beneficiamento_lote_obl_id_seq OWNED BY public.ordem_beneficiamento_lote.obl_id;


--
-- Name: ordem_beneficiamento_ob_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_beneficiamento_ob_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_beneficiamento_ob_id_seq OWNER TO postgres;

--
-- Name: ordem_beneficiamento_ob_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordem_beneficiamento_ob_id_seq OWNED BY public.ordem_beneficiamento.ob_id;


--
-- Name: ordem_fio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_fio (
    of_id integer NOT NULL,
    of_aa50id integer NOT NULL,
    of_quantidade numeric(9,2),
    of_data date,
    of_lote character(10) NOT NULL,
    of_tipo integer
);


ALTER TABLE public.ordem_fio OWNER TO postgres;

--
-- Name: ordem_fio_of_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_fio_of_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_fio_of_id_seq OWNER TO postgres;

--
-- Name: ordem_fio_of_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordem_fio_of_id_seq OWNED BY public.ordem_fio.of_id;


--
-- Name: ordem_parametros_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_parametros_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_parametros_id_seq OWNER TO postgres;

--
-- Name: ordem_parametros; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_parametros (
    id integer DEFAULT nextval('public.ordem_parametros_id_seq'::regclass) NOT NULL,
    os_id integer,
    data_lancamento date,
    velocidade numeric(18,2),
    temperatura numeric(18,2),
    maquina_id integer,
    observacao character(100)
);


ALTER TABLE public.ordem_parametros OWNER TO postgres;

--
-- Name: ordem_servico; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_servico (
    os_id integer NOT NULL,
    os_pdi_id integer NOT NULL,
    os_data_emissao date,
    os_impressa boolean DEFAULT false,
    os_total_produzido numeric(8,2),
    os_lote character(20),
    os_tipo integer DEFAULT 0 NOT NULL,
    os_nota character(10),
    os_entidade integer,
    os_aa50id integer,
    os_data_final date,
    os_maquina_id integer,
    os_variacao_id integer,
    os_observacao text,
    os_volume integer,
    os_finalizada boolean,
    os_quantidade numeric(10,2),
    os_deposito_id integer,
    os_aa50id_acabado integer,
    os_empresa_id integer,
    os_unidade character(2),
    os_data_programacao date,
    os_codigo integer,
    os_hora_final character(12),
    os_perdeu_tudo boolean DEFAULT false,
    os_emissao_nota_fiscal date,
    os_pintura boolean DEFAULT false,
    os_ambiente character(200),
    os_movel character(400),
    os_simulacao_id integer,
    os_viscosidade integer,
    os_observacao_ordem character(200),
    os_agrupamento integer,
    os_data_agrupamento date,
    os_usuario_agrupador integer,
    os_agrupamento_hora character(10),
    os_agrupamento_obs character(500),
    os_data_ordem_corte date,
    os_estampas_id integer,
    os_id_plano_corte integer,
    os_inicio_misturacao timestamp without time zone,
    os_final_misturacao timestamp without time zone,
    os_operador_misturacao integer,
    os_obs_misturacao character(300),
    os_data_inicio date,
    os_hora_inicio character(10),
    inicio timestamp without time zone,
    final timestamp without time zone,
    os_inativada boolean DEFAULT false,
    os_descricao text,
    os_espalmadeira date,
    os_datalaudo date,
    os_horalaudo character(20),
    os_iduser_laudo integer,
    os_statuslaudo boolean DEFAULT true,
    os_obslaudo character(120),
    os_obs_cancelada character(1000)
)
WITH (autovacuum_enabled='true');


ALTER TABLE public.ordem_servico OWNER TO postgres;

--
-- Name: ordem_servico_aponta_osaa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_servico_aponta_osaa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_servico_aponta_osaa_id_seq OWNER TO postgres;

--
-- Name: ordem_servico_aponta; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_servico_aponta (
    osaa_id integer DEFAULT nextval('public.ordem_servico_aponta_osaa_id_seq'::regclass) NOT NULL,
    osaa_os_id integer,
    osaa_osm_id integer,
    osaa_data_inicio date,
    osaa_data_fim date,
    osaa_funcionario integer,
    osaa_maquina integer,
    osaa_obs text,
    osaa_obs_sistema text,
    osaa_ordem_completa character(50),
    osaa_os_item integer,
    osaa_qtde numeric(18,2),
    hora_inicio character(8),
    osaa_hora_fim timestamp without time zone,
    osaa_hora_inicio timestamp without time zone
);


ALTER TABLE public.ordem_servico_aponta OWNER TO postgres;

--
-- Name: ordem_servico_aponta_aberto_osaa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_servico_aponta_aberto_osaa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_servico_aponta_aberto_osaa_id_seq OWNER TO postgres;

--
-- Name: ordem_servico_aponta_aberto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_servico_aponta_aberto (
    osaa_id integer DEFAULT nextval('public.ordem_servico_aponta_aberto_osaa_id_seq'::regclass) NOT NULL,
    osaa_ordem_servico_aponta_osaa_id integer,
    osaa_os_id integer,
    osaa_osm_id integer,
    osaa_data_inicio date,
    osaa_hora_inicio timestamp without time zone,
    osaa_data_fim date,
    osaa_hora_fim timestamp without time zone,
    osaa_funcionario integer
);


ALTER TABLE public.ordem_servico_aponta_aberto OWNER TO postgres;

--
-- Name: ordem_servico_lancadas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_servico_lancadas (
    ol_id integer NOT NULL,
    ol_data date,
    ol_ordem_servico_id integer,
    os_metros numeric(20,2),
    os_observacao character(500),
    os_data character(30),
    os_codigo integer DEFAULT 0,
    ol_iduser integer,
    os_observacao_sistema character(500)
);


ALTER TABLE public.ordem_servico_lancadas OWNER TO postgres;

--
-- Name: ordem_servico_lancadas_ol_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_servico_lancadas_ol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_servico_lancadas_ol_id_seq OWNER TO postgres;

--
-- Name: ordem_servico_lancadas_ol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordem_servico_lancadas_ol_id_seq OWNED BY public.ordem_servico_lancadas.ol_id;


--
-- Name: ordem_servico_laudo_osl_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_servico_laudo_osl_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_servico_laudo_osl_id_seq OWNER TO postgres;

--
-- Name: ordem_servico_laudo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_servico_laudo (
    osl_id integer DEFAULT nextval('public.ordem_servico_laudo_osl_id_seq'::regclass) NOT NULL,
    osl_os_id integer,
    osl_tipo integer,
    osl_tipo_descricao character(50),
    osl_status boolean,
    osl_obs_sistema character(50),
    osl_obs character(100),
    osl_iduser integer,
    osl_data date,
    osl_hora character(20)
);


ALTER TABLE public.ordem_servico_laudo OWNER TO postgres;

--
-- Name: ordem_servico_mo_osm_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_servico_mo_osm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_servico_mo_osm_id_seq OWNER TO postgres;

--
-- Name: ordem_servico_mo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_servico_mo (
    osm_id integer DEFAULT nextval('public.ordem_servico_mo_osm_id_seq'::regclass) NOT NULL,
    osm_idambiente integer,
    osm_idorcamento integer,
    osm_operacao integer,
    osm_qtde numeric(22,4),
    osm_qtde_hora character(8),
    osm_qtde_minuto integer,
    osm_valor_hora numeric(18,2),
    osm_valor_minuto numeric(20,7),
    osm_seq character(2),
    osm_qtde_extenso character(150),
    osm_valor_item numeric(18,2),
    osm_operacao_descricao character(200),
    osm_setup_qtde_hora numeric(18,2)
);


ALTER TABLE public.ordem_servico_mo OWNER TO postgres;

--
-- Name: ordem_servico_os_agrupamento_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_servico_os_agrupamento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_servico_os_agrupamento_seq OWNER TO postgres;

--
-- Name: ordem_servico_os_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_servico_os_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_servico_os_id_seq OWNER TO postgres;

--
-- Name: ordem_servico_os_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordem_servico_os_id_seq OWNED BY public.ordem_servico.os_id;


--
-- Name: ordem_servico_reprocesso_osr_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordem_servico_reprocesso_osr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordem_servico_reprocesso_osr_id_seq OWNER TO postgres;

--
-- Name: ordem_servico_reprocesso; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordem_servico_reprocesso (
    osr_id integer DEFAULT nextval('public.ordem_servico_reprocesso_osr_id_seq'::regclass) NOT NULL,
    osr_oscodigo_pai integer,
    osr_osid_filho integer,
    osr_oscodigo_filho integer,
    osr_fnc integer,
    osr_fnc_codigo character(20),
    osr_motivo text,
    osr_data date,
    osr_hora character(20),
    osr_iduser integer
);


ALTER TABLE public.ordem_servico_reprocesso OWNER TO postgres;

--
-- Name: origem_ocorrencia_oc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.origem_ocorrencia_oc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.origem_ocorrencia_oc_id_seq OWNER TO postgres;

--
-- Name: origem_ocorrencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.origem_ocorrencia (
    oc_id integer DEFAULT nextval('public.origem_ocorrencia_oc_id_seq'::regclass) NOT NULL,
    oc_descricao text
);


ALTER TABLE public.origem_ocorrencia OWNER TO postgres;

--
-- Name: os_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.os_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.os_log_id_seq OWNER TO postgres;

--
-- Name: os_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.os_log (
    id integer DEFAULT nextval('public.os_log_id_seq'::regclass) NOT NULL,
    assunto character(200),
    plano_id integer,
    os_id integer,
    data date,
    hora character(10),
    usuario integer,
    obs_sistema character(200),
    obf_id integer,
    tipo_acao character(50)
);


ALTER TABLE public.os_log OWNER TO postgres;

--
-- Name: padrao_pdr_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.padrao_pdr_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.padrao_pdr_id_seq OWNER TO postgres;

--
-- Name: padrao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.padrao (
    pdr_id integer DEFAULT nextval('public.padrao_pdr_id_seq'::regclass) NOT NULL,
    pdr_produtoid integer,
    pdr_corid integer,
    pdr_user integer,
    pdr_data date,
    pdr_hora character(12),
    pdr_solicita_padrao boolean
);


ALTER TABLE public.padrao OWNER TO postgres;

--
-- Name: padrao_log_pdl_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.padrao_log_pdl_id_seq
    START WITH 6
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.padrao_log_pdl_id_seq OWNER TO postgres;

--
-- Name: padrao_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.padrao_log (
    pdl_id integer DEFAULT nextval('public.padrao_log_pdl_id_seq'::regclass) NOT NULL,
    pdl_padraoid integer,
    pdl_produtoid integer,
    pdl_corid integer,
    pdl_userid integer,
    pdl_data date,
    pdl_hora character(12),
    pdl_anotacao character(600),
    pdl_anotacao_sistema character(600)
);


ALTER TABLE public.padrao_log OWNER TO postgres;

--
-- Name: paises; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.paises (
    paises_id integer NOT NULL,
    paises_nome character(50) NOT NULL,
    paises_cod_inter numeric(4,0),
    paises_cod_fisc numeric(5,0),
    paises_idioma_nome character(50),
    paises_idioma character(2),
    paises_codigo character(4) NOT NULL
);


ALTER TABLE public.paises OWNER TO postgres;

--
-- Name: paises_paises_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.paises_paises_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.paises_paises_id_seq OWNER TO postgres;

--
-- Name: paises_paises_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.paises_paises_id_seq OWNED BY public.paises.paises_id;


--
-- Name: parametro_beneficiamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametro_beneficiamento (
    parb_id integer NOT NULL,
    parb_familia_tecidos character(3),
    parb_ob_tecidos integer,
    parb_familia_malhas character(3),
    parb_ob_malhas integer,
    parb_familia_fios character(3),
    parb_ob_fios integer,
    parb_preparacao character(2),
    parb_tingimento character(2),
    parb_acabamento character(2),
    parb_revisao character(2),
    parb_consumo_romaneio "char",
    parb_consumo_nf "char",
    parb_altcorob1 character(20),
    parb_altcorob2 character(20),
    parb_altcorob3 character(20),
    parb_altcoroblibera character(1),
    parb_canitemob1 character(20),
    parb_canitemob2 character(20),
    parb_canitemob3 character(20),
    parb_canitemoblibera character(1),
    parb_cancelaob1 character(20),
    parb_cancelaob2 character(20),
    parb_cancelaob3 character(20),
    parb_cancelaoblibera character(1),
    parb_balanca_revisao character(1),
    parb_layout_obt character(150),
    parb_tipo_end_deposito character(1) DEFAULT 'S'::bpchar,
    parb_diasembarque integer,
    parb_porc_aceitavel_obt double precision,
    parb_valida_pedido integer,
    parb_cfop_estadual integer,
    parb_cfop_inter integer,
    parb_cfop_exporta integer,
    parb_programado character(1),
    parb_produto_tipo character(1),
    parb_qualidade integer,
    parb_parcial character(1),
    parb_produto_nivel integer,
    parb_perda_insumo_receita numeric(3,2),
    parb_depositorevisao character(3),
    parb_coresgenericaspedido boolean DEFAULT false,
    parb_carregaultimopedido boolean DEFAULT false,
    parb_deposito_acabado character(3),
    parb_deposito_transito character(3),
    parb_deposito_fio_revisao character(3),
    parb_deposito_matprima_compra character(3),
    parb_tpmov_fio_revisao integer,
    parb_tpmov_matprima_compra integer,
    parb_deposito_consumo_fio_malharia character(3),
    parb_tpmov_consumo_fio_malharia integer,
    parb_tpmov_consumo_fio_malharia_entrada integer,
    parb_tpmov_matprima_compra_entrada integer,
    parb_tpmov_fio_revisao_entrada integer,
    parb_tpmov_retalhos_entrada integer,
    parb_tpmov_retalhos integer,
    parb_deposito_retalhos character(3),
    parb_produto_retalho integer,
    parb_carrega_pedido_automatico boolean DEFAULT false,
    parb_tpmov_consumo_retalho integer,
    parb_divide_pf_media boolean DEFAULT true,
    parb_amostra_atividades_253 integer,
    parb_repete_valores_item boolean,
    parb_base character(3),
    parb_laca character(3),
    parb_top character(3),
    parb_pigmento character(3),
    parb_master character(3),
    parb_exclui_aponta_185_1 integer,
    parb_exclui_aponta_185_2 integer,
    parb_exclui_aponta_185_3 integer,
    parb_deposito_decartes character(3),
    parb_percentual_maior_pedido integer,
    parb_percentual_menor_pedido integer,
    parb_calcula_automatico_165a boolean,
    parb_mostra_estoques_189 boolean DEFAULT false,
    parb_libera_cgs0080_1 integer,
    parb_libera_cgs0080_2 integer,
    parb_libera_cgs0080_3 integer,
    parb_parametro_calculo_160 integer DEFAULT 1,
    parb_habilita_f3 integer,
    parb_parametro_calculo_165 integer,
    parb_tipo_tabela integer,
    parb_exibe_mapa_por integer,
    parb_periodo_292 integer,
    parb_folha_pagamento numeric(15,2),
    parb_numero_funcionarios integer,
    parb_horas_trabalhadas_mes integer,
    parb_custo_maquina_funcionario numeric(15,2),
    parb_custo_minuto numeric(17,2),
    parb_media_salarial numeric(17,2),
    parb_exige_fluxo boolean,
    parb_exige_apontamento_fluxo_165 boolean,
    parb_amostra_ocorrencia integer,
    parb_usa_ci boolean,
    parb_tipo_292 integer,
    parb_utiliza_136_completo boolean DEFAULT true,
    parb_utiliza_bloqueio_financeiro_166 boolean DEFAULT false,
    parb_importa_estrutura_de_produto integer,
    parb_trazer_fluxo_padrao_empresa integer,
    parb_parametro_iniciar_158 integer,
    parb_layout251 integer DEFAULT 1,
    parb_desabilita_fechamento166 boolean,
    parb_utiliza_devolucao_107_118 boolean DEFAULT false,
    parb_exige_lancamento_103 boolean DEFAULT false,
    parb_papel character(3),
    parb_substrato character(3),
    parb_custo_minuto_simulacao1 numeric(18,2),
    parb_custo_minuto_simulacao2 numeric(18,2),
    parb_atualizapreco_300 boolean,
    parb_os_id integer,
    parb_ind_perfil character(1),
    parb_ind_ativ integer,
    parb_contador character(200),
    parb_contador_cpf character(20),
    parb_contador_crc character(10),
    parb_contador_cnpj character(20),
    parb_contador_cep character(20),
    parb_contador_endereco character(200),
    parb_contador_numero character(20),
    parb_contador_complemento character(200),
    parb_contador_bairro character(200),
    parb_contador_fone character(20),
    parb_contador_fax character(20),
    parb_contador_email character(200),
    parb_contador_codigocidade integer,
    parb_aponta_ob_por_partida character(1) DEFAULT 'N'::bpchar,
    parb_ocorrencia_padrao_de_parada integer,
    parb_aba_custos boolean,
    parb_forca_atualizacao_preco_para_custos boolean DEFAULT false,
    parb_baixa_todos integer,
    parb_escolhe_ficha integer DEFAULT 0,
    parb_exibetodos_200 boolean,
    parb_retira_ipi_da_comissao boolean,
    parb_habilita_fechar_300 boolean DEFAULT true,
    parb_habilita_aceita_web_300 boolean DEFAULT true,
    parb_confeccao character(3),
    parb_confeccao_consumo character(3),
    range_inicio integer,
    range_final integer,
    range_sequencia integer,
    range_aviso integer,
    parb_folha_simulacao integer,
    parb_folha_simulacao_valor numeric(18,2),
    parb_folha_simulacao_funcionarios integer,
    parb_folha_simulacao_media numeric(18,2),
    parb_folha_simulacao_horas_mes integer,
    parb_folha_simulacao_maquina_funcionario numeric(18,2),
    parb_folha_simulacao_custo_minuto numeric(18,2),
    parb_ultimo_orcamento integer,
    parb_fnc integer,
    parb_padrao_simples_nacional numeric(18,2),
    parb_padrao_frete numeric(18,2),
    parb_padrao_embalagem numeric(18,2),
    parb_padrao_comissoes numeric(18,2),
    parb_padrao_lucro numeric(18,2),
    parb_os_codigo integer,
    parb_exibe0426_na_107 boolean DEFAULT false,
    parb_exibe0426_na_118 boolean DEFAULT false,
    parb_exibe0426_na_368 boolean DEFAULT false,
    parb_orcamento_padrao character(20),
    parb_ibpt_vigencia date,
    parb_ibpt_versao character(50),
    parb_fnc_fornecedor integer,
    parb_utilizar_bloqueio_padrao boolean DEFAULT false,
    parb_utilizar_baixa_lote boolean DEFAULT false,
    parb_centro_custo_principal integer,
    pb_perc_servico numeric(18,4),
    pb_perc_mo numeric(18,4),
    pb_perc_insumos numeric(18,4),
    parb_copia_itens_precos boolean,
    parb_exige_apontamento_lote boolean DEFAULT false,
    parb_romaneio_ci character(1000),
    parb_renovar_fci date
);


ALTER TABLE public.parametro_beneficiamento OWNER TO postgres;

--
-- Name: parametro_beneficiamento_parb_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parametro_beneficiamento_parb_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parametro_beneficiamento_parb_id_seq OWNER TO postgres;

--
-- Name: parametro_beneficiamento_parb_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parametro_beneficiamento_parb_id_seq OWNED BY public.parametro_beneficiamento.parb_id;


--
-- Name: parametro_financiamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametro_financiamento (
    parfin_f2 boolean DEFAULT false,
    parfin_f3 boolean DEFAULT false,
    parfin_f5 boolean DEFAULT false,
    parfin_juros numeric(16,3),
    parfin_id integer NOT NULL,
    parfin_f4 boolean DEFAULT false,
    parfin_banco_codigo character(3),
    parfin_banco_descricao character(60),
    parfin_libera_pedido boolean,
    parfin_libera_pedido1 character(15),
    parfin_libera_pedido2 character(15),
    parfin_libera_pedido3 character(15),
    parfin_envia_pedido_liberado1 character(40),
    parfin_envia_pedido_liberado2 character(40),
    parfin_envia_pedido_liberado3 character(40),
    parfin_libera_cliente boolean,
    parfin_libera_cliente1 character(15),
    parfin_libera_cliente2 character(15),
    parfin_libera_cliente3 character(15),
    parfin_tabela_preco_padrao integer
);


ALTER TABLE public.parametro_financiamento OWNER TO postgres;

--
-- Name: parametro_financiamento_parfin_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parametro_financiamento_parfin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parametro_financiamento_parfin_id_seq OWNER TO postgres;

--
-- Name: parametro_financiamento_parfin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parametro_financiamento_parfin_id_seq OWNED BY public.parametro_financiamento.parfin_id;


--
-- Name: parametro_grafico; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametro_grafico (
    parametro_grafico_id integer NOT NULL,
    parametro_grafico_grafico_id integer,
    parametro_grafico_seq numeric(3,0),
    parametro_grafico_temperatura numeric(15,3) DEFAULT 0.0000,
    parametro_grafico_tempo_total numeric(15,4) DEFAULT 0.00,
    parametro_grafico_letra character(5),
    parametro_grafico_legenda character(20),
    parametro_grafico_dosagem character(20) NOT NULL,
    parametro_grafico_tempo_minutos numeric(15,4) DEFAULT 0.00
);


ALTER TABLE public.parametro_grafico OWNER TO postgres;

--
-- Name: parametro_grafico_parametro_grafico_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parametro_grafico_parametro_grafico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parametro_grafico_parametro_grafico_id_seq OWNER TO postgres;

--
-- Name: parametro_grafico_parametro_grafico_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parametro_grafico_parametro_grafico_id_seq OWNED BY public.parametro_grafico.parametro_grafico_id;


--
-- Name: parametro_nfe; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametro_nfe (
    parnfe_id integer NOT NULL,
    parnfe_codigo_cliente boolean DEFAULT false,
    parnfe_cst_produto boolean DEFAULT false,
    parnfe_ab15codigo_saida character(5),
    parnfe_ab15codigo_entrada character(5),
    parnfe_cfop_saida character(4),
    parnfe_pesobruto_tara numeric(15,4) DEFAULT 0.0000,
    parnfe_nivel boolean DEFAULT false,
    parnfe_referencia boolean DEFAULT false,
    parnfe_tipodeproduto boolean DEFAULT false,
    parnfe_artigo boolean DEFAULT false,
    parnfe_utilidade boolean DEFAULT false,
    parnfe_colecao boolean DEFAULT false,
    parnfe_genero boolean DEFAULT false,
    parnfe_espessura boolean DEFAULT false,
    parnfe_largura boolean DEFAULT false,
    parnfe_gramatura boolean DEFAULT false,
    parnfe_descricaotabela boolean DEFAULT false,
    parnfe_familia boolean DEFAULT false,
    parnfe_codigo_cor boolean,
    parnfe_cfop_saida_triang_entrega character(4),
    parnfe_cfop_saida_triang_cobranca character(4),
    parnfe_cfop_saida_triang_entrega_fora character(4),
    parnfe_cfop_saida_triang_cobranca_fora character(4),
    parnfe_cfop_saida_fora character(4),
    parnfe_reducao_simples_nacional boolean DEFAULT false,
    parnfe_tipo_frete integer,
    parnfe_cst integer,
    parnfe_tipo_nota integer DEFAULT 2,
    parnfe_cfop_compras_entrada_fora character(4),
    parnfe_cfop_compras_entrada character(4),
    parnfe_cfop_servico_entrada_fora character(4),
    parnfe_cfop_servico_entrada character(4),
    parnfe_permite_cst020_simples_nacional boolean,
    parnfe_aliquota_permissao numeric(18,2),
    parnfe_inicia_calculo_automatico_103 boolean DEFAULT true,
    parnfe_cest integer,
    parnfe_especie character(50),
    parnfe_ab59id_entrada integer,
    parnfe_ab59id_saida integer,
    parnfe_gtin character(10),
    parnfe_forma_pagamento character(2),
    parnfe_indicador_presenca integer,
    parnfe_modalidade_frete integer,
    parnfe_calcula_fcp boolean DEFAULT true,
    parnfe_cfop_saida_beneficamento_interno character(4),
    parnfe_cfop_saida_beneficamento_fora character(4),
    parnfe_insumo_mao_obra integer,
    parnfe_abate boolean DEFAULT false
);


ALTER TABLE public.parametro_nfe OWNER TO postgres;

--
-- Name: parametro_nfe_parnfe_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parametro_nfe_parnfe_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parametro_nfe_parnfe_id_seq OWNER TO postgres;

--
-- Name: parametro_nfe_parnfe_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parametro_nfe_parnfe_id_seq OWNED BY public.parametro_nfe.parnfe_id;


--
-- Name: parametro_viscosidade; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametro_viscosidade (
    parv_id integer NOT NULL,
    parv_grupo integer,
    parv_tipo character(2),
    parv_caracteristica character(1),
    parv_espe1 numeric(18,3),
    parv_espe2 numeric(18,3),
    parv_visco_minino integer,
    parv_visco_maximo integer,
    parv_descricao character(300),
    parv_id_user integer,
    parv_user_data character(20),
    parv_id_altera_user integer,
    parv_user_altera_data character(20)
);


ALTER TABLE public.parametro_viscosidade OWNER TO postgres;

--
-- Name: parametro_viscosidade_parv_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parametro_viscosidade_parv_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parametro_viscosidade_parv_id_seq OWNER TO postgres;

--
-- Name: parametro_viscosidade_parv_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parametro_viscosidade_parv_id_seq OWNED BY public.parametro_viscosidade.parv_id;


--
-- Name: parametros; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametros (
    parametros_id integer NOT NULL,
    parametros_ip character(50),
    parametros_porta character(5),
    parametros_bd character(30),
    parametros_empresa character(50),
    parametros_user character(50),
    parametros_senha character(16),
    parametros_conectado character(1),
    parametros_importacao_clientes character(1),
    parametros_importacao_pedidos character(1),
    parametros_importacao_produtos character(1),
    parametros_emp character(3),
    parametros_produto_exclusivo boolean DEFAULT false NOT NULL,
    parametros_soldesenvolv_automatico boolean DEFAULT false NOT NULL,
    parametros_gerar_contas_pagar_documento_entrada boolean DEFAULT false NOT NULL,
    parametros_entidade_todas_empresas boolean DEFAULT false NOT NULL,
    parametros_perc_toleran_ent_nota numeric(6,2) DEFAULT 0,
    parametros_liberar_entrada_nfe character(1) DEFAULT 0,
    parametros_importacao_centro_custo character(1),
    parametros_importacao_trabalhadores character(1),
    parametros_importacao_cargos_salarios character(1),
    parametros_qtd integer,
    parametros_juros numeric(16,3) DEFAULT 0.000,
    parametros_duplicata_formas integer DEFAULT 1,
    parametros_estampa_automatico boolean DEFAULT false,
    parametros_estampa character(6),
    parametros_bordero_ultimo character(1),
    parametros_receita boolean,
    parametros_libera_receita1 character(15),
    parametros_libera_receita2 character(15),
    parametros_libera_receita3 character(15),
    parametros_envia_email_receita1 character(40),
    parametros_envia_email_receita2 character(40),
    parametros_envia_email_receita3 character(40),
    parametros_bordero_duplicata integer,
    parametros_produz boolean DEFAULT false,
    parametros_beneficia boolean DEFAULT false,
    parametros_utiliza_desc_forn_cons_prod boolean,
    parametros_codigo_produto_manual boolean DEFAULT false,
    parametros_usuarioceponline character varying(100),
    parametros_ceponlinesenha character varying(20),
    parametros_calcula_pf boolean DEFAULT false,
    parametros_localaplicativosatualizar character varying(200),
    parametros_notificarantesatualizar boolean,
    parametros_desenho integer,
    parametros_libera_sd1 integer,
    parametros_libera_sd2 integer,
    parametros_libera_sd3 integer,
    parametros_libera_sd4 integer,
    parametros_libera_sd5 integer,
    parametros_libera_sd6 integer,
    parametros_libera_sd7 integer,
    parametros_libera_sd8 integer,
    parametros_data_faturameno166 boolean,
    parametros_peso_automatico165a boolean,
    parametros_permite_desconto_negativo107 boolean,
    parametros_bandeira_print integer,
    parametros_bandeira integer,
    parametros_print integer,
    parametros_centro_custo_padrao_263 integer,
    parametros_enviaemail_185 character(300),
    parametros_colecoes integer,
    parametros_cor_importacao integer,
    parametros_le_grava_historico_63_10 integer,
    parametros_le_grava_historico_63_09 integer,
    parametros_le_grava_historico_63_01 integer,
    parametros_le_grava_historico_63_02 integer,
    parametros_le_grava_historico_63_03 integer,
    parametros_le_grava_historico_63_04 integer,
    parametros_le_grava_historico_63_05 integer,
    parametros_le_grava_historico_63_06 integer,
    parametros_le_grava_historico_63_07 integer,
    parametros_le_grava_historico_63_08 integer,
    parametros_limite_investimento numeric(15,2),
    parametros_dias_criticos_01 integer,
    parametros_dias_criticos_02 integer,
    parametros_dias_criticos_03 integer,
    parametros_dias_criticos_04 integer,
    parametros_dias_criticos_05 integer,
    parametros_dias_criticos_06 integer,
    parametros_dias_criticos_07 integer,
    parametros_dias_criticos_08 integer,
    parametros_dias_criticos_09 integer,
    parametros_dias_criticos_10 integer,
    parametros_tipo_documento_pedido_compras character(5),
    parametros_prazo_padrao_pedido_compras integer,
    parametros_observacao_pedido_compra character(200),
    parametros_mensagem_email character(500),
    parametros_assunto_email character(400),
    parametros_copia_para_autor boolean DEFAULT true,
    parametros_usa_imagem_30 boolean,
    parametros_usa_codigo_referencia boolean,
    parametros_coloracao integer,
    parametros_producao integer,
    parametros_raport integer,
    parametros_alteracao integer,
    parametros_empenha_automatico boolean DEFAULT false,
    parametros_le_txt_integracao boolean DEFAULT false,
    parametros_caminho_map01 character(200),
    parametros_caminho_map02 character(200),
    parametros_caminho_map03 character(200),
    parametros_caminho_map04 character(200),
    parametros_caminho_map05 character(200),
    parametros_caminho_map06 character(200),
    parametros_caminho_map07 character(200),
    parametros_caminho_map08 character(200),
    parametros_caminho_map09 character(200),
    parametros_caminho_map10 character(200),
    parametros_layout151 integer DEFAULT 0,
    parametros_imagem_produto text,
    parametros_imagem_funcionario text
);


ALTER TABLE public.parametros OWNER TO postgres;

--
-- Name: parametros_parametros_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parametros_parametros_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parametros_parametros_id_seq OWNER TO postgres;

--
-- Name: parametros_parametros_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parametros_parametros_id_seq OWNED BY public.parametros.parametros_id;


--
-- Name: parametros_setup_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parametros_setup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parametros_setup_id_seq OWNER TO postgres;

--
-- Name: parametros_setup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametros_setup (
    id integer DEFAULT nextval('public.parametros_setup_id_seq'::regclass) NOT NULL,
    espessura_inicio numeric(18,2),
    espessura_final numeric(18,2),
    artigo integer,
    setup integer,
    usuario integer,
    data date,
    usuario_alterada integer,
    alteracao date,
    hora_alteracao character(12)
);


ALTER TABLE public.parametros_setup OWNER TO postgres;

--
-- Name: parametros_smtp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametros_smtp (
    parametros_smtp_id integer NOT NULL,
    parametros_smtp_reme_nome character(50),
    parametros_smtp_reme_email character(80),
    parametros_smtp_login character(80),
    parametros_smtp_senha character(50),
    parametros_smtp_servidor character(50),
    parametros_smtp_tsl character(50),
    parametros_smtp_metodo character(50),
    parametros_smtp_conexao_ssl boolean DEFAULT false NOT NULL,
    parametros_smtp_autenticar boolean DEFAULT false NOT NULL,
    parametros_smtp_porta character(8)
);


ALTER TABLE public.parametros_smtp OWNER TO postgres;

--
-- Name: parametros_smtp_parametros_smtp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parametros_smtp_parametros_smtp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parametros_smtp_parametros_smtp_id_seq OWNER TO postgres;

--
-- Name: parametros_smtp_parametros_smtp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parametros_smtp_parametros_smtp_id_seq OWNED BY public.parametros_smtp.parametros_smtp_id;


--
-- Name: parametros_xml; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametros_xml (
    parametros_xml_id integer NOT NULL,
    parametros_xml_empresa character(3),
    parametros_xml_mc character(100),
    parametros_xml_fio character(100),
    parametros_xml_prodelabo character(100),
    parametros_xml_prodacab character(100),
    parametros_xml_totalemp boolean DEFAULT false,
    parametros_xml_mc_deposito character(3),
    parametros_xml_fio_deposito character(3)
);


ALTER TABLE public.parametros_xml OWNER TO postgres;

--
-- Name: parametros_xml_parametros_xml_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parametros_xml_parametros_xml_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parametros_xml_parametros_xml_id_seq OWNER TO postgres;

--
-- Name: parametros_xml_parametros_xml_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parametros_xml_parametros_xml_id_seq OWNED BY public.parametros_xml.parametros_xml_id;


--
-- Name: partida; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partida (
    partida_id integer NOT NULL,
    partida_receita_id integer,
    partida_receita_referencia character(10),
    partida_componente_id integer,
    partida_componente_referencia character(10),
    partida_componente_nome character(80),
    partida_componente_nivel integer,
    partida_unidade_medida character(3),
    partida_consumo numeric(15,6),
    partida_kgs_mt numeric(15,6),
    partida_total numeric(15,6),
    partida_perda numeric(10,3),
    partida_calculo character(3),
    partida_calculo_nome character(50),
    partida_tipo_tbl character(2),
    partida_os_id integer,
    partida_seq_aplicacao integer,
    partida_correcao numeric(15,6),
    partida_unitario numeric(24,5),
    partida_unitario_sem_icms_com_ipi numeric(18,2),
    partida_lotesl_id integer,
    partida_lotemp_id integer,
    partida_ordem integer
);


ALTER TABLE public.partida OWNER TO postgres;

--
-- Name: partida_beneficiamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partida_beneficiamento (
    pb_id integer NOT NULL,
    pb_receita_id integer NOT NULL,
    pb_data date,
    pb_tipo_receita integer,
    pb_maquina_id integer,
    pb_litros numeric(7,2),
    pb_quilos numeric(7,2),
    pb_volumes integer,
    pb_fundo numeric(7,2),
    pb_pickup numeric(7,2),
    pb_partida_original integer,
    pb_operador_final character(10),
    pb_operador_inicio character(10),
    pb_hora_final time without time zone,
    pb_dt_final date,
    pb_hora_inicio time without time zone,
    pb_dt_inicio date,
    pb_finalizada boolean DEFAULT false,
    pb_hora_ocorrencia_liberada time without time zone,
    pb_data_ocorrencia_liberada date,
    pb_data_ocorrencia_usuario integer,
    pb_ocorrencia_bloqueado boolean,
    pb_ocorrencia integer,
    pb_hora_ocorrencia time without time zone,
    pb_data_ocorrencia date,
    pb_observacao_ocorrencia character(1000),
    pb_operador_ocorrencia integer,
    pb_inicio timestamp without time zone,
    pb_final timestamp without time zone,
    programado boolean DEFAULT false
);


ALTER TABLE public.partida_beneficiamento OWNER TO postgres;

--
-- Name: partida_beneficiamento_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partida_beneficiamento_item (
    pbi_id integer NOT NULL,
    pbi_pb_id integer NOT NULL,
    pbi_aa50id integer NOT NULL,
    pbi_consumo numeric(7,2),
    pbi_total numeric(17,4),
    pbi_un character(3),
    pbi_etapa character(5),
    pbi_ordem character(3),
    pbi_fator integer
);


ALTER TABLE public.partida_beneficiamento_item OWNER TO postgres;

--
-- Name: partida_beneficiamento_item_pbi_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.partida_beneficiamento_item_pbi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.partida_beneficiamento_item_pbi_id_seq OWNER TO postgres;

--
-- Name: partida_beneficiamento_item_pbi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.partida_beneficiamento_item_pbi_id_seq OWNED BY public.partida_beneficiamento_item.pbi_id;


--
-- Name: partida_beneficiamento_pb_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.partida_beneficiamento_pb_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.partida_beneficiamento_pb_id_seq OWNER TO postgres;

--
-- Name: partida_beneficiamento_pb_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.partida_beneficiamento_pb_id_seq OWNED BY public.partida_beneficiamento.pb_id;


--
-- Name: partida_partida_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.partida_partida_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.partida_partida_id_seq OWNER TO postgres;

--
-- Name: partida_partida_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.partida_partida_id_seq OWNED BY public.partida.partida_id;


--
-- Name: pd_acab; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pd_acab (
    pd_acab_id integer NOT NULL,
    pd_acab_acabamento_cod character(3),
    pd_acab_cor character(6),
    pd_acab_acabamento character(50),
    pd_acab_pdi_id integer NOT NULL
);


ALTER TABLE public.pd_acab OWNER TO postgres;

--
-- Name: pd_acab_pd_acab_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pd_acab_pd_acab_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pd_acab_pd_acab_id_seq OWNER TO postgres;

--
-- Name: pd_acab_pd_acab_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pd_acab_pd_acab_id_seq OWNED BY public.pd_acab.pd_acab_id;


--
-- Name: pd_cancelados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pd_cancelados (
    pdc_id integer NOT NULL,
    pdc_id_pedido integer,
    pdc_codigo character(12),
    pdc_user integer,
    pdc_data character(12),
    pdc_hora character(12),
    pdc_motivo character(300),
    pdc_obs character(300),
    pdc_motivo_id integer,
    pdc_id_entidade integer
);


ALTER TABLE public.pd_cancelados OWNER TO postgres;

--
-- Name: pd_cancelados_pdc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pd_cancelados_pdc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pd_cancelados_pdc_id_seq OWNER TO postgres;

--
-- Name: pd_cancelados_pdc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pd_cancelados_pdc_id_seq OWNED BY public.pd_cancelados.pdc_id;


--
-- Name: pd_fixo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pd_fixo (
    pd_id integer NOT NULL,
    pd_tipo character(1) DEFAULT 4,
    pd_tipo_nome character(50),
    pd_id_cliente character(10),
    pd_cod_cliente character(10) NOT NULL,
    pd_nome_cliente character(120) NOT NULL,
    pd_id_representante character(10),
    pd_cod_representante character(10),
    pd_nome_representante character(60),
    pd_comissao_representante real,
    pd_obs_cliente character(60),
    pd_obs text,
    pd_parcial character(1),
    pd_valor numeric(15,4),
    pd_unid character(4),
    pd_codigo character(6),
    pd_itens character(3),
    pd_data_emissao date,
    pd_metro numeric(15,4),
    pd_peso numeric(15,4),
    pd_data_embarque date,
    pd_empresa_id integer,
    pd_deposito_id integer,
    pd_deposito_codigo character(3),
    pd_deposito_descricao character(60),
    pd_parcial_descricao character(3),
    pd_programado_descricao character(30),
    pd_programado character(1),
    pd_bloqueios integer,
    pd_servico_vendas integer,
    pd_id_transportadora integer,
    pd_desconto numeric(7,2),
    pd_desconto_extra numeric(7,2),
    pd_valor_liquido numeric(15,2),
    pd_revisado integer,
    pd_id_redespacho integer,
    pd_id_cfop character varying(10),
    pd_id_cpag character varying(10),
    pd_id_tabela character varying(10),
    pd_qualidade integer,
    pd_encargo numeric(7,2),
    pd_tipo_documento character(5),
    pd_cfop_codigo integer,
    pd_tipo_venda integer,
    pd_romaneio character(10),
    pd_triangular boolean DEFAULT false NOT NULL,
    pd_cod_cliente_entrega character(10),
    pd_cod_cliente_cobranca character(10),
    pd_peso_liquido numeric(15,2),
    pd_volume integer,
    pd_volumepeca character(1),
    pd_gerar_cobranca boolean DEFAULT false,
    pd_data_fechamento date,
    pd_cobranca_impressa character(60),
    pd_banco character(3),
    pd_desconto_tipo_documento numeric(9,2),
    pd_data_faturamento date,
    pd_revisar boolean,
    pd_obs_liberacoes character(600),
    pd_internet character(1),
    pd_bloqueado_appweb boolean,
    pd_appweb integer,
    pd_fatura_por integer DEFAULT 1,
    pd_preposto integer,
    pd_preposto_comissao numeric(18,2),
    pd_programar_em date,
    pd_valor_icms numeric(18,2),
    pd_valor_ipi numeric(18,2),
    pd_valor_cofins numeric(18,2),
    pd_outros_impostos numeric(18,2),
    pd_ordem_compra character(15),
    pd_iduser_cancelou integer,
    pd_inativado boolean DEFAULT false,
    pd_obs_cancelado character(1000),
    pd_obssistema_cancelou character(1000)
);


ALTER TABLE public.pd_fixo OWNER TO postgres;

--
-- Name: pd_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pd_log (
    id integer NOT NULL,
    pd_id integer,
    pdi_id_item integer,
    usuario integer,
    data_log date,
    hora_log character(12),
    observacao character(500)
);


ALTER TABLE public.pd_log OWNER TO postgres;

--
-- Name: pd_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pd_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pd_log_id_seq OWNER TO postgres;

--
-- Name: pd_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pd_log_id_seq OWNED BY public.pd_log.id;


--
-- Name: pd_proc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pd_proc (
    pd_proc_id integer NOT NULL,
    pd_proc_processo_cod character(3),
    pd_proc_cor character(6),
    pd_proc_processo character(50),
    pd_proc_pdi_id integer NOT NULL
);


ALTER TABLE public.pd_proc OWNER TO postgres;

--
-- Name: pd_proc_pd_proc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pd_proc_pd_proc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pd_proc_pd_proc_id_seq OWNER TO postgres;

--
-- Name: pd_proc_pd_proc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pd_proc_pd_proc_id_seq OWNED BY public.pd_proc.pd_proc_id;


--
-- Name: pdi_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pdi_item (
    pdi_item character(3),
    pdi_cod_prod integer,
    pdi_niv_prod character(1),
    pdi_ref_prod character(10),
    pdi_cor_prod character(6),
    pdi_volume integer DEFAULT 0,
    pdi_metros numeric(15,4) DEFAULT 0.0000,
    pdi_quilos numeric(15,4) DEFAULT 0.0000,
    pdi_obt character(10),
    pdi_obt_data date,
    pdi_rom character(10),
    pdi_rom_data date,
    pdi_nfi character(10),
    pdi_nfi_data date,
    pdi_aca_codigo character(3),
    pdi_aca_nome character(50),
    pdi_proc_codigo character(3),
    pdi_proc_nome character(50),
    pdi_id integer NOT NULL,
    pdi_data_emissao date,
    pdi_data_entrega date,
    pdi_lote character(10),
    pdi_ped_nota character(10),
    pdi_entidade character(100),
    pdi_metros_programado numeric(15,2) DEFAULT 0.00,
    pdi_quilos_programado numeric(15,2) DEFAULT 0.00,
    pdi_volumes_programado integer DEFAULT 0,
    pdi_codigo character(6),
    pdi_id_pedido integer NOT NULL,
    pdi_bloqueios integer,
    pdi_desconto numeric(7,2),
    pdi_valor_liquido numeric(15,2),
    pdi_id_cfop character varying(10),
    pdi_codigo_cfop character varying(4),
    pdi_descricao_cfop character varying(60),
    pdi_prod_acab_id integer,
    pdi_estampa_id integer,
    pdi_id_nfitem integer,
    pdi_valor_unitario numeric(7,2),
    pdi_quantidade numeric(7,2),
    pdi_valor_bruto numeric(7,2),
    pdi_unidade character(4),
    pdi_aa50item_id integer,
    pdi_obs character(200),
    pdi_unidade_venda character(4),
    pdi_quantidade_venda numeric(7,2),
    pdi_empenhar_amarelo integer,
    pdi_empenhar integer,
    pdi_empenhado boolean DEFAULT false,
    pdi_quilos_liquido numeric(15,2),
    pdi_pre_reserva boolean,
    pdi_cor character(200),
    pdi_id_devolucao integer,
    pdi_nro_ordem_serv integer,
    pdi_dta_ordem_serv date,
    pdi_liberado_diretoria character(1) DEFAULT 'N'::bpchar,
    pdi_liberado_comercial character(1) DEFAULT 'N'::bpchar,
    pdi_liberado_financeiro character(1) DEFAULT 'N'::bpchar,
    pdi_liberado_producao character(1) DEFAULT 'N'::bpchar,
    pdi_liberado_faturamento character(1) DEFAULT 'N'::bpchar,
    pdi_produto character(200),
    pdi_empenhar_quantidade numeric(15,2),
    pdi_empenhar_amarelo_quantidade numeric(15,2),
    pdi_quantidade_original numeric(15,2),
    pdi_unitario_sugestao numeric(15,2),
    pdi_fecha boolean,
    pdi_nf_origem_devolucao integer,
    pdi_custo_scrap numeric(18,2),
    pdi_custo_produto numeric(18,2),
    pdi_obs_prod character(200),
    pdi_obs_expedicao character(200),
    pdi_custo_produto_sem_icms numeric(18,2),
    pdi_tipo_rapport integer,
    pdi_sentido_desenho integer,
    pdi_tipo_aprovacao integer,
    pdi_tamanho_elemento character(100),
    pdi_espacamento_elementos character(100),
    pdi_revisar boolean,
    pdi_item_atendido boolean DEFAULT false,
    pdi_inativado boolean
);


ALTER TABLE public.pdi_item OWNER TO postgres;

--
-- Name: pdi_item_nro_ordem_serv_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pdi_item_nro_ordem_serv_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pdi_item_nro_ordem_serv_seq OWNER TO postgres;

--
-- Name: pdi_item_pdi_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pdi_item_pdi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pdi_item_pdi_id_seq OWNER TO postgres;

--
-- Name: pdi_item_pdi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pdi_item_pdi_id_seq OWNED BY public.pdi_item.pdi_id;


--
-- Name: pds_fixo_pds_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pds_fixo_pds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pds_fixo_pds_id_seq OWNER TO postgres;

--
-- Name: pds_fixo_pds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pds_fixo_pds_id_seq OWNED BY public.pd_fixo.pd_id;


--
-- Name: pecas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pecas (
    pec_entidade character(10),
    pec_id integer NOT NULL,
    pec_entidadenota character(10),
    pec_entidadepreco numeric(15,4),
    pec_entidaderolo character(10),
    pec_unidade character(3),
    pec_entidadeqtde numeric(15,4),
    pec_emitentenota character(10),
    pec_emitentedata date,
    pec_emitentepreco numeric(15,4),
    pec_romaneio character(10),
    pec_romaneiodata date,
    pec_romaneioflag character(1),
    pec_obt character(6),
    pec_obtdata date,
    pec_obtocorrencia character(1),
    pec_qtdedevolvida numeric(15,4),
    pec_depositoentrada character(3),
    pec_depositoatual character(3),
    pec_entidadelote character(10),
    pec_emitentelote character(10),
    pec_largura numeric(7,3) DEFAULT 0.000,
    pec_gramatura numeric(10,3) DEFAULT 0.000,
    pec_rendimento numeric(10,3) DEFAULT 0.000,
    pec_tara numeric(10,3) DEFAULT 0.000,
    pec_metro numeric(15,2) DEFAULT 0.000,
    pec_peso numeric(15,3) DEFAULT 0.000,
    pec_produto integer,
    pec_cor character(6),
    pec_produto_nome character(80),
    pec_entidade_nome character(80),
    pec_emitente_rolo character(12),
    pec_pecas integer,
    pec_selecionada character(1),
    pec_usuario character(80),
    pec_usuario_data date,
    pec_usuario_hora time without time zone,
    pec_item integer,
    pec_prod_acab_id integer,
    pec_prod_acab_nome character(80),
    pec_cor_acab_id integer,
    pec_cor_acab_codigo character(6),
    pec_cor_acab_nome character(40),
    pec_liberador character(30),
    pec_impressao integer,
    pec_observacao text,
    pec_gramatura_m2 numeric(7,3),
    pec_prod_nivel integer,
    pec_prod_referencia character(50),
    pec_artigo_descricao character(50),
    pec_familia character(50),
    pec_gr_linear numeric(15,3) DEFAULT 0.000,
    pec_obt_hora time without time zone,
    pec_serie_cor character(50),
    pec_entidade_id integer,
    pec_libera integer DEFAULT 1,
    pec_impressao_cont integer DEFAULT 0,
    pec_peca_original integer,
    pec_metro_revisado numeric(15,2),
    pec_peso_revisado numeric(15,2),
    pec_data_revisado date,
    pec_quebra_revisado numeric(15,2),
    pec_revisor_id integer,
    pec_revisor_codigo character(5),
    pec_revisor_nome character(50),
    pec_maquina_id integer,
    pec_maquina_codigo character(3),
    pec_maquina_nome character(60),
    pec_pedido character(6),
    pec_romaneio_valor numeric(15,2),
    pec_familia_codigo character(3),
    pec_revisao_deposito character(3),
    pec_revisao_deposito_endereco character(6),
    pec_qualidade character(1),
    pec_baio character(1),
    pec_bair character(1),
    pec_seq character(2),
    pec_id_velho integer,
    pec_revisao_ocorrencia character(3),
    pec_revisao_ocorrencia_descricao character(50),
    pec_empresa_id integer,
    pec_statusrevisao integer DEFAULT 0,
    pec_ordem_servico_id integer,
    pec_pdi_id integer,
    pec_enderecoatual_id integer,
    pec_turno integer,
    pec_voltas integer,
    pec_revisao_ocorrencia_cru character(3),
    pec_data_peca date,
    pec_ob_id integer,
    pec_instrucao_ocorrencia integer DEFAULT 0,
    pec_hora_revisado time without time zone,
    pec_empresa_id_entrada integer,
    pec_qualidade_cru character(1),
    pec_pre_beneficiamentoid integer,
    pec_pdi_devolucao integer,
    pec_data_devolucao date,
    pec_entidade_devolucao integer,
    pec_ocorrencia_descarte_data date,
    pec_ocorrencia_descarte integer,
    pec_ocorrencia_descarte_obs character(150),
    pec_romaneioentidade character(10),
    pec_pecaorigem_id integer,
    pec_tipo_doc integer,
    pec_ob_antiga integer,
    pec_ob_antiga_observacao character(200),
    pec_localdomapa character(500),
    pec_osid_subproduto integer,
    pec_remonta integer
);


ALTER TABLE public.pecas OWNER TO postgres;

--
-- Name: pecas_acabamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pecas_acabamento (
    pecas_acabamento_id integer NOT NULL,
    pecas_acabamento_obt character(6),
    pecas_acabamento_codigo character(3),
    pecas_acabamento_descricao character(50)
);


ALTER TABLE public.pecas_acabamento OWNER TO postgres;

--
-- Name: pecas_acabamento_pecas_acabamento_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pecas_acabamento_pecas_acabamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pecas_acabamento_pecas_acabamento_id_seq OWNER TO postgres;

--
-- Name: pecas_acabamento_pecas_acabamento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pecas_acabamento_pecas_acabamento_id_seq OWNED BY public.pecas_acabamento.pecas_acabamento_id;


--
-- Name: pecas_pec_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pecas_pec_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pecas_pec_id_seq OWNER TO postgres;

--
-- Name: pecas_pec_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pecas_pec_id_seq OWNED BY public.pecas.pec_id;


--
-- Name: pecas_processo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pecas_processo (
    pecas_processo_id integer NOT NULL,
    pecas_processo_obt character(6),
    pecas_processo_codigo character(3),
    pecas_processo_descricao character(50)
);


ALTER TABLE public.pecas_processo OWNER TO postgres;

--
-- Name: pecas_processo_pecas_processo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pecas_processo_pecas_processo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pecas_processo_pecas_processo_id_seq OWNER TO postgres;

--
-- Name: pecas_processo_pecas_processo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pecas_processo_pecas_processo_id_seq OWNED BY public.pecas_processo.pecas_processo_id;


--
-- Name: pecas_soma; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pecas_soma AS
 SELECT pecas.pec_romaneio_valor,
    pecas.pec_peso,
    pecas.pec_romaneio
   FROM public.pecas;


ALTER TABLE public.pecas_soma OWNER TO postgres;

--
-- Name: perfil; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.perfil (
    perfil_id integer NOT NULL,
    perfil_descricao character(150),
    perfil_data date,
    perfil_usuario integer
);


ALTER TABLE public.perfil OWNER TO postgres;

--
-- Name: perfil_perfil_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.perfil_perfil_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perfil_perfil_id_seq OWNER TO postgres;

--
-- Name: perfil_perfil_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.perfil_perfil_id_seq OWNED BY public.perfil.perfil_id;


--
-- Name: plano_contas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plano_contas (
    plc_id integer NOT NULL,
    plc_classificacao character(20),
    plc_descricao character(200),
    plc_codigo integer,
    pcl_inativar boolean DEFAULT false,
    pcl_despesas_fixas boolean DEFAULT false
);


ALTER TABLE public.plano_contas OWNER TO postgres;

--
-- Name: plano_contas_plc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.plano_contas_plc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.plano_contas_plc_id_seq OWNER TO postgres;

--
-- Name: plano_contas_plc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.plano_contas_plc_id_seq OWNED BY public.plano_contas.plc_id;


--
-- Name: plano_de_corte_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.plano_de_corte_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.plano_de_corte_id_seq OWNER TO postgres;

--
-- Name: plano_corte; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plano_corte (
    id integer DEFAULT nextval('public.plano_de_corte_id_seq'::regclass) NOT NULL,
    data date,
    usuario integer,
    usuario_alterou character(100),
    descricao character(200)
);


ALTER TABLE public.plano_corte OWNER TO postgres;

--
-- Name: pop_pop_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pop_pop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pop_pop_id_seq OWNER TO postgres;

--
-- Name: pop_fixo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pop_fixo (
    id integer DEFAULT nextval('public.pop_pop_id_seq'::regclass) NOT NULL,
    data date,
    usuario integer,
    usuario_alterou character(100),
    descricao character(200),
    objetivo character(1000),
    setor integer,
    validade date,
    frequencia integer,
    codigo character(6),
    versao integer,
    pode_alterar boolean DEFAULT true,
    ativo boolean DEFAULT true
);


ALTER TABLE public.pop_fixo OWNER TO postgres;

--
-- Name: pop_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pop_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pop_item_id_seq OWNER TO postgres;

--
-- Name: pop_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pop_item (
    id integer DEFAULT nextval('public.pop_item_id_seq'::regclass) NOT NULL,
    pop_id integer,
    programa character(90),
    descricao character(1000),
    acao integer,
    sequencia integer
);


ALTER TABLE public.pop_item OWNER TO postgres;

--
-- Name: prioridade_prioridade_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.prioridade_prioridade_codigo_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.prioridade_prioridade_codigo_seq OWNER TO postgres;

--
-- Name: prioridade; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prioridade (
    prioridade_id integer NOT NULL,
    prioridade_codigo character(3) DEFAULT lpad(((nextval('public.prioridade_prioridade_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    prioridade_cor integer
);


ALTER TABLE public.prioridade OWNER TO postgres;

--
-- Name: prioridade_prioridade_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.prioridade_prioridade_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.prioridade_prioridade_id_seq OWNER TO postgres;

--
-- Name: prioridade_prioridade_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.prioridade_prioridade_id_seq OWNED BY public.prioridade.prioridade_id;


--
-- Name: processo_tigimento_processo_tigimento_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.processo_tigimento_processo_tigimento_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.processo_tigimento_processo_tigimento_codigo_seq OWNER TO postgres;

--
-- Name: processo_tigimento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.processo_tigimento (
    processo_tigimento_id integer NOT NULL,
    processo_tigimento_descricao character(50) NOT NULL,
    processo_tigimento_banho numeric(15,4),
    processo_tigimento_codigo character(3) DEFAULT lpad(((nextval('public.processo_tigimento_processo_tigimento_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    processo_tigimento_unidade character(4),
    processo_tigimento_selecionada character(1),
    processo_tigimento_integracao character(5),
    processo_tigimento_mascara character(5),
    processo_tigimento_inativo boolean
);


ALTER TABLE public.processo_tigimento OWNER TO postgres;

--
-- Name: processo_tigimento_processo_tigimento_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.processo_tigimento_processo_tigimento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.processo_tigimento_processo_tigimento_id_seq OWNER TO postgres;

--
-- Name: processo_tigimento_processo_tigimento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.processo_tigimento_processo_tigimento_id_seq OWNED BY public.processo_tigimento.processo_tigimento_id;


--
-- Name: quadros_quadros_cilindro_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.quadros_quadros_cilindro_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.quadros_quadros_cilindro_codigo_seq OWNER TO postgres;

--
-- Name: quadros_cilindro; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.quadros_cilindro (
    quadros_cilindro_id integer NOT NULL,
    quadros_cilindro_codigo character(3) DEFAULT lpad(((nextval('public.quadros_quadros_cilindro_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    quadros_cilindro_descricao character(300),
    quadros_cilindro_endereco character(20),
    quadros_cilindro_deposito character(3),
    quadros_cilindro_data date,
    quadros_cilindro_data_cadastro date,
    quadros_cilindro_hora character(10),
    quadros_cilindro_tipo integer,
    quadros_cilindro_usuario_id integer,
    quadros_cilindro_usuario_id_alteracao integer,
    quadros_cilindro_data_alteracao character(20),
    quadros_cilindro_inativar boolean,
    quadros_cilindro_aa50id integer,
    quadros_cilindro_nota_fiscal character(9),
    quadros_cilindro_fornecedor integer,
    quadros_cilindro_unidade_medida integer,
    quadros_cilindro_quantidade numeric(18,2),
    quadros_cilindro_mts numeric(18,2),
    quadros_cilindro_obs character(400),
    quadros_cilindro_encerramento date,
    quadros_cilindro_transferiu boolean,
    quadros_cilindro_metros_transferidos numeric(18,2),
    quadros_cilindro_transferiu_para_bobina integer,
    quadros_cilindro_metros_encerrados numeric(18,2),
    quadros_cilindro_transferiu_para_bobina_codigo character(3),
    quadros_cilindro_valor numeric(18,2),
    sequencia character(3),
    quadros_cilindro_lote integer
);


ALTER TABLE public.quadros_cilindro OWNER TO postgres;

--
-- Name: quadros_cilindro_quadros_cilindro_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.quadros_cilindro_quadros_cilindro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.quadros_cilindro_quadros_cilindro_id_seq OWNER TO postgres;

--
-- Name: quadros_cilindro_quadros_cilindro_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.quadros_cilindro_quadros_cilindro_id_seq OWNED BY public.quadros_cilindro.quadros_cilindro_id;


--
-- Name: qualidade; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.qualidade (
    qual_id integer NOT NULL,
    qual_descricao character(15),
    qual_letra character(1)
);


ALTER TABLE public.qualidade OWNER TO postgres;

--
-- Name: qualidade_qual_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.qualidade_qual_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qualidade_qual_id_seq OWNER TO postgres;

--
-- Name: qualidade_qual_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.qualidade_qual_id_seq OWNED BY public.qualidade.qual_id;


--
-- Name: receita_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.receita_item (
    ri_id integer NOT NULL,
    ri_receita_id integer NOT NULL,
    ri_receita_referencia character(10),
    ri_familia_id integer,
    ri_familia_codigo character(3),
    ri_familia_nome character(60),
    ri_tipo_id integer,
    ri_tipo_codigo character(3),
    ri_tipo_nome character(60),
    ri_sequencia character(3),
    ri_sequencia2 character(1),
    ri_componente_id integer,
    ri_componente_referencia character(10),
    ri_componente_nome character(80),
    ri_componente_nivel integer,
    ri_alternativa character(2),
    ri_unidade_medida character(3),
    ri_consumo numeric(15,6),
    ri_perda numeric(10,3),
    ri_letra character(5),
    ri_estagio_id integer,
    ri_estagio_codigo character(2),
    ri_estagio_nome character(60),
    ri_grafico_id integer,
    ri_grafico_codigo character(6),
    ri_grafico_nome character(50),
    ri_preco numeric(15,6),
    ri_calculo character(3),
    ri_calculo_nome character(50),
    ri_tipo_tbl character(2),
    ri_observacao text,
    ri_componente_ipi numeric(5,2) DEFAULT 0.00,
    ri_componente_aliquota_pis numeric(5,2),
    ri_componente_aliquota_cofins numeric(5,2) DEFAULT 0.00,
    ri_fator integer,
    ri_correcoes numeric(18,4)
);


ALTER TABLE public.receita_item OWNER TO postgres;

--
-- Name: receita_item_ri_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.receita_item_ri_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.receita_item_ri_id_seq OWNER TO postgres;

--
-- Name: receita_item_ri_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.receita_item_ri_id_seq OWNED BY public.receita_item.ri_id;


--
-- Name: referencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.referencia (
    ref_id integer NOT NULL,
    ref_nome character(10) NOT NULL
);


ALTER TABLE public.referencia OWNER TO postgres;

--
-- Name: referencia_ref_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.referencia_ref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.referencia_ref_id_seq OWNER TO postgres;

--
-- Name: referencia_ref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.referencia_ref_id_seq OWNED BY public.referencia.ref_id;


--
-- Name: relacao_composicao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.relacao_composicao_id_seq
    START WITH 4146
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.relacao_composicao_id_seq OWNER TO postgres;

--
-- Name: relacao_composicao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.relacao_composicao (
    id integer DEFAULT nextval('public.relacao_composicao_id_seq'::regclass) NOT NULL,
    idpai integer,
    idprincipal integer,
    nivel character(1)
);


ALTER TABLE public.relacao_composicao OWNER TO postgres;

--
-- Name: relacao_fluxo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.relacao_fluxo (
    rflx_id integer NOT NULL,
    rflx_flx_id integer,
    rflx_flxi_id integer,
    rflx_descricao character(150),
    rflx_cor integer
);


ALTER TABLE public.relacao_fluxo OWNER TO postgres;

--
-- Name: relacao_fluxo_rflx_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.relacao_fluxo_rflx_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.relacao_fluxo_rflx_id_seq OWNER TO postgres;

--
-- Name: relacao_fluxo_rflx_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.relacao_fluxo_rflx_id_seq OWNED BY public.relacao_fluxo.rflx_id;


--
-- Name: relacao_ob_pb; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.relacao_ob_pb (
    rop_ob_id integer NOT NULL,
    rop_pb_id integer NOT NULL
);


ALTER TABLE public.relacao_ob_pb OWNER TO postgres;

--
-- Name: relacao_produto_os; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.relacao_produto_os (
    id integer NOT NULL,
    aa50id integer,
    estampas_id integer,
    aa80id integer,
    os_id integer,
    data character(10),
    hora character(10),
    id_user integer,
    preco_cotacao numeric(18,2),
    coeficiente numeric(18,3),
    representante_id integer,
    preco_sistema numeric(18,2),
    coeficiente_sistema numeric(18,2),
    preco_scrap numeric(18,2)
);


ALTER TABLE public.relacao_produto_os OWNER TO postgres;

--
-- Name: relacao_produto_os_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.relacao_produto_os_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.relacao_produto_os_id_seq OWNER TO postgres;

--
-- Name: relacao_produto_os_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.relacao_produto_os_id_seq OWNED BY public.relacao_produto_os.id;


--
-- Name: relatorio229_comissoes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.relatorio229_comissoes AS
 SELECT sql."OBS",
    sql.id_tab,
    sql.pd_codigo,
    sql.df10documento,
    sql.df10dtemissao,
    sql.df10dtpagamento,
    sql.aa80na,
    sql.df10repres_cod,
    sql."REPRESENTANTE",
    sql."PEDIDOS",
    sql."DESCONTO",
    sql."ACRESCIMOS",
    sql."VALOR",
    sql."COMISSAO",
    sql.comissao_verificada
   FROM ( SELECT ''::character(50) AS "OBS",
            '10'::text AS id_tab,
            pd_fixo.pd_codigo,
            df10.df10documento,
            df10.df10dtemissao,
            df10.df10dtpagamento,
            (aa80.aa80na)::character varying(90) AS aa80na,
            df10.df10repres_cod,
            ( SELECT aa80_1.aa80na
                   FROM public.aa80 aa80_1
                  WHERE (aa80_1.aa80codigo = df10.df10repres_cod)) AS "REPRESENTANTE",
                CASE
                    WHEN (pd_fixo.pd_codigo IS NULL) THEN df10.df10documento
                    ELSE pd_fixo.pd_codigo
                END AS "PEDIDOS",
            COALESCE(sum(df10.df10acrescimos), (0)::numeric) AS "ACRESCIMOS",
            COALESCE(sum(df10.df10desconto), (0)::numeric) AS "DESCONTO",
            COALESCE(sum(df10.df10liquido), (0)::numeric) AS "VALOR",
            COALESCE(sum(df10.df10repres_comisao_valor), (0)::numeric) AS "COMISSAO",
            ((COALESCE(sum((df10.df10liquido * df10.df10repres_comisao)), (0)::numeric) / (100)::numeric))::numeric(15,2) AS comissao_verificada
           FROM (((public.df10
             LEFT JOIN public.nf_fixa ON ((nf_fixa.nota_numero_doc = df10.df10documento)))
             LEFT JOIN public.pd_fixo ON ((pd_fixo.pd_romaneio = nf_fixa.nota_romaneio)))
             JOIN public.aa80 ON ((aa80.aa80id = df10.df10entidadeid)))
          WHERE ((df10.df10repres_cod IS NOT NULL) AND (df10.df10ativo = 0) AND (df10.df10rec_pag = '0'::"char") AND (df10.df10repres_comisao_valor <> (0)::numeric))
          GROUP BY (''::character(50)), '10'::text, pd_fixo.pd_codigo, df10.df10documento, df10.df10dtemissao, df10.df10dtpagamento, ((aa80.aa80na)::character varying(90)), df10.df10repres_cod
        UNION
         SELECT (dfgc.dfgcobservacao)::character(50) AS "OBS",
            '10'::text AS id_tab,
            ('GC-'::text || lpad(((dfgc.dfgcid)::character varying)::text, 6, '0'::text)) AS pd_codigo,
            (dfgc.dfgcid)::character varying(1) AS df10documento,
            dfgc.dfgcdata_emissao AS df10dtemissao,
            dfgc.dfgcdata_pagamento AS df10dtpagamento,
            '*AJUSTE DE COMISSÃO*'::character varying AS aa80na,
            'x'::bpchar AS df10repres_cod,
            ( SELECT aa80.aa80na
                   FROM public.aa80
                  WHERE (aa80.aa80codigo = dfgc.dfgcrepresentante_cod)) AS "REPRESENTANTE",
            ('GC-'::text || lpad(((dfgc.dfgcid)::character varying)::text, 6, '0'::text)) AS "PEDIDOS",
            0 AS "ACRESCIMOS",
            0 AS "DESCONTO",
            (dfgc.dfgcvalortitulo * ('-1'::integer)::numeric) AS "VALOR",
            dfgc.dfgcvalor AS "COMISSAO",
            0 AS "COMISSAO_verificada"
           FROM public.dfgc) sql
  ORDER BY sql."REPRESENTANTE", sql.df10dtemissao, sql.df10documento, sql.id_tab;


ALTER TABLE public.relatorio229_comissoes OWNER TO postgres;

--
-- Name: retorno_producao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.retorno_producao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.retorno_producao_id_seq OWNER TO postgres;

--
-- Name: retorno_producao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.retorno_producao (
    id integer DEFAULT nextval('public.retorno_producao_id_seq'::regclass) NOT NULL,
    os_id integer,
    data date,
    usuario integer,
    usuario_conferiu integer,
    observacao character(100),
    qtde numeric(18,2)
);


ALTER TABLE public.retorno_producao OWNER TO postgres;

--
-- Name: revisa_papel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.revisa_papel (
    rev_papel_id integer NOT NULL,
    rev_papel_bobina_id integer,
    rev_papel_metros numeric(18,2),
    rev_papel_emendas integer,
    rev_papel_percas numeric(18,2),
    rev_papel_operador_id integer,
    rev_papel_data date,
    rev_papel_hora character(12)
);


ALTER TABLE public.revisa_papel OWNER TO postgres;

--
-- Name: revisa_papel_rev_papel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.revisa_papel_rev_papel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.revisa_papel_rev_papel_id_seq OWNER TO postgres;

--
-- Name: revisa_papel_rev_papel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.revisa_papel_rev_papel_id_seq OWNED BY public.revisa_papel.rev_papel_id;


--
-- Name: rolos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rolos (
    rolos_id integer NOT NULL,
    rolos_os_id integer,
    rolos_ob_id integer,
    rolos_bobina_id integer,
    rolos_data date,
    rolos_usuario_id integer,
    rolos_operador integer,
    rolos_hora character(10),
    rolos_metros numeric(18,2),
    rolos_peso numeric(18,2),
    rolos_ativo boolean,
    rolos_operador_cancelou integer,
    rolo_data_cancelou date,
    rolos_hora_cancelou character(20),
    rolos_motivo_cancelou character(200),
    rolos_observacao character(300)
);


ALTER TABLE public.rolos OWNER TO postgres;

--
-- Name: rolos_rolos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rolos_rolos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rolos_rolos_id_seq OWNER TO postgres;

--
-- Name: rolos_rolos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rolos_rolos_id_seq OWNED BY public.rolos.rolos_id;


--
-- Name: rolos_deletados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rolos_deletados (
    rolos_id integer DEFAULT nextval('public.rolos_rolos_id_seq'::regclass) NOT NULL,
    rolos_os_id integer,
    rolos_ob_id integer,
    rolos_bobina_id integer,
    rolos_data date,
    rolos_usuario_id integer,
    rolos_operador integer,
    rolos_hora character(10),
    rolos_metros numeric(18,2),
    rolos_peso numeric(18,2),
    rolos_ativo boolean,
    rolos_operador_cancelou integer,
    rolo_data_cancelou date,
    rolos_hora_cancelou character(20),
    rolos_motivo_cancelou character(200),
    rolos_observacao character(300)
);


ALTER TABLE public.rolos_deletados OWNER TO postgres;

--
-- Name: romaneio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.romaneio (
    rom_id integer NOT NULL,
    rom_tipo integer,
    rom_empresa_id integer,
    rom_data date,
    rom_obs text,
    rom_gerado boolean DEFAULT false,
    rom_aa50id integer,
    rom_nf integer,
    rom_recebido boolean DEFAULT false,
    rom_entidade_id integer
);


ALTER TABLE public.romaneio OWNER TO postgres;

--
-- Name: romaneio_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.romaneio_item (
    romi_id integer NOT NULL,
    romi_rom_id integer,
    romi_pec_id integer,
    romi_peso numeric(12,2),
    romi_metros numeric(12,2),
    romi_nf_retorno integer,
    romi_nf_data date,
    romi_recebido character(1)
);


ALTER TABLE public.romaneio_item OWNER TO postgres;

--
-- Name: romaneio_item_romi_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.romaneio_item_romi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.romaneio_item_romi_id_seq OWNER TO postgres;

--
-- Name: romaneio_item_romi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.romaneio_item_romi_id_seq OWNED BY public.romaneio_item.romi_id;


--
-- Name: romaneio_rom_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.romaneio_rom_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.romaneio_rom_id_seq OWNER TO postgres;

--
-- Name: romaneio_rom_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.romaneio_rom_id_seq OWNED BY public.romaneio.rom_id;


--
-- Name: roteiro; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roteiro (
    roteiro_id integer NOT NULL,
    roteiro_descricao character(80) NOT NULL
);


ALTER TABLE public.roteiro OWNER TO postgres;

--
-- Name: roteiro_producao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roteiro_producao (
    roteiro_producao_id integer NOT NULL,
    roteiro_producao_estagio_id integer,
    roteiro_producao_estagio_codigo character(2) NOT NULL,
    roteiro_producao_estagio_descricao character(100),
    roteiro_producao_ordem numeric(2,0),
    roteiro_producao_centro_custo_maquina character(7),
    roteiro_producao_centro_custo_homem character(7),
    roteiro_producao_giro_cordas_voltas integer,
    roteiro_producao_velocidade numeric(8,2),
    roteiro_producao_grp_maq_cod character(4) NOT NULL,
    roteiro_producao_grp_maq_descricao character(80),
    roteiro_producao_unidade character(2) NOT NULL,
    roteiro_producao_tempo_maquina character(7),
    roteiro_producao_tempo_homem character(7),
    roteiro_producao_temperatura numeric(5,3),
    roteiro_producao_roteiro_id integer NOT NULL
);


ALTER TABLE public.roteiro_producao OWNER TO postgres;

--
-- Name: roteiro_producao_roteiro_producao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.roteiro_producao_roteiro_producao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.roteiro_producao_roteiro_producao_id_seq OWNER TO postgres;

--
-- Name: roteiro_producao_roteiro_producao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roteiro_producao_roteiro_producao_id_seq OWNED BY public.roteiro_producao.roteiro_producao_id;


--
-- Name: roteiro_roteiro_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.roteiro_roteiro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.roteiro_roteiro_id_seq OWNER TO postgres;

--
-- Name: roteiro_roteiro_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roteiro_roteiro_id_seq OWNED BY public.roteiro.roteiro_id;


--
-- Name: rpai_filho; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rpai_filho (
    rpai_filho_id integer NOT NULL,
    rpai_filho_pai integer,
    rpai_filho_filho integer
);


ALTER TABLE public.rpai_filho OWNER TO postgres;

--
-- Name: rpai_filho_rpai_filho_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rpai_filho_rpai_filho_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rpai_filho_rpai_filho_id_seq OWNER TO postgres;

--
-- Name: rpai_filho_rpai_filho_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rpai_filho_rpai_filho_id_seq OWNED BY public.rpai_filho.rpai_filho_id;


--
-- Name: sdc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sdc (
    sdc_id integer NOT NULL,
    sdc_codigo character(10),
    sdc_usuario integer,
    sdc_representante integer,
    sdc_exclusivo boolean DEFAULT false,
    sdc_dt_cadastro date,
    sdc_dt_liberacao date,
    sdc_dt_desenvolvimento date,
    sdc_aplicacao character(30),
    sdc_tarefa character(30),
    sdc_estampa_id integer,
    sdc_estampa_descricao character(50),
    sdc_observacoes text,
    sdc_data_inicial date,
    sdc_data_final date,
    sdc_finalidade integer,
    sdc_desenho integer,
    sdc_versao character(2),
    sdc_variante character(2),
    sdc_caminho_imagem character(400),
    sdc_matriz character(1),
    sdc_desenvolvedor integer,
    sdc_bandeira_print character(1),
    sdc_desenho_rapport_alteracao character(1),
    sdc_dt_nao_liberado date,
    sdc_qtde_padrao numeric(6,2),
    sdc_tema integer,
    sdc_descritivo character(90),
    sdc_artigo integer,
    sdc_espessura numeric(10,2),
    sdc_substrato integer,
    sdc_papel integer,
    sdc_gravacao integer,
    sdc_largura numeric(10,2),
    sdc_gramatura numeric(10,3),
    sdc_unidademedida character(2) DEFAULT 'MT'::bpchar,
    sdc_estamparia integer,
    sdc_estudio_id integer,
    sdc_estudio boolean DEFAULT false,
    sdc_descricao character(150),
    sdc_entidade integer,
    sdc_mt_min numeric(18,2),
    sdc_custos_id integer,
    sdc_dt_pedido date,
    sdc_prioridade integer DEFAULT 1
);


ALTER TABLE public.sdc OWNER TO postgres;

--
-- Name: sdc_aux; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sdc_aux (
    id integer NOT NULL,
    aplicacao character(20),
    sequencia integer,
    produto integer,
    item integer,
    qtde_aplicada numeric(20,4),
    preco numeric(20,4),
    sd_id integer,
    ativo boolean DEFAULT true,
    nivel integer,
    produto_base_id integer,
    qtde numeric(20,4),
    usuario_id integer,
    data_geracao timestamp without time zone,
    usuario_id_alterou integer
);


ALTER TABLE public.sdc_aux OWNER TO postgres;

--
-- Name: sdc_aux_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sdc_aux_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sdc_aux_id_seq OWNER TO postgres;

--
-- Name: sdc_aux_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sdc_aux_id_seq OWNED BY public.sdc_aux.id;


--
-- Name: sdc_item_cor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sdc_item_cor (
    id integer NOT NULL,
    sdc_id integer,
    estampas_id integer,
    cor_temporaria character(100),
    cor_data date,
    ativo boolean DEFAULT true,
    id_formulacao integer,
    qtde_placas integer,
    obs text
);


ALTER TABLE public.sdc_item_cor OWNER TO postgres;

--
-- Name: sdc_item_cor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sdc_item_cor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sdc_item_cor_id_seq OWNER TO postgres;

--
-- Name: sdc_item_cor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sdc_item_cor_id_seq OWNED BY public.sdc_item_cor.id;


--
-- Name: sdc_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sdc_log (
    sl_id integer NOT NULL,
    sl_sdc_id integer,
    sl_sdc_funcao integer,
    sl_data date,
    sl_usuario integer,
    sl_hora character(20),
    sl_observacao character(600),
    sl_funcao_descricao character(500)
);


ALTER TABLE public.sdc_log OWNER TO postgres;

--
-- Name: sdc_log_sl_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sdc_log_sl_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sdc_log_sl_id_seq OWNER TO postgres;

--
-- Name: sdc_log_sl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sdc_log_sl_id_seq OWNED BY public.sdc_log.sl_id;


--
-- Name: sdc_sdc_id_custos_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sdc_sdc_id_custos_seq
    START WITH 10000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sdc_sdc_id_custos_seq OWNER TO postgres;

--
-- Name: sdc_sdc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sdc_sdc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sdc_sdc_id_seq OWNER TO postgres;

--
-- Name: sdc_sdc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sdc_sdc_id_seq OWNED BY public.sdc.sdc_id;


--
-- Name: sdc_sdc_id_solicitacoes_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sdc_sdc_id_solicitacoes_seq
    START WITH 680
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sdc_sdc_id_solicitacoes_seq OWNER TO postgres;

--
-- Name: segmento_mercado_segmento_mercado_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.segmento_mercado_segmento_mercado_codigo_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.segmento_mercado_segmento_mercado_codigo_seq OWNER TO postgres;

--
-- Name: segmento_mercado; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.segmento_mercado (
    segmento_mercado_id integer NOT NULL,
    segmento_mercado_descricao character(50) NOT NULL,
    segmento_mercado_codigo character(3) DEFAULT lpad(((nextval('public.segmento_mercado_segmento_mercado_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    segmento_mercado_1 boolean,
    segmento_mercado_2 boolean,
    segmento_mercado_3 boolean,
    segmento_mercado_4 boolean,
    segmento_mercado_5 boolean,
    segmento_mercado_6 boolean,
    segmento_mercado_7 boolean,
    segmento_mercado_8 boolean,
    segmento_mercado_9 boolean,
    segmento_mercado_189 boolean,
    segmento_mercado_302 boolean DEFAULT true
);


ALTER TABLE public.segmento_mercado OWNER TO postgres;

--
-- Name: TABLE segmento_mercado; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.segmento_mercado IS 'Nome no sistema Família';


--
-- Name: segmento_mercado_segmento_mercado_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.segmento_mercado_segmento_mercado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.segmento_mercado_segmento_mercado_id_seq OWNER TO postgres;

--
-- Name: segmento_mercado_segmento_mercado_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.segmento_mercado_segmento_mercado_id_seq OWNED BY public.segmento_mercado.segmento_mercado_id;


--
-- Name: serie_serie_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.serie_serie_codigo_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.serie_serie_codigo_seq OWNER TO postgres;

--
-- Name: series_cor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.series_cor (
    series_cor_id integer NOT NULL,
    series_cor_descricao character(50) NOT NULL,
    series_cor_acrescimo numeric(4,4) DEFAULT 0.0000,
    series_cor_serie character(3) DEFAULT lpad(((nextval('public.serie_serie_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    series_cor_ordem character(4)
);


ALTER TABLE public.series_cor OWNER TO postgres;

--
-- Name: setores_cor_setores_cor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.setores_cor_setores_cor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.setores_cor_setores_cor_id_seq OWNER TO postgres;

--
-- Name: setores_cor_setores_cor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.setores_cor_setores_cor_id_seq OWNED BY public.series_cor.series_cor_id;


--
-- Name: setup_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.setup_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.setup_id_seq OWNER TO postgres;

--
-- Name: setup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.setup (
    id integer DEFAULT nextval('public.setup_id_seq'::regclass) NOT NULL,
    descricao character(50),
    maquina integer,
    desativar boolean DEFAULT false,
    usuario integer,
    data_inserida date
);


ALTER TABLE public.setup OWNER TO postgres;

--
-- Name: setup_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.setup_item_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.setup_item_id_seq OWNER TO postgres;

--
-- Name: setup_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.setup_item (
    id integer DEFAULT nextval('public.setup_item_id_seq'::regclass) NOT NULL,
    id_setup integer,
    estufa integer,
    r11 numeric(18,2),
    r12 numeric(18,2),
    r13 numeric(18,2),
    r14 numeric(18,2),
    t11 numeric(18,2),
    t12 numeric(18,2),
    t13 numeric(18,2),
    r21 numeric(18,2),
    r22 numeric(18,2),
    r23 numeric(18,2),
    r24 numeric(18,2),
    t21 numeric(18,2),
    t22 numeric(18,2),
    t23 numeric(18,2),
    t24 numeric(18,2),
    t31 numeric(18,2),
    t32 numeric(18,2),
    t33 numeric(18,2),
    t34 numeric(18,2),
    r31 numeric(18,2),
    r32 numeric(18,2),
    r33 numeric(18,2),
    r34 numeric(18,2),
    mi_1 numeric(18,2),
    ms_1 numeric(18,2),
    mi_2 numeric(18,2),
    ms_2 numeric(18,2),
    mi_3 numeric(18,2),
    ms_3 numeric(18,2),
    mi_4 numeric(18,2),
    ms_4 numeric(18,2),
    mi_5 numeric(18,2),
    ms_5 numeric(18,2),
    mi_6 numeric(18,2),
    ms_6 numeric(18,2)
);


ALTER TABLE public.setup_item OWNER TO postgres;

--
-- Name: setup_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.setup_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.setup_log_id_seq OWNER TO postgres;

--
-- Name: setup_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.setup_log (
    id integer DEFAULT nextval('public.setup_log_id_seq'::regclass) NOT NULL,
    produto integer,
    setup_id integer,
    usuario integer,
    data_mvto date,
    hora character(12),
    obs text
);


ALTER TABLE public.setup_log OWNER TO postgres;

--
-- Name: setup_maquinas_setup_maquinas_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.setup_maquinas_setup_maquinas_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.setup_maquinas_setup_maquinas_codigo_seq OWNER TO postgres;

--
-- Name: setup_maquinas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.setup_maquinas (
    setup_maquinas_id integer NOT NULL,
    setup_maquinas_codigo character(3) DEFAULT lpad(((nextval('public.setup_maquinas_setup_maquinas_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    setup_maquinas_descricao character(50) NOT NULL,
    setup_maquinas_estagio character(2),
    setup_maquinas_area character(3),
    setup_maquinas_tempo numeric(15,4)
);


ALTER TABLE public.setup_maquinas OWNER TO postgres;

--
-- Name: setup_maquinas_setup_maquinas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.setup_maquinas_setup_maquinas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.setup_maquinas_setup_maquinas_id_seq OWNER TO postgres;

--
-- Name: setup_maquinas_setup_maquinas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.setup_maquinas_setup_maquinas_id_seq OWNED BY public.setup_maquinas.setup_maquinas_id;


--
-- Name: simulacoes_cenario_sces_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.simulacoes_cenario_sces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.simulacoes_cenario_sces_id_seq OWNER TO postgres;

--
-- Name: simulacoes_cenario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.simulacoes_cenario (
    sces_id integer DEFAULT nextval('public.simulacoes_cenario_sces_id_seq'::regclass) NOT NULL,
    sces_idsimulacao integer,
    sces_aa50id integer,
    sces_produto character(200),
    sces_precopraticado numeric(18,2),
    sces_qtde numeric(18,2),
    sces_faturamento numeric(18,2),
    sces_despesasrateio numeric(18,2),
    sces_custo_variavel_obs character(250),
    sces_custo_variavel numeric(18,2),
    sces_margem_obs character(250),
    sces_margem_contribuicao numeric(18,2),
    sces_margem_lucro_obs character(250),
    sces_margem_lucro numeric(18,2),
    sces_comissao numeric(18,2),
    sces_imposto numeric(18,2),
    sces_markup_obs character(250),
    sces_markup numeric(18,2),
    sces_percentual_mix_obs character(250),
    sces_percentual_mix numeric(18,2),
    sces_margem_contribuicao_perc numeric(18,2),
    sces_margem_contribuicao_perc_obs character(200),
    sces_margem_lucro_perc numeric(18,2),
    sces_margem_lucro_perc_obs character(200)
);


ALTER TABLE public.simulacoes_cenario OWNER TO postgres;

--
-- Name: simulacoes_despesas_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.simulacoes_despesas_item_id_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.simulacoes_despesas_item_id_seq OWNER TO postgres;

--
-- Name: simulacoes_despesas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.simulacoes_despesas (
    sdes_id integer DEFAULT nextval('public.simulacoes_despesas_item_id_seq'::regclass) NOT NULL,
    sdes_des_id integer,
    sdes_idsimulacoes integer,
    sdes_descricao character(200),
    sdes_valor numeric(18,2)
);


ALTER TABLE public.simulacoes_despesas OWNER TO postgres;

--
-- Name: simulacoes_fixa_sfi_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.simulacoes_fixa_sfi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.simulacoes_fixa_sfi_id_seq OWNER TO postgres;

--
-- Name: simulacoes_fixa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.simulacoes_fixa (
    sfi_id integer DEFAULT nextval('public.simulacoes_fixa_sfi_id_seq'::regclass) NOT NULL,
    sfi_descricao character(200),
    sfi_data date,
    sfi_usuario integer,
    sfi_periodo_ini date,
    sfi_periodo_fim date,
    sfi_produzidos_reais numeric(18,2),
    sfi_despesas_por_unidade numeric(18,2)
);


ALTER TABLE public.simulacoes_fixa OWNER TO postgres;

--
-- Name: simulacoes_funcionarios_sfu_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.simulacoes_funcionarios_sfu_id_seq
    START WITH 223
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.simulacoes_funcionarios_sfu_id_seq OWNER TO postgres;

--
-- Name: simulacoes_funcionarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.simulacoes_funcionarios (
    sfu_id integer DEFAULT nextval('public.simulacoes_funcionarios_sfu_id_seq'::regclass) NOT NULL,
    sfu_idfuncionario integer,
    sfu_nomefuncionario character(200),
    sfu_idsimulacoes integer,
    sfu_tipo_contrato integer,
    sfu_salario numeric(18,2),
    sfu_vale_refeicao numeric(18,2),
    sfu_convenio numeric(18,2),
    sfu_cargo_id integer,
    sfu_cargo_nome character(200),
    sfu_carga_horaria numeric(18,2),
    sfu_encargos_sociais numeric(18,2),
    sfu_encargos_trabalhistas numeric(18,2),
    sfu_vale_transporte numeric(18,2)
);


ALTER TABLE public.simulacoes_funcionarios OWNER TO postgres;

--
-- Name: simulacoes_impostos_simp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.simulacoes_impostos_simp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.simulacoes_impostos_simp_id_seq OWNER TO postgres;

--
-- Name: simulacoes_impostos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.simulacoes_impostos (
    simp_id integer DEFAULT nextval('public.simulacoes_impostos_simp_id_seq'::regclass) NOT NULL,
    simp_idcenario integer,
    simp_idnota integer,
    simp_idnota_item integer,
    simp_nota character(12),
    simp_idproduto integer,
    simp_valor numeric(18,2)
);


ALTER TABLE public.simulacoes_impostos OWNER TO postgres;

--
-- Name: sobras; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sobras (
    sobras_id integer NOT NULL,
    sobras_os_id integer,
    sobras_data date,
    sobras_considerar boolean DEFAULT true
);


ALTER TABLE public.sobras OWNER TO postgres;

--
-- Name: sobras_sobras_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sobras_sobras_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sobras_sobras_id_seq OWNER TO postgres;

--
-- Name: sobras_sobras_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sobras_sobras_id_seq OWNED BY public.sobras.sobras_id;


--
-- Name: solicitacao_compras; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.solicitacao_compras (
    sc_id integer NOT NULL,
    sc_data date,
    sc_usuario_id integer,
    sc_observacao character(400),
    sc_cc_id integer,
    sc_status integer DEFAULT 0,
    sc_classificacao integer,
    sc_hora character(30),
    sc_tipo integer,
    sc_nivel_urgencia integer,
    sc_codigo character(10),
    sc_nivel_produto integer,
    sc_recebimento integer DEFAULT 0,
    sc_marcourecebido character(300),
    sc_ativo boolean DEFAULT true,
    sc_tipo_doc integer
);


ALTER TABLE public.solicitacao_compras OWNER TO postgres;

--
-- Name: solicitacao_compras_aplicacao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.solicitacao_compras_aplicacao (
    sca_id integer NOT NULL,
    sca_sci_id integer,
    sci_ondeusa_id integer
);


ALTER TABLE public.solicitacao_compras_aplicacao OWNER TO postgres;

--
-- Name: solicitacao_compras_aplicacao_sca_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.solicitacao_compras_aplicacao_sca_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.solicitacao_compras_aplicacao_sca_id_seq OWNER TO postgres;

--
-- Name: solicitacao_compras_aplicacao_sca_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.solicitacao_compras_aplicacao_sca_id_seq OWNED BY public.solicitacao_compras_aplicacao.sca_id;


--
-- Name: solicitacao_compras_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.solicitacao_compras_item (
    sci_id integer NOT NULL,
    sci_sc_id integer,
    sci_ordem integer,
    sci_produto integer,
    sci_cor integer,
    sci_qtde numeric(20,4),
    sci_unitario numeric(20,4),
    sci_ipi numeric(20,4),
    sci_icms numeric(20,4),
    sci_observacao character(140)
);


ALTER TABLE public.solicitacao_compras_item OWNER TO postgres;

--
-- Name: solicitacao_compras_item_sci_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.solicitacao_compras_item_sci_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.solicitacao_compras_item_sci_id_seq OWNER TO postgres;

--
-- Name: solicitacao_compras_item_sci_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.solicitacao_compras_item_sci_id_seq OWNED BY public.solicitacao_compras_item.sci_id;


--
-- Name: solicitacao_compras_nivel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.solicitacao_compras_nivel (
    sc_compras_nivel_id integer NOT NULL,
    sc_compras_nivel_descricao character(80),
    sc_compras_nivel_valor integer
);


ALTER TABLE public.solicitacao_compras_nivel OWNER TO postgres;

--
-- Name: solicitacao_compras_nivel_sc_compras_nivel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.solicitacao_compras_nivel_sc_compras_nivel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.solicitacao_compras_nivel_sc_compras_nivel_id_seq OWNER TO postgres;

--
-- Name: solicitacao_compras_nivel_sc_compras_nivel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.solicitacao_compras_nivel_sc_compras_nivel_id_seq OWNED BY public.solicitacao_compras_nivel.sc_compras_nivel_id;


--
-- Name: solicitacao_compras_sc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.solicitacao_compras_sc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.solicitacao_compras_sc_id_seq OWNER TO postgres;

--
-- Name: solicitacao_compras_sc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.solicitacao_compras_sc_id_seq OWNED BY public.solicitacao_compras.sc_id;


--
-- Name: solicitacao_desenvolvimento_cor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.solicitacao_desenvolvimento_cor (
    solicitacao_desenvolvimento_cor_solicitante character(50),
    solicitacao_desenvolvimento_cor_setor_solicitante character(50),
    solicitacao_desenvolvimento_cor_nova character(1),
    solicitacao_desenvolvimento_cor_prazo numeric(3,0),
    solicitacao_desenvolvimento_cor_observacoes text,
    solicitacao_desenvolvimento_cor_data_solicitacao date,
    solicitacao_desenvolvimento_cor_usuario_codigo character(4),
    solicitacao_desenvolvimento_cor_situacao character(30) NOT NULL,
    solicitacao_desenvolvimento_cor_cliente character(10),
    solicitacao_desenvolvimento_cor_alternativa character(2),
    solicitacao_desenvolvimento_cor_data_prevista date,
    solicitacao_desenvolvimento_cor_encerrado character(1),
    solicitacao_desenvolvimento_tipo character(50),
    solicitacao_desenvolvimento_cor_data_alteracao date,
    solicitacao_desenvolvimento_cor_codigo character(3) NOT NULL,
    solicitacao_desenvolvimento_cor_aplicacao text,
    solicitacao_desenvolvimento_cor_representante character(10),
    solicitacao_desenvolvimento_cor_caracteristicas character(15) NOT NULL,
    solicitacao_desenvolvimento_cor_lancado time without time zone,
    solicitacao_desenvolvimento_cor_id integer NOT NULL,
    solicitacao_desenvolvimento_cor_produto integer,
    solicitacao_desenvolvimento_cor_prioridade character(15) NOT NULL,
    solicitacao_desenvolvimento_cor_hora_prevista time without time zone,
    solicitacao_desenvolvimento_cor_lab_nome character(40),
    solicitacao_desenvolvimento_cor_lab_previsao date,
    solicitacao_desenvolvimento_cor_lab_entrega date,
    solicitacao_desenvolvimento_cor_situacao_codigo character(2) NOT NULL,
    solicitacao_desenvolvimento_cor_lab_hora time without time zone,
    solicitacao_desenvolvimento_cor_editar boolean DEFAULT true NOT NULL
);


ALTER TABLE public.solicitacao_desenvolvimento_cor OWNER TO postgres;

--
-- Name: solicitacao_desenvolvimento_c_solicitacao_desenvolvimento_c_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.solicitacao_desenvolvimento_c_solicitacao_desenvolvimento_c_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.solicitacao_desenvolvimento_c_solicitacao_desenvolvimento_c_seq OWNER TO postgres;

--
-- Name: solicitacao_desenvolvimento_c_solicitacao_desenvolvimento_c_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.solicitacao_desenvolvimento_c_solicitacao_desenvolvimento_c_seq OWNED BY public.solicitacao_desenvolvimento_cor.solicitacao_desenvolvimento_cor_id;


--
-- Name: tab_cest; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tab_cest (
    cest character varying(7) NOT NULL,
    ncm character varying(8),
    descricao character varying(512)
);


ALTER TABLE public.tab_cest OWNER TO postgres;

--
-- Name: tabela_custo_hora_tbc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tabela_custo_hora_tbc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tabela_custo_hora_tbc_id_seq OWNER TO postgres;

--
-- Name: tabela_custo_hora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tabela_custo_hora (
    tbc_id integer DEFAULT nextval('public.tabela_custo_hora_tbc_id_seq'::regclass) NOT NULL,
    tbc_descricao character(100),
    tbc_data date,
    tbc_hora character(10)
);


ALTER TABLE public.tabela_custo_hora OWNER TO postgres;

--
-- Name: tabela_custo_hora_item_tbci_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tabela_custo_hora_item_tbci_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tabela_custo_hora_item_tbci_id_seq OWNER TO postgres;

--
-- Name: tabela_custo_hora_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tabela_custo_hora_item (
    tbci_id integer DEFAULT nextval('public.tabela_custo_hora_item_tbci_id_seq'::regclass) NOT NULL,
    tbci_tbc_id integer,
    tbci_operacao integer,
    tbci_terceiro boolean DEFAULT false,
    tbci_custo_hora numeric(18,2),
    tbci_custo_minuto numeric(18,2),
    tbci_ativo boolean DEFAULT true
);


ALTER TABLE public.tabela_custo_hora_item OWNER TO postgres;

--
-- Name: tabela_preco; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tabela_preco (
    tabela_preco_id integer NOT NULL,
    tabela_preco_desc character(80),
    tabela_data_ini date,
    tabela_data_fim date,
    tabela_moeda integer,
    tabela_tipo integer,
    tabela_obs_sistema character(50)
);


ALTER TABLE public.tabela_preco OWNER TO postgres;

--
-- Name: tabela_preco_tabela_preco_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tabela_preco_tabela_preco_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tabela_preco_tabela_preco_id_seq OWNER TO postgres;

--
-- Name: tabela_preco_tabela_preco_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tabela_preco_tabela_preco_id_seq OWNED BY public.tabela_preco.tabela_preco_id;


--
-- Name: telefones_tipos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.telefones_tipos (
    idtipo smallint NOT NULL,
    descricao character varying(20) NOT NULL
);


ALTER TABLE public.telefones_tipos OWNER TO postgres;

--
-- Name: tema; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tema (
    tema_id integer NOT NULL,
    tema_descricao character(150),
    tema_data date,
    tema_usuario integer
);


ALTER TABLE public.tema OWNER TO postgres;

--
-- Name: tema_tema_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tema_tema_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tema_tema_id_seq OWNER TO postgres;

--
-- Name: tema_tema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tema_tema_id_seq OWNED BY public.tema.tema_id;


--
-- Name: tipo_fornecedor_tpf_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipo_fornecedor_tpf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipo_fornecedor_tpf_id_seq OWNER TO postgres;

--
-- Name: tipo_fornecedor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_fornecedor (
    tpf_id integer DEFAULT nextval('public.tipo_fornecedor_tpf_id_seq'::regclass) NOT NULL,
    tpf_descricao text,
    tpf_selecionar boolean
);


ALTER TABLE public.tipo_fornecedor OWNER TO postgres;

--
-- Name: tipo_moveis_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipo_moveis_id_seq
    START WITH 40
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipo_moveis_id_seq OWNER TO postgres;

--
-- Name: tipo_moveis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_moveis (
    id integer DEFAULT nextval('public.tipo_moveis_id_seq'::regclass) NOT NULL,
    tipo_moveis character(200)
);


ALTER TABLE public.tipo_moveis OWNER TO postgres;

--
-- Name: tipo_produto_tipo_produto_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipo_produto_tipo_produto_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipo_produto_tipo_produto_codigo_seq OWNER TO postgres;

--
-- Name: tipo_produto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_produto (
    tipo_produto_id integer NOT NULL,
    tipo_produto_codigo character(3) DEFAULT lpad(((nextval('public.tipo_produto_tipo_produto_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    tipo_produto_descricao character(50) NOT NULL,
    tipo_produto_1 boolean,
    tipo_produto_2 boolean,
    tipo_produto_3 boolean,
    tipo_produto_4 boolean,
    tipo_produto_5 boolean,
    tipo_produto_6 boolean,
    tipo_produto_7 boolean,
    tipo_produto_8 boolean,
    tipo_produto_9 boolean,
    tipo_produto_exibe_302 boolean,
    tipo_produto_exibe_302_diario boolean,
    tipo_produto_atualiza_351 boolean DEFAULT true,
    tipo_produto_10 boolean,
    tipo_produto_381 boolean
);


ALTER TABLE public.tipo_produto OWNER TO postgres;

--
-- Name: tipo_produto_tipo_produto_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipo_produto_tipo_produto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipo_produto_tipo_produto_id_seq OWNER TO postgres;

--
-- Name: tipo_produto_tipo_produto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipo_produto_tipo_produto_id_seq OWNED BY public.tipo_produto.tipo_produto_id;


--
-- Name: tipos_calculo_tipos_calculo_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipos_calculo_tipos_calculo_codigo_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipos_calculo_tipos_calculo_codigo_seq OWNER TO postgres;

--
-- Name: tipos_calculo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_calculo (
    tipos_calculo_id integer NOT NULL,
    tipos_calculo_descricao character(50) NOT NULL,
    tipos_calculo_rel_comp numeric(1,0),
    tipos_calculo_rel_unidade numeric(15,3),
    tipos_calculo_codigo character(3) DEFAULT lpad(((nextval('public.tipos_calculo_tipos_calculo_codigo_seq'::regclass))::character(3))::text, 3, '0'::text)
);


ALTER TABLE public.tipos_calculo OWNER TO postgres;

--
-- Name: tipos_calculo_tipos_calculo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipos_calculo_tipos_calculo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipos_calculo_tipos_calculo_id_seq OWNER TO postgres;

--
-- Name: tipos_calculo_tipos_calculo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipos_calculo_tipos_calculo_id_seq OWNED BY public.tipos_calculo.tipos_calculo_id;


--
-- Name: tipos_desenhos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_desenhos (
    td_id integer NOT NULL,
    td_descricao character(150),
    td_data date,
    td_usuario integer
);


ALTER TABLE public.tipos_desenhos OWNER TO postgres;

--
-- Name: tipos_desenhos_td_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipos_desenhos_td_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipos_desenhos_td_id_seq OWNER TO postgres;

--
-- Name: tipos_desenhos_td_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipos_desenhos_td_id_seq OWNED BY public.tipos_desenhos.td_id;


--
-- Name: tipos_materia_prima_tipos_materia_prima_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipos_materia_prima_tipos_materia_prima_codigo_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipos_materia_prima_tipos_materia_prima_codigo_seq OWNER TO postgres;

--
-- Name: tipos_materia_prima; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_materia_prima (
    tipos_materia_prima_id integer NOT NULL,
    tipos_materia_prima_descricao character(50) NOT NULL,
    tipos_materia_prima_pesar numeric(1,0),
    tipos_materia_prima_qtd numeric(2,0),
    tipos_materia_prima_enviar numeric(1,0),
    tipos_materia_prima_etiqueta character(1) NOT NULL,
    tipos_materia_prima_digitacao character(1) NOT NULL,
    tipos_materia_prima_codigo character(3) DEFAULT lpad(((nextval('public.tipos_materia_prima_tipos_materia_prima_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL
);


ALTER TABLE public.tipos_materia_prima OWNER TO postgres;

--
-- Name: tipos_materia_prima_tipos_materia_prima_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipos_materia_prima_tipos_materia_prima_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipos_materia_prima_tipos_materia_prima_id_seq OWNER TO postgres;

--
-- Name: tipos_materia_prima_tipos_materia_prima_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipos_materia_prima_tipos_materia_prima_id_seq OWNED BY public.tipos_materia_prima.tipos_materia_prima_id;


--
-- Name: toque_toque_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.toque_toque_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.toque_toque_codigo_seq OWNER TO postgres;

--
-- Name: toque; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.toque (
    toque_id integer NOT NULL,
    toque_descricao character(50) NOT NULL,
    toque_codigo character(3) DEFAULT lpad(((nextval('public.toque_toque_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL
);


ALTER TABLE public.toque OWNER TO postgres;

--
-- Name: toque_toque_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.toque_toque_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.toque_toque_id_seq OWNER TO postgres;

--
-- Name: toque_toque_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.toque_toque_id_seq OWNED BY public.toque.toque_id;


--
-- Name: torcamento_torc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_torc_id_seq
    START WITH 321
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_torc_id_seq OWNER TO postgres;

--
-- Name: torcamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento (
    torc_id integer DEFAULT nextval('public.torcamento_torc_id_seq'::regclass) NOT NULL,
    torc_codigo character(8),
    torc_versao character(1),
    torc_dataorcamento date,
    torc_cliente_id integer,
    torc_cond_pagto integer,
    torc_prazo_entrega date,
    torc_validade date,
    torc_desconto numeric(18,2),
    torc_vl_ipi numeric(18,2),
    torc_tabela_id integer,
    torc_lancamento date,
    torc_lancamento_hora character(10),
    torc_dt_aprovacao date,
    torc_hora_aprovacao character(10),
    torc_valor_aprovado numeric(18,2),
    torc_vl_icms numeric(18,2),
    torc_usuario_responsavel integer,
    torc_inativar boolean DEFAULT false,
    torc_dt_inativou date,
    torc_hora_inativiou character(10),
    torc_motivo_inativou text,
    torc_cod_os integer,
    torc_validade_estagio date,
    torc_data_enviou_cliente date,
    torc_hora_enviou_cliente character(10),
    torc_enviou_cliente boolean DEFAULT false,
    torc_contato character(150),
    torc_titulo character(500),
    torc_cabecalho character(500),
    torc_obs character(500),
    torc_rodape character(500),
    torc_descricao character(500),
    torc_valor_orcamento numeric(20,5),
    torc_pedido character(10),
    torc_data_pedido date,
    torc_frete_valor numeric(20,2),
    torc_status integer DEFAULT 0,
    torc_tipo_pedido integer,
    torc_entrega_id integer,
    torc_cobranca_id integer,
    torc_representante_id integer,
    torc_motivo_perdeu text
);


ALTER TABLE public.torcamento OWNER TO postgres;

--
-- Name: torcamento_agrupamento_tgr_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_agrupamento_tgr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_agrupamento_tgr_id_seq OWNER TO postgres;

--
-- Name: torcamento_agrupamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_agrupamento (
    tgr_id integer DEFAULT nextval('public.torcamento_agrupamento_tgr_id_seq'::regclass) NOT NULL,
    tgr_idambiente integer,
    tgr_tipo integer,
    tgr_valor numeric(18,5),
    tgr_percentual numeric(10,2)
);


ALTER TABLE public.torcamento_agrupamento OWNER TO postgres;

--
-- Name: torcamento_ambiente_toa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_ambiente_toa_id_seq
    START WITH 650
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_ambiente_toa_id_seq OWNER TO postgres;

--
-- Name: torcamento_ambiente; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_ambiente (
    toa_id integer DEFAULT nextval('public.torcamento_ambiente_toa_id_seq'::regclass) NOT NULL,
    toa_ambiente integer,
    toa_movel integer,
    toa_descricao text,
    toa_detalhes text,
    toa_preco_geral_a_vista numeric(20,5),
    toa_replica character(1),
    toa_tipo_movel integer,
    toa_idorcamento integer,
    toa_user_inseriu integer,
    toa_inseriu_data date,
    toa_inseriu_hora character(10),
    toa_quantidade numeric(18,5),
    toa_item character(3),
    toa_ref_arquiteto character(50),
    toa_observacao_detalhes text,
    toa_aliq_lucro numeric(18,4),
    toa_valor_lucro numeric(18,2),
    toa_valor_ambiente numeric(18,4),
    toa_markup numeric(18,2),
    toa_aliq_simples_federal numeric(18,2),
    toa_valor_simples_federal numeric(14,2),
    toa_aliq_frete numeric(18,2),
    toa_valor_frete numeric(18,2),
    toa_aliq_embalagem numeric(18,2),
    toa_valor_embalagem numeric(18,2),
    toa_aliq_representante numeric(18,2),
    toa_valor_representante numeric(18,2),
    toa_complemento_ambiente character(1500),
    toa_complemento_movel character(1500),
    toa_descricao2 text,
    toa_idprod_acabado integer,
    toa_iditem_acabado integer,
    toa_idreceita integer,
    toa_qtde_devolver numeric(18,2),
    toa_valor_devolver numeric(18,2),
    toa_descricao_nf character(200),
    toa_aliq_desconto numeric(18,2),
    toa_valor_desconto numeric(18,2),
    toa_aliq_lucro_anterior numeric(18,4),
    toa_osid integer,
    toa_item_revisado boolean,
    toa_iduser_revisado integer,
    toa_data_revisao date,
    toa_hora_revisado character(20)
);


ALTER TABLE public.torcamento_ambiente OWNER TO postgres;

--
-- Name: torcamento_calc_tcalc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_calc_tcalc_id_seq
    START WITH 2791
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_calc_tcalc_id_seq OWNER TO postgres;

--
-- Name: torcamento_calc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_calc (
    tcalc_id integer DEFAULT nextval('public.torcamento_calc_tcalc_id_seq'::regclass) NOT NULL,
    tcalc_item integer,
    tcalc_d1 numeric(20,5),
    tcalc_d2 numeric(20,5),
    tcalc_d3 numeric(20,5),
    tcalc_quantidade numeric(18,5),
    tcalc_formato numeric(18,5)
);


ALTER TABLE public.torcamento_calc OWNER TO postgres;

--
-- Name: torcamento_contrato_tcon_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_contrato_tcon_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_contrato_tcon_id_seq OWNER TO postgres;

--
-- Name: torcamento_contrato; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_contrato (
    tcon_id integer DEFAULT nextval('public.torcamento_contrato_tcon_id_seq'::regclass) NOT NULL,
    tcon_idorcamento integer,
    tcon_cabecalho text,
    tcon_corpo text,
    tcon_rodape text,
    tcon_idusuario integer,
    tcon_usuario_data character(40),
    tcon_idusuario_alterou integer,
    tcon_idusuario_alterou_data character(40),
    tcon_garantia text,
    tcon_prazoentregaorcamento text,
    tcon_outrasinformacoes text,
    tcon_modeloaprovacao character(100),
    tcon_titulo text,
    tcon_observacoes text
);


ALTER TABLE public.torcamento_contrato OWNER TO postgres;

--
-- Name: torcamento_grupo_tgr_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_grupo_tgr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_grupo_tgr_id_seq OWNER TO postgres;

--
-- Name: torcamento_grupo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_grupo (
    tgr_id integer DEFAULT nextval('public.torcamento_grupo_tgr_id_seq'::regclass) NOT NULL,
    tgr_tipo integer,
    tgr_tipo_nome character(100),
    tgr_valor numeric(18,2),
    tgr_percentual numeric(18,2),
    tgr_idorcamento integer,
    tgr_idambiente integer
);


ALTER TABLE public.torcamento_grupo OWNER TO postgres;

--
-- Name: torcamento_item_tit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_item_tit_id_seq
    START WITH 18691
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_item_tit_id_seq OWNER TO postgres;

--
-- Name: torcamento_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_item (
    tit_id integer DEFAULT nextval('public.torcamento_item_tit_id_seq'::regclass) NOT NULL,
    tit_item character(3),
    tit_idambiente integer,
    tit_idorcamento integer,
    tit_produto integer,
    tit_produto_codigo character(20),
    tit_quantidade numeric(20,5),
    tit_unidade_compra character(20),
    tit_unidade_processo character(20),
    tit_custo numeric(18,5),
    tit_custo_original numeric(18,5),
    tit_d1 numeric(18,5),
    tit_d2 numeric(18,5),
    tit_d3 numeric(18,5),
    tit_perca_percentual numeric(18,5),
    tit_quantidade_formato numeric(18,5),
    tit_quantidade_utilizada numeric(18,5),
    tit_detalhes character(600),
    tit_quantidade_compra numeric(18,5),
    tit_custo_unitario numeric(18,5),
    tit_custo_unitario_original numeric(18,5),
    tit_compoe_custo boolean DEFAULT true,
    tit_quantidade_para_fazer_um numeric(18,5),
    tit_obs_precos character(500)
);


ALTER TABLE public.torcamento_item OWNER TO postgres;

--
-- Name: torcamento_log_tlo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_log_tlo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_log_tlo_id_seq OWNER TO postgres;

--
-- Name: torcamento_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_log (
    tlo_id integer DEFAULT nextval('public.torcamento_log_tlo_id_seq'::regclass) NOT NULL,
    tlo_descricao character(200),
    tlo_idusuario integer,
    tlo_idorcamento integer,
    tlo_versao character(2),
    tlo_data date,
    tlo_hora character(10)
);


ALTER TABLE public.torcamento_log OWNER TO postgres;

--
-- Name: torcamento_mo_tmo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_mo_tmo_id_seq
    START WITH 1528
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_mo_tmo_id_seq OWNER TO postgres;

--
-- Name: torcamento_mo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_mo (
    tmo_id integer DEFAULT nextval('public.torcamento_mo_tmo_id_seq'::regclass) NOT NULL,
    tmo_idambiente integer,
    tmo_idorcamento integer,
    tmo_operacao integer,
    tmo_qtde numeric(22,4),
    tmo_qtde_hora character(8),
    tmo_qtde_minuto integer,
    tmo_valor_hora numeric(18,2),
    tmo_valor_minuto numeric(20,7),
    tmo_seq character(2),
    tmo_qtde_extenso character(150),
    tmo_valor_item numeric(18,2),
    tmo_operacao_descricao character(200)
);


ALTER TABLE public.torcamento_mo OWNER TO postgres;

--
-- Name: torcamento_outros_custos_toc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_outros_custos_toc_id_seq
    START WITH 262
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_outros_custos_toc_id_seq OWNER TO postgres;

--
-- Name: torcamento_outros_custos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_outros_custos (
    toc_id integer DEFAULT nextval('public.torcamento_outros_custos_toc_id_seq'::regclass) NOT NULL,
    toc_idorcamento integer,
    toc_idambiente integer,
    toc_descricao character(200),
    toc_qtde numeric(18,4),
    toc_valor numeric(18,4),
    toc_item_valor numeric(18,4),
    toc_unidade character(10)
);


ALTER TABLE public.torcamento_outros_custos OWNER TO postgres;

--
-- Name: torcamento_pagamento_tpag_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_pagamento_tpag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_pagamento_tpag_id_seq OWNER TO postgres;

--
-- Name: torcamento_pagamento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_pagamento (
    tpag_id integer DEFAULT nextval('public.torcamento_pagamento_tpag_id_seq'::regclass) NOT NULL,
    tpag_condicoes_id integer,
    tpag_dias integer,
    tpag_valor numeric(18,2),
    tpag_percentual numeric(22,7),
    tpag_idorcamento integer,
    tpag_data date,
    tpag_observacoes character(300),
    tpag_manter_parcelas boolean DEFAULT false,
    tpag_tipo_calculo character(30)
);


ALTER TABLE public.torcamento_pagamento OWNER TO postgres;

--
-- Name: torcamento_responsanvel_tres_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_responsanvel_tres_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_responsanvel_tres_id_seq OWNER TO postgres;

--
-- Name: torcamento_responsavel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_responsavel (
    tres_id integer DEFAULT nextval('public.torcamento_responsanvel_tres_id_seq'::regclass) NOT NULL,
    tres_idorcamento integer,
    tres_idusuario integer
);


ALTER TABLE public.torcamento_responsavel OWNER TO postgres;

--
-- Name: torcamento_servicos_terceiros_tst_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.torcamento_servicos_terceiros_tst_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.torcamento_servicos_terceiros_tst_id_seq OWNER TO postgres;

--
-- Name: torcamento_servicos_terceiros; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.torcamento_servicos_terceiros (
    tst_id integer DEFAULT nextval('public.torcamento_servicos_terceiros_tst_id_seq'::regclass) NOT NULL,
    tst_idambiente integer,
    tst_idorcamento integer,
    tst_fornecedor_id integer,
    tst_fornecedor_livre character(100),
    tst_quantidade numeric(18,2),
    tst_valor numeric(18,2),
    tst_observacao character(200),
    tst_item_valor numeric(18,2)
);


ALTER TABLE public.torcamento_servicos_terceiros OWNER TO postgres;

--
-- Name: turno; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.turno (
    turno_id integer NOT NULL,
    turno_descricao character(50) NOT NULL
);


ALTER TABLE public.turno OWNER TO postgres;

--
-- Name: turno_turno_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.turno_turno_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.turno_turno_id_seq OWNER TO postgres;

--
-- Name: turno_turno_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.turno_turno_id_seq OWNED BY public.turno.turno_id;


--
-- Name: uf; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.uf (
    uf_descricao character(2) NOT NULL,
    uf_regiao character(20),
    uf_aliquota1 numeric(18,2),
    uf_aliquota2 numeric(18,2),
    uf_aliquota3 numeric(18,2),
    uf_aliquota_ibs numeric(18,2)
);


ALTER TABLE public.uf OWNER TO postgres;

--
-- Name: unidade_medida; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.unidade_medida (
    unidade_medida_id integer NOT NULL,
    unidade_medida_codigo character(4) NOT NULL,
    unidade_medida_descricao character(50),
    unidade_medida_padrao character(4)
);


ALTER TABLE public.unidade_medida OWNER TO postgres;

--
-- Name: unidade_medida_unidade_medida_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.unidade_medida_unidade_medida_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.unidade_medida_unidade_medida_id_seq OWNER TO postgres;

--
-- Name: unidade_medida_unidade_medida_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.unidade_medida_unidade_medida_id_seq OWNED BY public.unidade_medida.unidade_medida_id;


--
-- Name: utilidades_tecido_utilidades_tecido_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.utilidades_tecido_utilidades_tecido_codigo_seq
    START WITH 18
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.utilidades_tecido_utilidades_tecido_codigo_seq OWNER TO postgres;

--
-- Name: utilidades_tecido; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.utilidades_tecido (
    utilidades_tecido_id integer NOT NULL,
    utilidades_tecido_descricao character(50) NOT NULL,
    utilidades_tecido_codigo character(3) DEFAULT lpad(((nextval('public.utilidades_tecido_utilidades_tecido_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    utilidade_tecido_1 boolean,
    utilidade_tecido_2 boolean,
    utilidade_tecido_3 boolean,
    utilidade_tecido_4 boolean,
    utilidade_tecido_5 boolean,
    utilidade_tecido_6 boolean,
    utilidade_tecido_7 boolean,
    utilidade_tecido_8 boolean,
    utilidade_tecido_9 boolean
);


ALTER TABLE public.utilidades_tecido OWNER TO postgres;

--
-- Name: unidade_tecido_unidade_tecido_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.unidade_tecido_unidade_tecido_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.unidade_tecido_unidade_tecido_id_seq OWNER TO postgres;

--
-- Name: unidade_tecido_unidade_tecido_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.unidade_tecido_unidade_tecido_id_seq OWNED BY public.utilidades_tecido.utilidades_tecido_id;


--
-- Name: usuario_usuario_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_usuario_codigo_seq
    START WITH 15
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_usuario_codigo_seq OWNER TO postgres;

--
-- Name: usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario (
    usuario_nome character varying(80) NOT NULL,
    usuario_usuario character varying(80) NOT NULL,
    usuario_senha character varying(50) NOT NULL,
    usuario_corporativo character varying(80),
    usuario_skype character varying(80),
    usuario_ativado character(1) NOT NULL,
    usuario_pessoal character varying(80),
    usuario_nivel_acesso character(2),
    usuario_superior1 character varying(50),
    usuario_superior2 character varying(50),
    usuario_superior3 character varying(50),
    usuario_messenger character varying(80),
    usuario_grafico character(1),
    usuario_id integer NOT NULL,
    usuario_acessos_simultaneos character(4),
    usuario_conect character(4),
    usuario_skin character(30),
    usuario_tema character(30),
    usuario_layout character(1) DEFAULT '0'::"char" NOT NULL,
    usuario_grupo_codigo character(3),
    usuario_codigo character(3) DEFAULT lpad(((nextval('public.usuario_usuario_codigo_seq'::regclass))::character(3))::text, 3, '0'::text) NOT NULL,
    usuario_nivel_produto_1 boolean DEFAULT false,
    usuario_nivel_produto_2 boolean DEFAULT false,
    usuario_nivel_produto_3 boolean DEFAULT false,
    usuario_nivel_produto_4 boolean DEFAULT false,
    usuario_nivel_produto_5 boolean DEFAULT false,
    usuario_nivel_produto_6 boolean DEFAULT false,
    usuario_nivel_produto_7 boolean DEFAULT false,
    usuario_nivel_produto_8 boolean DEFAULT false,
    usuario_nivel_produto_9 boolean DEFAULT false,
    usuario_atualiza boolean DEFAULT false,
    usuario_ultimoacesso character(25),
    usuario_representante_id integer,
    usuario_representante_email character(200),
    usuario_acessa_website boolean DEFAULT false,
    usuario_codigo_funcionario integer,
    usuario_email character(200),
    usuario_email_senha character(50),
    usuario_ve_todas_sc boolean DEFAULT false,
    usuario_abrir_300 integer,
    usuario_altera_339 boolean DEFAULT false,
    usuario_baixar_credito_107 boolean,
    usuario_fase_producao boolean DEFAULT false,
    usuario_roteiro_fabricacao boolean DEFAULT false,
    usuario_retornar_representante boolean DEFAULT false,
    usuario_altera_cliente_fv boolean DEFAULT false,
    usuario_ativo boolean DEFAULT true,
    usuario_opcoes_exportacoes boolean DEFAULT false,
    usuario_abre_pedidos boolean DEFAULT false,
    usuario_solicitacao integer,
    usuario_expira timestamp without time zone,
    usuario_id_cliente integer,
    usuario_habilita_devolver_representante boolean DEFAULT true,
    usuario_habilita_enviar_fabrica boolean DEFAULT true,
    usuario_reabrir_os character(1),
    usuario_somente_seus_desenhos boolean DEFAULT false,
    usuario_limite_credito boolean,
    usuario_altera_333 boolean DEFAULT false,
    usuario_ve_valor_225 boolean DEFAULT false,
    usuario_parecer_tecnico boolean DEFAULT false,
    usuario_parecer_comercial boolean DEFAULT false,
    usuario_parecer_diretoria boolean DEFAULT false,
    usuario_parecer_financeiro boolean DEFAULT false,
    usuario_ve_valores_093 boolean DEFAULT false,
    usuario_dash boolean,
    usuario_receber_atrasado boolean,
    usuario_receber_atrasado30 boolean,
    usuario_pagar_atrasado boolean,
    usuario_pagar_atrasado30 boolean,
    usuario_executando_agora boolean,
    usuario_favorito_expandido boolean,
    usuario_mensageiro_expandido boolean,
    usuario_programacao boolean,
    usuario_permite_baixar_lote118 boolean DEFAULT false,
    usuario_revisa_orcamento boolean DEFAULT false,
    usuario_fecha_ordem boolean DEFAULT false,
    usuario_exibe_fernando boolean DEFAULT false,
    usuario_atende boolean DEFAULT false,
    usuario_solicita boolean DEFAULT false,
    usuario_abertura_408 integer,
    usuario_inspecao_final boolean DEFAULT false,
    usuario_libera_apontamento_lote boolean DEFAULT false,
    usuario_abre_inspecao_final boolean DEFAULT false,
    usuario_id_outro_sistema character(10),
    usuario_deleta_desenho boolean DEFAULT false,
    usuario_cor character(30)
);


ALTER TABLE public.usuario OWNER TO postgres;

--
-- Name: TABLE usuario; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.usuario IS 'Tabela aonde armazena os usuários';


--
-- Name: usuarios_ambientes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuarios_ambientes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuarios_ambientes_id_seq OWNER TO postgres;

--
-- Name: usuario_ambientes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_ambientes (
    id integer DEFAULT nextval('public.usuarios_ambientes_id_seq'::regclass) NOT NULL,
    usuarioid integer,
    ambiente character(50)
);


ALTER TABLE public.usuario_ambientes OWNER TO postgres;

--
-- Name: usuario_bolinhas_ub_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_bolinhas_ub_id_seq
    START WITH 49
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_bolinhas_ub_id_seq OWNER TO postgres;

--
-- Name: usuario_bolinhas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_bolinhas (
    ub_id integer DEFAULT nextval('public.usuario_bolinhas_ub_id_seq'::regclass) NOT NULL,
    ub_usuario_id integer,
    ub_bolinha_descricao character(200),
    ub_ativar boolean DEFAULT true,
    ub_id_bolinhas_dash integer
);


ALTER TABLE public.usuario_bolinhas OWNER TO postgres;

--
-- Name: usuario_consulta; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_consulta (
    usuario_consulta_id integer NOT NULL,
    usuario_consulta_codigo_usuario character(3) NOT NULL,
    usuario_consulta_funcao character(100),
    usuario_consulta_campo character(100)
);


ALTER TABLE public.usuario_consulta OWNER TO postgres;

--
-- Name: usuario_consulta_usuario_consulta_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_consulta_usuario_consulta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_consulta_usuario_consulta_id_seq OWNER TO postgres;

--
-- Name: usuario_consulta_usuario_consulta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_consulta_usuario_consulta_id_seq OWNED BY public.usuario_consulta.usuario_consulta_id;


--
-- Name: usuario_empresa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_empresa (
    usuario_empresa_id integer NOT NULL,
    usuario_empresa_codigo character(3),
    usuario_empresa_usuario_codigo character(3)
);


ALTER TABLE public.usuario_empresa OWNER TO postgres;

--
-- Name: TABLE usuario_empresa; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.usuario_empresa IS 'Tabela que interliga o usuário a empresa';


--
-- Name: usuario_empresa_usuario_empresa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_empresa_usuario_empresa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_empresa_usuario_empresa_id_seq OWNER TO postgres;

--
-- Name: usuario_empresa_usuario_empresa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_empresa_usuario_empresa_id_seq OWNED BY public.usuario_empresa.usuario_empresa_id;


--
-- Name: usuario_funcoes_usuario_funcao_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_funcoes_usuario_funcao_codigo_seq
    START WITH 6
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_funcoes_usuario_funcao_codigo_seq OWNER TO postgres;

--
-- Name: usuario_funcoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_funcoes (
    usuario_funcao_nome character varying(80) NOT NULL,
    usuario_funcao_item_menu character varying(50),
    usuario_funcao_tipo_menu character(100),
    usuario_funcao_menu character varying(100),
    usuario_funcao_submenu character varying(100),
    usuario_funcao_codigo character(3) DEFAULT lpad(((nextval('public.usuario_funcoes_usuario_funcao_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    usuario_funcao_id integer NOT NULL,
    usuario_funcao_workflow character(1),
    usuario_funcao_descricao character(200)
);


ALTER TABLE public.usuario_funcoes OWNER TO postgres;

--
-- Name: TABLE usuario_funcoes; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.usuario_funcoes IS 'Tabela de funcoes do sistema, aqui quarda todos os codigo dos forms para liberar acesso';


--
-- Name: usuario_funcoes_usuario_funcao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_funcoes_usuario_funcao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_funcoes_usuario_funcao_id_seq OWNER TO postgres;

--
-- Name: usuario_funcoes_usuario_funcao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_funcoes_usuario_funcao_id_seq OWNED BY public.usuario_funcoes.usuario_funcao_id;


--
-- Name: usuario_grupo_usuario_grupo_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_grupo_usuario_grupo_codigo_seq
    START WITH 5
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_grupo_usuario_grupo_codigo_seq OWNER TO postgres;

--
-- Name: usuario_grupo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_grupo (
    usuario_grupo_nome character varying(80) NOT NULL,
    usuario_grupo_super character(1) NOT NULL,
    usuario_grupo_id integer NOT NULL,
    usuario_grupo_codigo character(3) DEFAULT lpad(((nextval('public.usuario_grupo_usuario_grupo_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    usuario_grupo_ecommerce boolean DEFAULT false
);


ALTER TABLE public.usuario_grupo OWNER TO postgres;

--
-- Name: TABLE usuario_grupo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.usuario_grupo IS 'Tabela de grupos de usuários';


--
-- Name: usuario_grupo_funcoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_grupo_funcoes (
    usuario_grupo_funcoes_inserir character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_alterar character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_excluir character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_id integer NOT NULL,
    usuario_grupo_funcoes_gravar character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_codigo character(3),
    usuario_grupo_funcoes_usuario_codigo character(3),
    usuario_grupo_funcoes_f1 character(1) DEFAULT 'N'::bpchar,
    usuario_grupo_funcoes_f2 character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_f3 character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_f4 character(1) DEFAULT 'N'::bpchar,
    usuario_grupo_funcoes_f5 character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_f6 character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_f7 character(1) DEFAULT 'N'::bpchar,
    usuario_grupo_funcoes_f8 character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_f9 character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_f10 character(1) DEFAULT 'N'::bpchar,
    usuario_grupo_funcoes_f11 character(1) DEFAULT 'S'::bpchar,
    usuario_grupo_funcoes_f12 character(1) DEFAULT 'N'::bpchar,
    usuario_grupo_funcoes_nome character varying(80),
    usuario_grupo_funcoes_menu character varying(100)
);


ALTER TABLE public.usuario_grupo_funcoes OWNER TO postgres;

--
-- Name: usuario_grupo_funcoes_usuario_grupo_funcoes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_grupo_funcoes_usuario_grupo_funcoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_grupo_funcoes_usuario_grupo_funcoes_id_seq OWNER TO postgres;

--
-- Name: usuario_grupo_funcoes_usuario_grupo_funcoes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_grupo_funcoes_usuario_grupo_funcoes_id_seq OWNED BY public.usuario_grupo_funcoes.usuario_grupo_funcoes_id;


--
-- Name: usuario_grupo_usuario_grupo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_grupo_usuario_grupo_id_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_grupo_usuario_grupo_id_seq OWNER TO postgres;

--
-- Name: usuario_grupo_usuario_grupo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_grupo_usuario_grupo_id_seq OWNED BY public.usuario_grupo.usuario_grupo_id;


--
-- Name: usuario_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_log (
    log_usuario character varying(50),
    log_hora character varying(12),
    log_programa character varying(50),
    log_infomacao character(6000),
    log_id integer NOT NULL,
    log_data date
);


ALTER TABLE public.usuario_log OWNER TO postgres;

--
-- Name: TABLE usuario_log; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.usuario_log IS 'Tabela que guarda todos os acessos dos usuários no sistema';


--
-- Name: usuario_log_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_log_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_log_log_id_seq OWNER TO postgres;

--
-- Name: usuario_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_log_log_id_seq OWNED BY public.usuario_log.log_id;


--
-- Name: usuario_mensagem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_mensagem (
    usuario_mensagem_id integer NOT NULL,
    usuario_mensagem_autor character(50) NOT NULL,
    usuario_mensagem_assunto character(50),
    usuario_mensagem_texto text,
    usuario_mensagem_usuario_codigo character(3),
    usuario_mensagem_usuario_remetente character(3)
);


ALTER TABLE public.usuario_mensagem OWNER TO postgres;

--
-- Name: TABLE usuario_mensagem; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.usuario_mensagem IS 'Tabela de envio de mensagens';


--
-- Name: usuario_mensagem_remetente; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_mensagem_remetente (
    usuario_mensagem_remetente_id integer NOT NULL,
    usuario_mensagem_remetente_destinatario character(50),
    usuario_mensagem_remetente_assunto character(50),
    usuario_mensagem_remetente_mensagem text,
    usuario_mensagem_remetente_codigo character(3),
    usuario_mensagem_remetente_destinatario_codigo character(3)
);


ALTER TABLE public.usuario_mensagem_remetente OWNER TO postgres;

--
-- Name: TABLE usuario_mensagem_remetente; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.usuario_mensagem_remetente IS 'Aqui guarda as mensagens que foram enviadas.';


--
-- Name: usuario_mensagem_remetente_usuario_mensagem_remetente_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_mensagem_remetente_usuario_mensagem_remetente_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_mensagem_remetente_usuario_mensagem_remetente_id_seq OWNER TO postgres;

--
-- Name: usuario_mensagem_remetente_usuario_mensagem_remetente_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_mensagem_remetente_usuario_mensagem_remetente_id_seq OWNED BY public.usuario_mensagem_remetente.usuario_mensagem_remetente_id;


--
-- Name: usuario_mensagem_usuario_mensagem_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_mensagem_usuario_mensagem_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_mensagem_usuario_mensagem_id_seq OWNER TO postgres;

--
-- Name: usuario_mensagem_usuario_mensagem_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_mensagem_usuario_mensagem_id_seq OWNED BY public.usuario_mensagem.usuario_mensagem_id;


--
-- Name: usuario_menu; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_menu (
    id integer NOT NULL,
    id_menu integer,
    id_usuario integer
);


ALTER TABLE public.usuario_menu OWNER TO postgres;

--
-- Name: usuario_menu_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_menu_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_menu_id_seq OWNER TO postgres;

--
-- Name: usuario_menu_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_menu_id_seq OWNED BY public.usuario_menu.id;


--
-- Name: usuario_usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuario_usuario_id_seq OWNER TO postgres;

--
-- Name: usuario_usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_usuario_id_seq OWNED BY public.usuario.usuario_id;


--
-- Name: variacao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.variacao (
    variacao_id integer NOT NULL,
    variacao_descricao character(80),
    variacao_codigo character(4),
    variacao_inativar boolean DEFAULT false,
    variacao_entidade integer
);


ALTER TABLE public.variacao OWNER TO postgres;

--
-- Name: variacao_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.variacao_item (
    variacao_item_id integer NOT NULL,
    variacao_item_produto_id integer,
    variacao_item_percentual numeric(10,2),
    variacao_item_variacao_id integer NOT NULL
);


ALTER TABLE public.variacao_item OWNER TO postgres;

--
-- Name: variacao_item_variacao_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.variacao_item_variacao_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variacao_item_variacao_item_id_seq OWNER TO postgres;

--
-- Name: variacao_item_variacao_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.variacao_item_variacao_item_id_seq OWNED BY public.variacao_item.variacao_item_id;


--
-- Name: variacao_variacao_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.variacao_variacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variacao_variacao_id_seq OWNER TO postgres;

--
-- Name: variacao_variacao_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.variacao_variacao_id_seq OWNED BY public.variacao.variacao_id;


--
-- Name: variantes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.variantes (
    id integer NOT NULL,
    descricao character(5),
    data timestamp without time zone,
    usuario integer,
    ordem integer
);


ALTER TABLE public.variantes OWNER TO postgres;

--
-- Name: variantes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.variantes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variantes_id_seq OWNER TO postgres;

--
-- Name: variantes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.variantes_id_seq OWNED BY public.variantes.id;


--
-- Name: vendas_fixo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vendas_fixo (
    id integer NOT NULL,
    idcliente integer,
    data date,
    usuario integer,
    prazo_pagamento integer,
    tipo character(30),
    observacao character(300),
    representante integer,
    comissao numeric(18,2),
    banco integer,
    data_fechamento date,
    fechado boolean DEFAULT false
);


ALTER TABLE public.vendas_fixo OWNER TO postgres;

--
-- Name: vendas_fixo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vendas_fixo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.vendas_fixo_id_seq OWNER TO postgres;

--
-- Name: vendas_fixo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vendas_fixo_id_seq OWNED BY public.vendas_fixo.id;


--
-- Name: vendas_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vendas_item (
    id_item integer NOT NULL,
    id_fixo integer,
    qtde numeric(18,2),
    unidade character(5),
    unitario numeric(18,2),
    produto_id integer,
    cor_item integer
);


ALTER TABLE public.vendas_item OWNER TO postgres;

--
-- Name: vendas_item_id_item_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vendas_item_id_item_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.vendas_item_id_item_seq OWNER TO postgres;

--
-- Name: vendas_item_id_item_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vendas_item_id_item_seq OWNED BY public.vendas_item.id_item;


--
-- Name: view_usuarios_web; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.view_usuarios_web AS
 SELECT usuario.usuario_nome,
    (COALESCE(usuario.usuario_corporativo, 'Sem Email Cadastrado'::character varying))::character(60) AS usuario_corporativo,
    usuario.usuario_senha,
    usuario.usuario_id,
    usuario.usuario_grupo_codigo,
    usuario.usuario_acessa_website,
    COALESCE(usuario.usuario_representante_id, 0) AS usuario_representante_id
   FROM public.usuario
  WHERE (usuario.usuario_acessa_website = true);


ALTER TABLE public.view_usuarios_web OWNER TO postgres;

--
-- Name: visoes_vis_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.visoes_vis_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.visoes_vis_id_seq OWNER TO postgres;

--
-- Name: visoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.visoes (
    vis_usuario integer,
    vis_programa character(50),
    vis_arquivo text,
    vis_id integer DEFAULT nextval('public.visoes_vis_id_seq'::regclass) NOT NULL,
    vis_grid text
);


ALTER TABLE public.visoes OWNER TO postgres;

--
-- Name: workflow_workflow_codigo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.workflow_workflow_codigo_seq
    START WITH 14
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_workflow_codigo_seq OWNER TO postgres;

--
-- Name: workflow; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.workflow (
    workflow_id integer NOT NULL,
    workflow_codigo character(3) DEFAULT lpad(((nextval('public.workflow_workflow_codigo_seq'::regclass))::character(3))::text, 3, '0'::text),
    workflow_funcao character(80) NOT NULL,
    workflow_data_de date,
    workflow_data_ate date,
    workflow_horas_de time without time zone,
    workflow_horas_ate time without time zone,
    workflow_domingo boolean DEFAULT false,
    workflow_segunda boolean DEFAULT false,
    workflow_terca boolean DEFAULT false,
    workflow_quarta boolean DEFAULT false,
    workflow_quinta boolean DEFAULT false,
    workflow_sexta boolean DEFAULT false,
    workflow_sabado boolean DEFAULT false,
    workflow_data_parametro date,
    workflow_enviar_email boolean DEFAULT true,
    workflow_enviar_painel boolean DEFAULT false,
    workflow_obs text
);


ALTER TABLE public.workflow OWNER TO postgres;

--
-- Name: workflow_usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.workflow_usuario (
    workflow_usuario_id integer NOT NULL,
    workflow_usuario_workflow integer,
    workflow_funcao_id integer,
    workflow_painel boolean,
    workflow_email boolean,
    workflow_usuario_codigo character(3),
    workflow_id integer NOT NULL
);


ALTER TABLE public.workflow_usuario OWNER TO postgres;

--
-- Name: workflow_usuario_workflow_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.workflow_usuario_workflow_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_usuario_workflow_id_seq OWNER TO postgres;

--
-- Name: workflow_usuario_workflow_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.workflow_usuario_workflow_id_seq OWNED BY public.workflow_usuario.workflow_id;


--
-- Name: workflow_usuario_workflow_usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.workflow_usuario_workflow_usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_usuario_workflow_usuario_id_seq OWNER TO postgres;

--
-- Name: workflow_usuario_workflow_usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.workflow_usuario_workflow_usuario_id_seq OWNED BY public.workflow_usuario.workflow_usuario_id;


--
-- Name: workflow_workflow_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.workflow_workflow_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_workflow_id_seq OWNER TO postgres;

--
-- Name: workflow_workflow_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.workflow_workflow_id_seq OWNED BY public.workflow.workflow_id;


--
-- Name: aa50id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50 ALTER COLUMN aa50id SET DEFAULT nextval('public.aa50_aa50id_seq'::regclass);


--
-- Name: aa50componente_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50componentes ALTER COLUMN aa50componente_id SET DEFAULT nextval('public.aa50componentes_aa50componente_id_seq'::regclass);


--
-- Name: aa50ct_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50ct ALTER COLUMN aa50ct_id SET DEFAULT nextval('public.aa50ct_aa50ct_id_seq'::regclass);


--
-- Name: aa50estrutura_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50estrutura ALTER COLUMN aa50estrutura_id SET DEFAULT nextval('public.aa50estrutura_aa50estrutura_id_seq'::regclass);


--
-- Name: aa50fornecedor_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50fornecedor ALTER COLUMN aa50fornecedor_id SET DEFAULT nextval('public.aa50fornecedor_aa50fornecedor_id_seq'::regclass);


--
-- Name: aa50item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50item ALTER COLUMN aa50item_id SET DEFAULT nextval('public.aa50item_aa50item_id_seq'::regclass);


--
-- Name: aa50item_acabamento_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50item_acabamento ALTER COLUMN aa50item_acabamento_id SET DEFAULT nextval('public.aa50item_acabamento_aa50item_acabamento_id_seq'::regclass);


--
-- Name: aa50item_simula_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50item_simula ALTER COLUMN aa50item_simula_id SET DEFAULT nextval('public.aa50item_simula_aa50item_simula_id_seq'::regclass);


--
-- Name: aa50log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50log ALTER COLUMN aa50log_id SET DEFAULT nextval('public.aa50log_aa50log_id_seq'::regclass);


--
-- Name: aa50logpm_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50logpm ALTER COLUMN aa50logpm_id SET DEFAULT nextval('public.aa50logpm_aa50logpm_id_seq'::regclass);


--
-- Name: aa50ondeusa_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50ondeusa ALTER COLUMN aa50ondeusa_id SET DEFAULT nextval('public.aa50ondeusa_aa50ondeusa_id_seq'::regclass);


--
-- Name: aa50pm_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50pratica_mercado ALTER COLUMN aa50pm_id SET DEFAULT nextval('public.aa50pratica_mercado_aa50pm_id_seq'::regclass);


--
-- Name: aa50preco_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50preco ALTER COLUMN aa50preco_id SET DEFAULT nextval('public.aa50preco_aa50preco_id_seq'::regclass);


--
-- Name: aa50subgrupo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50subgrupo ALTER COLUMN aa50subgrupo_id SET DEFAULT nextval('public.aa50subgrupo_aa50subgrupo_id_seq'::regclass);


--
-- Name: aa50variacao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50variacao ALTER COLUMN aa50variacao_id SET DEFAULT nextval('public.aa50variacao_aa50variacao_id_seq'::regclass);


--
-- Name: aa80id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80 ALTER COLUMN aa80id SET DEFAULT nextval('public.cliente_aa80id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80_serasa ALTER COLUMN id SET DEFAULT nextval('public.aa80_serasa_id_seq'::regclass);


--
-- Name: aa80tel_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80_telefones ALTER COLUMN aa80tel_id SET DEFAULT nextval('public.aa80_telefones_aa80tel_id_seq'::regclass);


--
-- Name: aa80endcobra_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80endcobra ALTER COLUMN aa80endcobra_id SET DEFAULT nextval('public.aa80endcobra_aa80endcobra_id_seq'::regclass);


--
-- Name: aa80endentr_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80endentr ALTER COLUMN aa80endentr_id SET DEFAULT nextval('public.aa80endentr_aa80endentr_id_seq'::regclass);


--
-- Name: aa80inf_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80inf ALTER COLUMN aa80inf_id SET DEFAULT nextval('public.aa80inf_aa80inf_id_seq'::regclass);


--
-- Name: aa80mk_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80mk ALTER COLUMN aa80mk_id SET DEFAULT nextval('public.aa80mk_aa80mk_id_seq'::regclass);


--
-- Name: ab15id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab15 ALTER COLUMN ab15id SET DEFAULT nextval('public.ab15_ab15id_seq'::regclass);


--
-- Name: ab31id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab31 ALTER COLUMN ab31id SET DEFAULT nextval('public.ab31_ab31id_seq'::regclass);


--
-- Name: ab311id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab311 ALTER COLUMN ab311id SET DEFAULT nextval('public.ab311_ab311id_seq'::regclass);


--
-- Name: ab59id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab59 ALTER COLUMN ab59id SET DEFAULT nextval('public.ab59_ab59id_seq'::regclass);


--
-- Name: ab98id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab98 ALTER COLUMN ab98id SET DEFAULT nextval('public.ab98_ab98id_seq'::regclass);


--
-- Name: acabamento_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acabamento ALTER COLUMN acabamento_id SET DEFAULT nextval('public.acabamento_acabamento_id_seq'::regclass);


--
-- Name: amostra_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.amostra ALTER COLUMN amostra_id SET DEFAULT nextval('public.amostra_amostra_id_seq'::regclass);


--
-- Name: aparencias_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aparencias ALTER COLUMN aparencias_id SET DEFAULT nextval('public.aparencias_aparencias_id_seq'::regclass);


--
-- Name: areas_producao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_producao ALTER COLUMN areas_producao_id SET DEFAULT nextval('public.areas_producao_areas_producao_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.arquivo_retorno ALTER COLUMN id SET DEFAULT nextval('public.arquivo_retorno_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.arquivo_retorno_item ALTER COLUMN id SET DEFAULT nextval('public.arquivo_retorno_item_id_seq'::regclass);


--
-- Name: artigosprodutos_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artigosprodutos ALTER COLUMN artigosprodutos_id SET DEFAULT nextval('public.artigosprodutos_artigosprodutos_id_seq'::regclass);


--
-- Name: ap_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.atividades_padrao ALTER COLUMN ap_id SET DEFAULT nextval('public.atividades_padrao_ap_id_seq'::regclass);


--
-- Name: api_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.atividades_padrao_item ALTER COLUMN api_id SET DEFAULT nextval('public.atividades_padrao_item_api_id_seq'::regclass);


--
-- Name: atv_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.atv ALTER COLUMN atv_id SET DEFAULT nextval('public.atv_atv_id_seq'::regclass);


--
-- Name: bal_codigo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balanca ALTER COLUMN bal_codigo SET DEFAULT nextval('public.balanca_bal_codigo_seq'::regclass);


--
-- Name: bco_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bancos ALTER COLUMN bco_id SET DEFAULT nextval('public.bancos_bco_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bd_fixo ALTER COLUMN id SET DEFAULT nextval('public.bd_fixo_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bd_item ALTER COLUMN id SET DEFAULT nextval('public.bd_item_id_seq'::regclass);


--
-- Name: blf_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bloco_fixo ALTER COLUMN blf_id SET DEFAULT nextval('public.bloco_fixo_blf_id_seq'::regclass);


--
-- Name: bli_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bloco_item ALTER COLUMN bli_id SET DEFAULT nextval('public.bloco_item_bli_id_seq'::regclass);


--
-- Name: bloq_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bloqueios_pedidos ALTER COLUMN bloq_id SET DEFAULT nextval('public.bloqueios_pedidos_bloq_id_seq'::regclass);


--
-- Name: bc_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bordero_cheque ALTER COLUMN bc_id SET DEFAULT nextval('public.bordero_cheque_bc_id_seq'::regclass);


--
-- Name: bmv_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bordero_mvto ALTER COLUMN bmv_id SET DEFAULT nextval('public.bordero_mvto_bmv_id_seq'::regclass);


--
-- Name: cai_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caixas ALTER COLUMN cai_id SET DEFAULT nextval('public.caixas_cai_id_seq'::regclass);


--
-- Name: hc_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caixas_historico ALTER COLUMN hc_id SET DEFAULT nextval('public.caixas_historico_hc_id_seq'::regclass);


--
-- Name: centro_custo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centro_custo ALTER COLUMN centro_custo_id SET DEFAULT nextval('public.centro_custo_centro_custo_id_seq'::regclass);


--
-- Name: ccd_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centro_custo_detalhes ALTER COLUMN ccd_id SET DEFAULT nextval('public.centro_custo_detalhes_ccd_id_seq'::regclass);


--
-- Name: cfop_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cfop ALTER COLUMN cfop_id SET DEFAULT nextval('public.cfop_cfop_id_seq'::regclass);


--
-- Name: cheque_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cheque ALTER COLUMN cheque_id SET DEFAULT nextval('public.cheque_cheque_id_seq'::regclass);


--
-- Name: cheqhist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cheque_historico ALTER COLUMN cheqhist_id SET DEFAULT nextval('public.cheque_historico_cheqhist_id_seq'::regclass);


--
-- Name: chq_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chq_lote ALTER COLUMN chq_id SET DEFAULT nextval('public.chq_lote_chq_id_seq'::regclass);


--
-- Name: cidades_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cidades ALTER COLUMN cidades_id SET DEFAULT nextval('public.cidades_cidades_id_seq'::regclass);


--
-- Name: cid_tipo_log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cidades_tipo_logradouro ALTER COLUMN cid_tipo_log_id SET DEFAULT nextval('public.cidades_tipo_logradouro_cid_tipo_log_id_seq'::regclass);


--
-- Name: classificacao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classificacao ALTER COLUMN classificacao_id SET DEFAULT nextval('public.classificacao_classificacao_id_seq'::regclass);


--
-- Name: cbk_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classificacao_bloco_k ALTER COLUMN cbk_id SET DEFAULT nextval('public.classificacao_bloco_k_cbk_id_seq'::regclass);


--
-- Name: colecoes_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.colecoes ALTER COLUMN colecoes_id SET DEFAULT nextval('public.colecoes_colecoes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comissoes ALTER COLUMN id SET DEFAULT nextval('public.comissoes_id_seq'::regclass);


--
-- Name: composicao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.composicao ALTER COLUMN composicao_id SET DEFAULT nextval('public.composicao_composicao_id_seq'::regclass);


--
-- Name: conservacao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conservacao ALTER COLUMN conservacao_id SET DEFAULT nextval('public.conservacao_conservacao_id_seq'::regclass);


--
-- Name: cc_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conta_corrente ALTER COLUMN cc_id SET DEFAULT nextval('public.conta_corrente_cc_id_seq'::regclass);


--
-- Name: conta_estoque_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conta_estoque ALTER COLUMN conta_estoque_id SET DEFAULT nextval('public.conta_estoque_conta_estoque_id_seq'::regclass);


--
-- Name: cst_ipi_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cst_ipi ALTER COLUMN cst_ipi_id SET DEFAULT nextval('public.cst_ipi_cst_ipi_id_seq'::regclass);


--
-- Name: cf_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.custos_folha ALTER COLUMN cf_id SET DEFAULT nextval('public.custos_folha_cf_id_seq'::regclass);


--
-- Name: cfi_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.custos_folha_item ALTER COLUMN cfi_id SET DEFAULT nextval('public.custos_folha_item_cfi_id_seq'::regclass);


--
-- Name: deposito_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposito ALTER COLUMN deposito_id SET DEFAULT nextval('public.deposito_deposito_id_seq'::regclass);


--
-- Name: deposito_endereco_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposito_endereco ALTER COLUMN deposito_endereco_id SET DEFAULT nextval('public.deposito_endereco_deposito_endereco_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.descontos ALTER COLUMN id SET DEFAULT nextval('public.descontos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.descontos_operacoes ALTER COLUMN id SET DEFAULT nextval('public.descontos_operacoes_id_seq'::regclass);


--
-- Name: df10id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df10 ALTER COLUMN df10id SET DEFAULT nextval('public.df10_df10id_seq'::regclass);


--
-- Name: df10id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df10_temp ALTER COLUMN df10id SET DEFAULT nextval('public.df10_temp_df10id_seq'::regclass);


--
-- Name: df20id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df20 ALTER COLUMN df20id SET DEFAULT nextval('public.df20_df20id_seq'::regclass);


--
-- Name: dfgcid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfgc ALTER COLUMN dfgcid SET DEFAULT nextval('public.dfgc_dfgcid_seq'::regclass);


--
-- Name: dflog_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dflog ALTER COLUMN dflog_id SET DEFAULT nextval('public.dflog_dflog_id_seq'::regclass);


--
-- Name: dflogtm_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dflog_tipos_mov ALTER COLUMN dflogtm_id SET DEFAULT nextval('public.dflog_tipos_mov_dflogtm_id_seq'::regclass);


--
-- Name: dfterceiro_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfterceiro ALTER COLUMN dfterceiro_id SET DEFAULT nextval('public.dfterceiro_dfterceiro_id_seq'::regclass);


--
-- Name: divisoes_producao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.divisoes_producao ALTER COLUMN divisoes_producao_id SET DEFAULT nextval('public.divisoes_producao_divisoes_producao_id_seq'::regclass);


--
-- Name: email_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.email ALTER COLUMN email_id SET DEFAULT nextval('public.email_email_id_seq'::regclass);


--
-- Name: emails_artigo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emails_artigo ALTER COLUMN emails_artigo_id SET DEFAULT nextval('public.emails_artigo_emails_artigo_id_seq'::regclass);


--
-- Name: emails_artigo_codigo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emails_artigo ALTER COLUMN emails_artigo_codigo SET DEFAULT nextval('public.emails_artigo_emails_artigo_codigo_seq'::regclass);


--
-- Name: embalagens_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.embalagens ALTER COLUMN embalagens_id SET DEFAULT nextval('public.embalagens_embalagens_id_seq'::regclass);


--
-- Name: empresa_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa ALTER COLUMN empresa_id SET DEFAULT nextval('public.empresa_empresa_id_seq'::regclass);


--
-- Name: esp_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.espessuras ALTER COLUMN esp_id SET DEFAULT nextval('public.espessuras_esp_id_seq'::regclass);


--
-- Name: estagios_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estagios ALTER COLUMN estagios_id SET DEFAULT nextval('public.estagios_estagios_serial_seq'::regclass);


--
-- Name: estampa_cilindro_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estampa_cilindro ALTER COLUMN estampa_cilindro_id SET DEFAULT nextval('public.estampa_cilindro_estampa_cilindro_id_seq'::regclass);


--
-- Name: estampas_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estampas ALTER COLUMN estampas_id SET DEFAULT nextval('public.estampas_estampas_id_seq'::regclass);


--
-- Name: estoque_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estoque ALTER COLUMN estoque_id SET DEFAULT nextval('public.estoque_estoque_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estrutura_custo ALTER COLUMN id SET DEFAULT nextval('public.estrutura_custo_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos ALTER COLUMN id SET DEFAULT nextval('public.eventos_id_seq'::regclass);


--
-- Name: exc_entidade_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exc_entidade ALTER COLUMN exc_entidade_id SET DEFAULT nextval('public.exc_entidade_exc_entidade_id_seq'::regclass);


--
-- Name: exc_produto_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exc_produto ALTER COLUMN exc_produto_id SET DEFAULT nextval('public.exc_produto_exc_produto_id_seq'::regclass);


--
-- Name: exp_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expira ALTER COLUMN exp_id SET DEFAULT nextval('public.expira_exp_id_seq'::regclass);


--
-- Name: favoritos_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favoritos ALTER COLUMN favoritos_id SET DEFAULT nextval('public.favoritos_favoritos_id_seq'::regclass);


--
-- Name: fcp_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fcp ALTER COLUMN fcp_id SET DEFAULT nextval('public.fcp_fcp_id_seq'::regclass);


--
-- Name: flx_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fluxo_fixo ALTER COLUMN flx_id SET DEFAULT nextval('public.fluxo_fixo_flx_id_seq'::regclass);


--
-- Name: flxi_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fluxo_item ALTER COLUMN flxi_id SET DEFAULT nextval('public.fluxo_item_flxi_id_seq'::regclass);


--
-- Name: genero_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.genero ALTER COLUMN genero_id SET DEFAULT nextval('public.genero_genero_id_seq'::regclass);


--
-- Name: grafico_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grafico ALTER COLUMN grafico_id SET DEFAULT nextval('public.grafico_grafico_id_seq'::regclass);


--
-- Name: grupo_encolhimento_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grupo_encolhimento ALTER COLUMN grupo_encolhimento_id SET DEFAULT nextval('public.grupo_encolhimento_grupo_encolhimento_id_seq'::regclass);


--
-- Name: grupo_maquinas_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grupo_maquinas ALTER COLUMN grupo_maquinas_id SET DEFAULT nextval('public.grupo_maquinas_grupo_maquinas_id_seq'::regclass);


--
-- Name: historico_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historico ALTER COLUMN historico_id SET DEFAULT nextval('public.historico_historico_id_seq'::regclass);


--
-- Name: historico_fci_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historico_fci ALTER COLUMN historico_fci_id SET DEFAULT nextval('public.historico_fci_historico_fci_id_seq'::regclass);


--
-- Name: icms_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.icms ALTER COLUMN icms_id SET DEFAULT nextval('public.icms_icms_id_seq'::regclass);


--
-- Name: icms_codigo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.icms ALTER COLUMN icms_codigo SET DEFAULT nextval('public.icms_icms_codigo_seq'::regclass);


--
-- Name: icms01_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.icms01 ALTER COLUMN icms01_id SET DEFAULT nextval('public.icms01_icms01_id_seq'::regclass);


--
-- Name: item_simula_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.item_simula ALTER COLUMN item_simula_id SET DEFAULT nextval('public.item_simula_item_simula_id_seq'::regclass);


--
-- Name: lo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lancamento_ocorrencia ALTER COLUMN lo_id SET DEFAULT nextval('public.lancamento_ocorrencia_lo_id_seq'::regclass);


--
-- Name: liberacao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.liberacao ALTER COLUMN liberacao_id SET DEFAULT nextval('public.liberacao_liberacao_id_seq'::regclass);


--
-- Name: lib_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.liberacoes ALTER COLUMN lib_id SET DEFAULT nextval('public.liberacoes_lib_id_seq'::regclass);


--
-- Name: labd_idatualizacao; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_atualizacao_banco_dados ALTER COLUMN labd_idatualizacao SET DEFAULT nextval('public.log_atualizacao_banco_dados_labd_idatualizacao_seq'::regclass);


--
-- Name: maquinas_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maquinas ALTER COLUMN maquinas_id SET DEFAULT nextval('public.maquinas_maquinas_serial_seq'::regclass);


--
-- Name: mcp_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maquinas_capacidade ALTER COLUMN mcp_id SET DEFAULT nextval('public.maquinas_capacidade_mcp_id_seq'::regclass);


--
-- Name: maquinas_regulagem_serial; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maquinas_regulagem ALTER COLUMN maquinas_regulagem_serial SET DEFAULT nextval('public.maquinas_regulagem_maquinas_regulagem_serial_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu ALTER COLUMN id SET DEFAULT nextval('public.menu_id_seq'::regclass);


--
-- Name: mkf_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mkf ALTER COLUMN mkf_id SET DEFAULT nextval('public.mkf_mkf_id_seq'::regclass);


--
-- Name: mki_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mki ALTER COLUMN mki_id SET DEFAULT nextval('public.mki_mki_id_seq'::regclass);


--
-- Name: moeda_cotacao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.moeda_cotacao ALTER COLUMN moeda_cotacao_id SET DEFAULT nextval('public.moeda_cotacao_moeda_cotacao_id_seq'::regclass);


--
-- Name: motivo_uso_producao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.motivo_uso_producao ALTER COLUMN motivo_uso_producao_id SET DEFAULT nextval('public.motivo_uso_producao_motivo_uso_producao_id_seq'::regclass);


--
-- Name: mot_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.motivos_bloqueios ALTER COLUMN mot_id SET DEFAULT nextval('public.motivos_bloqueios_mot_id_seq'::regclass);


--
-- Name: movest_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque ALTER COLUMN movest_id SET DEFAULT nextval('public.mov_estoque_movest_id_seq'::regclass);


--
-- Name: movimentacao_roteiro_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimentacao_roteiro ALTER COLUMN movimentacao_roteiro_id SET DEFAULT nextval('public.movimentacao_roteiro_movimentacao_roteiro_id_seq'::regclass);


--
-- Name: msg_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.msg ALTER COLUMN msg_id SET DEFAULT nextval('public.msg_msg_id_seq'::regclass);


--
-- Name: mvta_estoque_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mvta_estoque ALTER COLUMN mvta_estoque_id SET DEFAULT nextval('public.mvta_estoque_mvta_estoque_id_seq'::regclass);


--
-- Name: nfcan_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_canceladas ALTER COLUMN nfcan_id SET DEFAULT nextval('public.nf_canceladas_nfcan_id_seq'::regclass);


--
-- Name: nfc_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_complememtar ALTER COLUMN nfc_id SET DEFAULT nextval('public.nf_complememtar_nfc_id_seq'::regclass);


--
-- Name: nfd_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_devolucao ALTER COLUMN nfd_id SET DEFAULT nextval('public.nf_devolucao_nfd_id_seq'::regclass);


--
-- Name: nf_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_fixa ALTER COLUMN nf_id SET DEFAULT nextval('public.nf_fixa_id_seq'::regclass);


--
-- Name: cce_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_fixa_cce ALTER COLUMN cce_id SET DEFAULT nextval('public.nf_fixa_cce_cce_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_inutilizadas ALTER COLUMN id SET DEFAULT nextval('public.nf_inutilizadas_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_item ALTER COLUMN id SET DEFAULT nextval('public.nf_produtos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nomearq ALTER COLUMN id SET DEFAULT nextval('public.nomearq_id_seq'::regclass);


--
-- Name: obs_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.observacoes ALTER COLUMN obs_id SET DEFAULT nextval('public.observacoes_obs_id_seq'::regclass);


--
-- Name: ocorrencia_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ocorrencia ALTER COLUMN ocorrencia_id SET DEFAULT nextval('public.ocorrencia_ocorrencia_id_seq'::regclass);


--
-- Name: ocorrencia_papel_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ocorrencia_papel ALTER COLUMN ocorrencia_papel_id SET DEFAULT nextval('public.ocorrencia_papel_ocorrencia_papel_id_seq'::regclass);


--
-- Name: operacoes_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operacoes ALTER COLUMN operacoes_id SET DEFAULT nextval('public.operacoes_operacoes_id_seq'::regclass);


--
-- Name: of_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orcamento_fixo ALTER COLUMN of_id SET DEFAULT nextval('public.orcamento_fixo_of_id_seq'::regclass);


--
-- Name: oi_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orcamento_item ALTER COLUMN oi_id SET DEFAULT nextval('public.orcamento_item_oi_id_seq'::regclass);


--
-- Name: or_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orcamento_recebido ALTER COLUMN or_id SET DEFAULT nextval('public.orcamento_recebido_or_id_seq'::regclass);


--
-- Name: or_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orcamento_recebidos ALTER COLUMN or_id SET DEFAULT nextval('public.orcamento_recebidos_or_id_seq'::regclass);


--
-- Name: ob_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento ALTER COLUMN ob_id SET DEFAULT nextval('public.ordem_beneficiamento_ob_id_seq'::regclass);


--
-- Name: obb_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_bloqueios ALTER COLUMN obb_id SET DEFAULT nextval('public.ordem_beneficiamento_bloqueios_obb_id_seq'::regclass);


--
-- Name: obf_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_fluxo ALTER COLUMN obf_id SET DEFAULT nextval('public.ordem_beneficiamento_fluxo_obf_id_seq'::regclass);


--
-- Name: obh_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_historicos ALTER COLUMN obh_id SET DEFAULT nextval('public.ordem_beneficiamento_historicos_obh_id_seq'::regclass);


--
-- Name: obl_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_lote ALTER COLUMN obl_id SET DEFAULT nextval('public.ordem_beneficiamento_lote_obl_id_seq'::regclass);


--
-- Name: of_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_fio ALTER COLUMN of_id SET DEFAULT nextval('public.ordem_fio_of_id_seq'::regclass);


--
-- Name: os_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_servico ALTER COLUMN os_id SET DEFAULT nextval('public.ordem_servico_os_id_seq'::regclass);


--
-- Name: ol_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_servico_lancadas ALTER COLUMN ol_id SET DEFAULT nextval('public.ordem_servico_lancadas_ol_id_seq'::regclass);


--
-- Name: paises_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paises ALTER COLUMN paises_id SET DEFAULT nextval('public.paises_paises_id_seq'::regclass);


--
-- Name: parb_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_beneficiamento ALTER COLUMN parb_id SET DEFAULT nextval('public.parametro_beneficiamento_parb_id_seq'::regclass);


--
-- Name: parfin_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_financiamento ALTER COLUMN parfin_id SET DEFAULT nextval('public.parametro_financiamento_parfin_id_seq'::regclass);


--
-- Name: parametro_grafico_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_grafico ALTER COLUMN parametro_grafico_id SET DEFAULT nextval('public.parametro_grafico_parametro_grafico_id_seq'::regclass);


--
-- Name: parnfe_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_nfe ALTER COLUMN parnfe_id SET DEFAULT nextval('public.parametro_nfe_parnfe_id_seq'::regclass);


--
-- Name: parv_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_viscosidade ALTER COLUMN parv_id SET DEFAULT nextval('public.parametro_viscosidade_parv_id_seq'::regclass);


--
-- Name: parametros_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros ALTER COLUMN parametros_id SET DEFAULT nextval('public.parametros_parametros_id_seq'::regclass);


--
-- Name: parametros_smtp_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros_smtp ALTER COLUMN parametros_smtp_id SET DEFAULT nextval('public.parametros_smtp_parametros_smtp_id_seq'::regclass);


--
-- Name: parametros_xml_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros_xml ALTER COLUMN parametros_xml_id SET DEFAULT nextval('public.parametros_xml_parametros_xml_id_seq'::regclass);


--
-- Name: partida_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partida ALTER COLUMN partida_id SET DEFAULT nextval('public.partida_partida_id_seq'::regclass);


--
-- Name: pb_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partida_beneficiamento ALTER COLUMN pb_id SET DEFAULT nextval('public.partida_beneficiamento_pb_id_seq'::regclass);


--
-- Name: pbi_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partida_beneficiamento_item ALTER COLUMN pbi_id SET DEFAULT nextval('public.partida_beneficiamento_item_pbi_id_seq'::regclass);


--
-- Name: pd_acab_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_acab ALTER COLUMN pd_acab_id SET DEFAULT nextval('public.pd_acab_pd_acab_id_seq'::regclass);


--
-- Name: pdc_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_cancelados ALTER COLUMN pdc_id SET DEFAULT nextval('public.pd_cancelados_pdc_id_seq'::regclass);


--
-- Name: pd_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_fixo ALTER COLUMN pd_id SET DEFAULT nextval('public.pds_fixo_pds_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_log ALTER COLUMN id SET DEFAULT nextval('public.pd_log_id_seq'::regclass);


--
-- Name: pd_proc_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_proc ALTER COLUMN pd_proc_id SET DEFAULT nextval('public.pd_proc_pd_proc_id_seq'::regclass);


--
-- Name: pdi_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdi_item ALTER COLUMN pdi_id SET DEFAULT nextval('public.pdi_item_pdi_id_seq'::regclass);


--
-- Name: pec_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas ALTER COLUMN pec_id SET DEFAULT nextval('public.pecas_pec_id_seq'::regclass);


--
-- Name: pecas_acabamento_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas_acabamento ALTER COLUMN pecas_acabamento_id SET DEFAULT nextval('public.pecas_acabamento_pecas_acabamento_id_seq'::regclass);


--
-- Name: hp_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas_historico ALTER COLUMN hp_id SET DEFAULT nextval('public.historico_pecas_hp_id_seq'::regclass);


--
-- Name: pecas_processo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas_processo ALTER COLUMN pecas_processo_id SET DEFAULT nextval('public.pecas_processo_pecas_processo_id_seq'::regclass);


--
-- Name: perfil_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perfil ALTER COLUMN perfil_id SET DEFAULT nextval('public.perfil_perfil_id_seq'::regclass);


--
-- Name: plc_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plano_contas ALTER COLUMN plc_id SET DEFAULT nextval('public.plano_contas_plc_id_seq'::regclass);


--
-- Name: prioridade_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prioridade ALTER COLUMN prioridade_id SET DEFAULT nextval('public.prioridade_prioridade_id_seq'::regclass);


--
-- Name: processo_tigimento_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.processo_tigimento ALTER COLUMN processo_tigimento_id SET DEFAULT nextval('public.processo_tigimento_processo_tigimento_id_seq'::regclass);


--
-- Name: quadros_cilindro_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.quadros_cilindro ALTER COLUMN quadros_cilindro_id SET DEFAULT nextval('public.quadros_cilindro_quadros_cilindro_id_seq'::regclass);


--
-- Name: qual_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qualidade ALTER COLUMN qual_id SET DEFAULT nextval('public.qualidade_qual_id_seq'::regclass);


--
-- Name: ri_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receita_item ALTER COLUMN ri_id SET DEFAULT nextval('public.receita_item_ri_id_seq'::regclass);


--
-- Name: ref_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.referencia ALTER COLUMN ref_id SET DEFAULT nextval('public.referencia_ref_id_seq'::regclass);


--
-- Name: rflx_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relacao_fluxo ALTER COLUMN rflx_id SET DEFAULT nextval('public.relacao_fluxo_rflx_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relacao_produto_os ALTER COLUMN id SET DEFAULT nextval('public.relacao_produto_os_id_seq'::regclass);


--
-- Name: rev_papel_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.revisa_papel ALTER COLUMN rev_papel_id SET DEFAULT nextval('public.revisa_papel_rev_papel_id_seq'::regclass);


--
-- Name: rolos_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rolos ALTER COLUMN rolos_id SET DEFAULT nextval('public.rolos_rolos_id_seq'::regclass);


--
-- Name: rom_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.romaneio ALTER COLUMN rom_id SET DEFAULT nextval('public.romaneio_rom_id_seq'::regclass);


--
-- Name: romi_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.romaneio_item ALTER COLUMN romi_id SET DEFAULT nextval('public.romaneio_item_romi_id_seq'::regclass);


--
-- Name: roteiro_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roteiro ALTER COLUMN roteiro_id SET DEFAULT nextval('public.roteiro_roteiro_id_seq'::regclass);


--
-- Name: roteiro_producao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roteiro_producao ALTER COLUMN roteiro_producao_id SET DEFAULT nextval('public.roteiro_producao_roteiro_producao_id_seq'::regclass);


--
-- Name: rpai_filho_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rpai_filho ALTER COLUMN rpai_filho_id SET DEFAULT nextval('public.rpai_filho_rpai_filho_id_seq'::regclass);


--
-- Name: sdc_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sdc ALTER COLUMN sdc_id SET DEFAULT nextval('public.sdc_sdc_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sdc_aux ALTER COLUMN id SET DEFAULT nextval('public.sdc_aux_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sdc_item_cor ALTER COLUMN id SET DEFAULT nextval('public.sdc_item_cor_id_seq'::regclass);


--
-- Name: sl_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sdc_log ALTER COLUMN sl_id SET DEFAULT nextval('public.sdc_log_sl_id_seq'::regclass);


--
-- Name: segmento_mercado_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.segmento_mercado ALTER COLUMN segmento_mercado_id SET DEFAULT nextval('public.segmento_mercado_segmento_mercado_id_seq'::regclass);


--
-- Name: series_cor_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.series_cor ALTER COLUMN series_cor_id SET DEFAULT nextval('public.setores_cor_setores_cor_id_seq'::regclass);


--
-- Name: setup_maquinas_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.setup_maquinas ALTER COLUMN setup_maquinas_id SET DEFAULT nextval('public.setup_maquinas_setup_maquinas_id_seq'::regclass);


--
-- Name: sobras_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sobras ALTER COLUMN sobras_id SET DEFAULT nextval('public.sobras_sobras_id_seq'::regclass);


--
-- Name: sc_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_compras ALTER COLUMN sc_id SET DEFAULT nextval('public.solicitacao_compras_sc_id_seq'::regclass);


--
-- Name: sca_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_compras_aplicacao ALTER COLUMN sca_id SET DEFAULT nextval('public.solicitacao_compras_aplicacao_sca_id_seq'::regclass);


--
-- Name: sci_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_compras_item ALTER COLUMN sci_id SET DEFAULT nextval('public.solicitacao_compras_item_sci_id_seq'::regclass);


--
-- Name: sc_compras_nivel_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_compras_nivel ALTER COLUMN sc_compras_nivel_id SET DEFAULT nextval('public.solicitacao_compras_nivel_sc_compras_nivel_id_seq'::regclass);


--
-- Name: solicitacao_desenvolvimento_cor_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_desenvolvimento_cor ALTER COLUMN solicitacao_desenvolvimento_cor_id SET DEFAULT nextval('public.solicitacao_desenvolvimento_c_solicitacao_desenvolvimento_c_seq'::regclass);


--
-- Name: tabela_preco_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tabela_preco ALTER COLUMN tabela_preco_id SET DEFAULT nextval('public.tabela_preco_tabela_preco_id_seq'::regclass);


--
-- Name: tema_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tema ALTER COLUMN tema_id SET DEFAULT nextval('public.tema_tema_id_seq'::regclass);


--
-- Name: tipo_produto_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_produto ALTER COLUMN tipo_produto_id SET DEFAULT nextval('public.tipo_produto_tipo_produto_id_seq'::regclass);


--
-- Name: tipos_calculo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_calculo ALTER COLUMN tipos_calculo_id SET DEFAULT nextval('public.tipos_calculo_tipos_calculo_id_seq'::regclass);


--
-- Name: td_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_desenhos ALTER COLUMN td_id SET DEFAULT nextval('public.tipos_desenhos_td_id_seq'::regclass);


--
-- Name: tipos_materia_prima_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_materia_prima ALTER COLUMN tipos_materia_prima_id SET DEFAULT nextval('public.tipos_materia_prima_tipos_materia_prima_id_seq'::regclass);


--
-- Name: toque_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toque ALTER COLUMN toque_id SET DEFAULT nextval('public.toque_toque_id_seq'::regclass);


--
-- Name: turno_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.turno ALTER COLUMN turno_id SET DEFAULT nextval('public.turno_turno_id_seq'::regclass);


--
-- Name: unidade_medida_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.unidade_medida ALTER COLUMN unidade_medida_id SET DEFAULT nextval('public.unidade_medida_unidade_medida_id_seq'::regclass);


--
-- Name: usuario_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario ALTER COLUMN usuario_id SET DEFAULT nextval('public.usuario_usuario_id_seq'::regclass);


--
-- Name: usuario_consulta_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_consulta ALTER COLUMN usuario_consulta_id SET DEFAULT nextval('public.usuario_consulta_usuario_consulta_id_seq'::regclass);


--
-- Name: usuario_empresa_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_empresa ALTER COLUMN usuario_empresa_id SET DEFAULT nextval('public.usuario_empresa_usuario_empresa_id_seq'::regclass);


--
-- Name: usuario_funcao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_funcoes ALTER COLUMN usuario_funcao_id SET DEFAULT nextval('public.usuario_funcoes_usuario_funcao_id_seq'::regclass);


--
-- Name: usuario_grupo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_grupo ALTER COLUMN usuario_grupo_id SET DEFAULT nextval('public.usuario_grupo_usuario_grupo_id_seq'::regclass);


--
-- Name: usuario_grupo_funcoes_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_grupo_funcoes ALTER COLUMN usuario_grupo_funcoes_id SET DEFAULT nextval('public.usuario_grupo_funcoes_usuario_grupo_funcoes_id_seq'::regclass);


--
-- Name: log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_log ALTER COLUMN log_id SET DEFAULT nextval('public.usuario_log_log_id_seq'::regclass);


--
-- Name: usuario_mensagem_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_mensagem ALTER COLUMN usuario_mensagem_id SET DEFAULT nextval('public.usuario_mensagem_usuario_mensagem_id_seq'::regclass);


--
-- Name: usuario_mensagem_remetente_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_mensagem_remetente ALTER COLUMN usuario_mensagem_remetente_id SET DEFAULT nextval('public.usuario_mensagem_remetente_usuario_mensagem_remetente_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_menu ALTER COLUMN id SET DEFAULT nextval('public.usuario_menu_id_seq'::regclass);


--
-- Name: utilidades_tecido_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilidades_tecido ALTER COLUMN utilidades_tecido_id SET DEFAULT nextval('public.unidade_tecido_unidade_tecido_id_seq'::regclass);


--
-- Name: variacao_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variacao ALTER COLUMN variacao_id SET DEFAULT nextval('public.variacao_variacao_id_seq'::regclass);


--
-- Name: variacao_item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variacao_item ALTER COLUMN variacao_item_id SET DEFAULT nextval('public.variacao_item_variacao_item_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variantes ALTER COLUMN id SET DEFAULT nextval('public.variantes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vendas_fixo ALTER COLUMN id SET DEFAULT nextval('public.vendas_fixo_id_seq'::regclass);


--
-- Name: id_item; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vendas_item ALTER COLUMN id_item SET DEFAULT nextval('public.vendas_item_id_item_seq'::regclass);


--
-- Name: workflow_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workflow ALTER COLUMN workflow_id SET DEFAULT nextval('public.workflow_workflow_id_seq'::regclass);


--
-- Name: workflow_usuario_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workflow_usuario ALTER COLUMN workflow_usuario_id SET DEFAULT nextval('public.workflow_usuario_workflow_usuario_id_seq'::regclass);


--
-- Name: workflow_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workflow_usuario ALTER COLUMN workflow_id SET DEFAULT nextval('public.workflow_usuario_workflow_id_seq'::regclass);


--
-- Name: Campo Unico; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80
    ADD CONSTRAINT "Campo Unico" UNIQUE (aa80codigo);


--
-- Name: Chave Primaria; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80endentr
    ADD CONSTRAINT "Chave Primaria" PRIMARY KEY (aa80endentr_id);


--
-- Name: OBFPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_fluxo
    ADD CONSTRAINT "OBFPK" PRIMARY KEY (obf_id);


--
-- Name: PKOI; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orcamento_item
    ADD CONSTRAINT "PKOI" PRIMARY KEY (oi_id);


--
-- Name: TBCPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tabela_custo_hora
    ADD CONSTRAINT "TBCPK" PRIMARY KEY (tbc_id);


--
-- Name: TOAID; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_ambiente
    ADD CONSTRAINT "TOAID" PRIMARY KEY (toa_id);


--
-- Name: aa50_aa50id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50id_key UNIQUE (aa50id, aa50descricao);


--
-- Name: aa50_aa50id_key1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50id_key1 UNIQUE (aa50id, aa50linha_produto, aa50linha_produto_descricao);


--
-- Name: aa50_aa50id_key2; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50id_key2 UNIQUE (aa50id, aa50nivel, aa50grupo, aa50descricao, aa50um);


--
-- Name: aa50_aa50id_key3; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50id_key3 UNIQUE (aa50id, aa50nivel, aa50grupo, aa50descricao, aa50um, aa50ipi, aa50aliquotapis, aa50aliquotacofins);


--
-- Name: aa50_aa50nivel_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50nivel_key UNIQUE (aa50nivel, aa50descricao);


--
-- Name: aa50_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_pkey PRIMARY KEY (aa50id);


--
-- Name: aa50cinis; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50conversao
    ADD CONSTRAINT aa50cinis PRIMARY KEY (id);


--
-- Name: aa50componentes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50componentes
    ADD CONSTRAINT aa50componentes_pkey PRIMARY KEY (aa50componente_id);


--
-- Name: aa50ctPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50ct
    ADD CONSTRAINT "aa50ctPK" PRIMARY KEY (aa50ct_id);


--
-- Name: aa50estrutura_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50estrutura
    ADD CONSTRAINT aa50estrutura_pkey PRIMARY KEY (aa50estrutura_id);


--
-- Name: aa50fornecedor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50fornecedor
    ADD CONSTRAINT aa50fornecedor_pkey PRIMARY KEY (aa50fornecedor_id);


--
-- Name: aa50id22; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50imagem
    ADD CONSTRAINT aa50id22 PRIMARY KEY (id);


--
-- Name: aa50item_aa50item_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50item
    ADD CONSTRAINT aa50item_aa50item_codigo_key UNIQUE (aa50item_codigo, aa50item_aa50);


--
-- Name: aa50item_acabamento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50item_acabamento
    ADD CONSTRAINT aa50item_acabamento_pkey PRIMARY KEY (aa50item_acabamento_id);


--
-- Name: aa50item_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50item
    ADD CONSTRAINT aa50item_pkey PRIMARY KEY (aa50item_id);


--
-- Name: aa50logid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50log
    ADD CONSTRAINT aa50logid PRIMARY KEY (aa50log_id);


--
-- Name: aa50logidpm; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50logpm
    ADD CONSTRAINT aa50logidpm PRIMARY KEY (aa50logpm_id);


--
-- Name: aa50preco_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50preco
    ADD CONSTRAINT aa50preco_id_pkey PRIMARY KEY (aa50preco_id);


--
-- Name: aa50subgrupo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50subgrupo
    ADD CONSTRAINT aa50subgrupo_pkey PRIMARY KEY (aa50subgrupo_id);


--
-- Name: aa50variacao_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50variacao
    ADD CONSTRAINT aa50variacao_pk PRIMARY KEY (aa50variacao_id);


--
-- Name: aa50variacao_uk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50variacao
    ADD CONSTRAINT aa50variacao_uk UNIQUE (aa50variacao_aa50id, aa50variacao_codigo);


--
-- Name: aa80_aa80codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80
    ADD CONSTRAINT aa80_aa80codigo_key UNIQUE (aa80codigo, aa80nome);


--
-- Name: aa80_aa80id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80
    ADD CONSTRAINT aa80_aa80id_key UNIQUE (aa80id, aa80codigo, aa80nome);


--
-- Name: aa80_aa80nome_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80
    ADD CONSTRAINT aa80_aa80nome_key UNIQUE (aa80nome);


--
-- Name: aa80endcobra_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80endcobra
    ADD CONSTRAINT aa80endcobra_pkey PRIMARY KEY (aa80endcobra_id);


--
-- Name: aa80inf_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80inf
    ADD CONSTRAINT aa80inf_pkey PRIMARY KEY (aa80inf_id);


--
-- Name: aa80mk_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80mk
    ADD CONSTRAINT aa80mk_pkey PRIMARY KEY (aa80mk_id);


--
-- Name: aa80tpfidtpf; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80tipo_fornecedor
    ADD CONSTRAINT aa80tpfidtpf PRIMARY KEY (aa80tpf_id);


--
-- Name: ab15_ab15codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab15
    ADD CONSTRAINT ab15_ab15codigo_key UNIQUE (ab15codigo);


--
-- Name: ab15_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab15
    ADD CONSTRAINT ab15_pkey PRIMARY KEY (ab15id);


--
-- Name: ab20_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab20
    ADD CONSTRAINT ab20_pkey PRIMARY KEY (ab20id);


--
-- Name: ab311_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab311
    ADD CONSTRAINT ab311_pkey PRIMARY KEY (ab311id);


--
-- Name: ab31_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab31
    ADD CONSTRAINT ab31_pkey PRIMARY KEY (ab31id);


--
-- Name: ab59_ab59codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab59
    ADD CONSTRAINT ab59_ab59codigo_key UNIQUE (ab59codigo);


--
-- Name: ab59_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab59
    ADD CONSTRAINT ab59_pkey PRIMARY KEY (ab59id);


--
-- Name: ab83idconstra; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab83
    ADD CONSTRAINT ab83idconstra PRIMARY KEY (ab83id);


--
-- Name: ab98_ab98codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab98
    ADD CONSTRAINT ab98_ab98codigo_key UNIQUE (ab98codigo, ab98nome);


--
-- Name: ab998idprima; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab98
    ADD CONSTRAINT ab998idprima PRIMARY KEY (ab98id);


--
-- Name: acabamento_acabamento_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acabamento
    ADD CONSTRAINT acabamento_acabamento_codigo_key UNIQUE (acabamento_codigo);


--
-- Name: acabamento_acabamento_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acabamento
    ADD CONSTRAINT acabamento_acabamento_descricao_key UNIQUE (acabamento_descricao);


--
-- Name: acabamento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acabamento
    ADD CONSTRAINT acabamento_pkey PRIMARY KEY (acabamento_id);


--
-- Name: ambid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ambientes
    ADD CONSTRAINT ambid PRIMARY KEY (amb_id);


--
-- Name: amostra_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.amostra
    ADD CONSTRAINT amostra_pkey PRIMARY KEY (amostra_id);


--
-- Name: aparencias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aparencias
    ADD CONSTRAINT aparencias_pkey PRIMARY KEY (aparencias_id);


--
-- Name: areas_producao_areas_producao_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_producao
    ADD CONSTRAINT areas_producao_areas_producao_codigo_key UNIQUE (areas_producao_codigo);


--
-- Name: areas_producao_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_producao
    ADD CONSTRAINT areas_producao_pkey PRIMARY KEY (areas_producao_id);


--
-- Name: arquivo_itenpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.arquivo_retorno_item
    ADD CONSTRAINT arquivo_itenpk PRIMARY KEY (id);


--
-- Name: artigosprodutos_artigosprodutos_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artigosprodutos
    ADD CONSTRAINT artigosprodutos_artigosprodutos_codigo_key UNIQUE (artigosprodutos_codigo);


--
-- Name: artigosprodutos_artigosprodutos_codigo_key1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artigosprodutos
    ADD CONSTRAINT artigosprodutos_artigosprodutos_codigo_key1 UNIQUE (artigosprodutos_codigo, artigosprodutos_descricao);


--
-- Name: artigosprodutos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.artigosprodutos
    ADD CONSTRAINT artigosprodutos_pkey PRIMARY KEY (artigosprodutos_id);


--
-- Name: balanca_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balanca
    ADD CONSTRAINT balanca_pkey PRIMARY KEY (bal_codigo);


--
-- Name: bancos_bco_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bancos
    ADD CONSTRAINT bancos_bco_codigo_key UNIQUE (bco_codigo, bco_nome);


--
-- Name: bancos_bco_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bancos
    ADD CONSTRAINT bancos_bco_id_key UNIQUE (bco_id, bco_codigo, bco_nome);


--
-- Name: bancos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bancos
    ADD CONSTRAINT bancos_pkey PRIMARY KEY (bco_id);


--
-- Name: blipk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bloco_item
    ADD CONSTRAINT blipk PRIMARY KEY (bli_id);


--
-- Name: bloqueios_pedidos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bloqueios_pedidos
    ADD CONSTRAINT bloqueios_pedidos_pkey PRIMARY KEY (bloq_id);


--
-- Name: bordero_mvto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bordero_mvto
    ADD CONSTRAINT bordero_mvto_pkey PRIMARY KEY (bmv_id);


--
-- Name: cai_id_fk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caixas
    ADD CONSTRAINT cai_id_fk PRIMARY KEY (cai_id);


--
-- Name: cbk_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classificacao_bloco_k
    ADD CONSTRAINT cbk_pk PRIMARY KEY (cbk_id);


--
-- Name: centro_custo_centro_custo_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centro_custo
    ADD CONSTRAINT centro_custo_centro_custo_codigo_key UNIQUE (centro_custo_codigo);


--
-- Name: centro_custo_centro_custo_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centro_custo
    ADD CONSTRAINT centro_custo_centro_custo_descricao_key UNIQUE (centro_custo_descricao);


--
-- Name: centro_custo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centro_custo
    ADD CONSTRAINT centro_custo_pkey PRIMARY KEY (centro_custo_id);


--
-- Name: cf_relacaopid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cf_funcionario_valor
    ADD CONSTRAINT cf_relacaopid PRIMARY KEY (id);


--
-- Name: cf_relacaopid2; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.custos_folha_funcionario
    ADD CONSTRAINT cf_relacaopid2 PRIMARY KEY (id);


--
-- Name: cfop_cfop_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cfop
    ADD CONSTRAINT cfop_cfop_id_key UNIQUE (cfop_id, cfop_natureza, cfop_descricao);


--
-- Name: cfop_natureza_uk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cfop
    ADD CONSTRAINT cfop_natureza_uk UNIQUE (cfop_natureza);


--
-- Name: cfop_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cfop
    ADD CONSTRAINT cfop_pkey PRIMARY KEY (cfop_id);


--
-- Name: cheque_historico_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cheque_historico
    ADD CONSTRAINT cheque_historico_pkey PRIMARY KEY (cheqhist_id);


--
-- Name: cheque_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cheque
    ADD CONSTRAINT cheque_pkey PRIMARY KEY (cheque_id);


--
-- Name: cidades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cidades
    ADD CONSTRAINT cidades_pkey PRIMARY KEY (cidades_id);


--
-- Name: classificacao_classificacao_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classificacao
    ADD CONSTRAINT classificacao_classificacao_codigo_key UNIQUE (classificacao_codigo);


--
-- Name: classificacao_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classificacao
    ADD CONSTRAINT classificacao_pkey PRIMARY KEY (classificacao_id);


--
-- Name: cliente_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (aa80id);


--
-- Name: colecoes_colecoes_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.colecoes
    ADD CONSTRAINT colecoes_colecoes_codigo_key UNIQUE (colecoes_codigo);


--
-- Name: colecoes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.colecoes
    ADD CONSTRAINT colecoes_pkey PRIMARY KEY (colecoes_id);


--
-- Name: comisk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comissoes
    ADD CONSTRAINT comisk PRIMARY KEY (id);


--
-- Name: composicao_composicao_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.composicao
    ADD CONSTRAINT composicao_composicao_codigo_key UNIQUE (composicao_codigo);


--
-- Name: composicao_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.composicao
    ADD CONSTRAINT composicao_pkey PRIMARY KEY (composicao_id);


--
-- Name: conservacao_conservacao_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."conservacaoERR"
    ADD CONSTRAINT conservacao_conservacao_codigo_key UNIQUE (conservacao_codigo);


--
-- Name: conservacao_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."conservacaoERR"
    ADD CONSTRAINT conservacao_pkey PRIMARY KEY (conservacao_id);


--
-- Name: conta_corrente_cc_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conta_corrente
    ADD CONSTRAINT conta_corrente_cc_codigo_key UNIQUE (cc_codigo);


--
-- Name: conta_corrente_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conta_corrente
    ADD CONSTRAINT conta_corrente_pkey PRIMARY KEY (cc_id);


--
-- Name: conta_estoque_conta_estoque_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conta_estoque
    ADD CONSTRAINT conta_estoque_conta_estoque_codigo_key UNIQUE (conta_estoque_codigo);


--
-- Name: conta_estoque_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conta_estoque
    ADD CONSTRAINT conta_estoque_pkey PRIMARY KEY (conta_estoque_id);


--
-- Name: coridd; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customizacao_tela
    ADD CONSTRAINT coridd PRIMARY KEY (id);


--
-- Name: cst_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cst
    ADD CONSTRAINT cst_pkey PRIMARY KEY (cts_id);


--
-- Name: cstipipk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cst_ipi
    ADD CONSTRAINT cstipipk PRIMARY KEY (cst_ipi_id);


--
-- Name: ddpkbanco; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bancos_brasil
    ADD CONSTRAINT ddpkbanco PRIMARY KEY (id);


--
-- Name: deposito_deposito_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposito
    ADD CONSTRAINT deposito_deposito_codigo_key UNIQUE (deposito_codigo);


--
-- Name: deposito_endereco_deposito_endereco_numero_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposito_endereco
    ADD CONSTRAINT deposito_endereco_deposito_endereco_numero_key UNIQUE (deposito_endereco_numero);


--
-- Name: deposito_endereco_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposito_endereco
    ADD CONSTRAINT deposito_endereco_pkey PRIMARY KEY (deposito_endereco_id);


--
-- Name: deposito_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposito
    ADD CONSTRAINT deposito_pkey PRIMARY KEY (deposito_id);


--
-- Name: descontopk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.descontos
    ADD CONSTRAINT descontopk PRIMARY KEY (id);


--
-- Name: desid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.despesas_fixas
    ADD CONSTRAINT desid PRIMARY KEY (des_id);


--
-- Name: df10_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df10
    ADD CONSTRAINT df10_pkey PRIMARY KEY (df10id);


--
-- Name: df10_pkey2; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df10_temp
    ADD CONSTRAINT df10_pkey2 PRIMARY KEY (df10id);


--
-- Name: df20_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df20
    ADD CONSTRAINT df20_pkey PRIMARY KEY (df20id);


--
-- Name: dfgcpk_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfgc
    ADD CONSTRAINT dfgcpk_id PRIMARY KEY (dfgcid);


--
-- Name: dfidccid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfcc
    ADD CONSTRAINT dfidccid PRIMARY KEY (dfcc_id);


--
-- Name: dfidplcid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfplano_contas
    ADD CONSTRAINT dfidplcid PRIMARY KEY (dfplc_id);


--
-- Name: dflog_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dflog
    ADD CONSTRAINT dflog_id_pk PRIMARY KEY (dflog_id);


--
-- Name: ditid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.despesas_item
    ADD CONSTRAINT ditid PRIMARY KEY (dit_id);


--
-- Name: divisoes_producao_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.divisoes_producao
    ADD CONSTRAINT divisoes_producao_pkey PRIMARY KEY (divisoes_producao_id);


--
-- Name: email_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.email
    ADD CONSTRAINT email_pkey PRIMARY KEY (email_id);


--
-- Name: emails_artigo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emails_artigo
    ADD CONSTRAINT emails_artigo_pkey PRIMARY KEY (emails_artigo_id);


--
-- Name: embalagens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.embalagens
    ADD CONSTRAINT embalagens_pkey PRIMARY KEY (embalagens_id);


--
-- Name: empresa_empresa_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT empresa_empresa_codigo_key UNIQUE (empresa_codigo);


--
-- Name: empresa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT empresa_pkey PRIMARY KEY (empresa_id);


--
-- Name: encidpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.encargos
    ADD CONSTRAINT encidpk PRIMARY KEY (enc_id);


--
-- Name: estagios_estagios_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estagios
    ADD CONSTRAINT estagios_estagios_codigo_key UNIQUE (estagios_codigo);


--
-- Name: estagios_estagios_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estagios
    ADD CONSTRAINT estagios_estagios_descricao_key UNIQUE (estagios_descricao);


--
-- Name: estagios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estagios
    ADD CONSTRAINT estagios_pkey PRIMARY KEY (estagios_id);


--
-- Name: estampa_cilindro_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estampa_cilindro
    ADD CONSTRAINT estampa_cilindro_pkey PRIMARY KEY (estampa_cilindro_id);


--
-- Name: estampas_estampas_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estampas
    ADD CONSTRAINT estampas_estampas_codigo_key UNIQUE (estampas_codigo);


--
-- Name: estampas_estampas_codigo_key1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estampas
    ADD CONSTRAINT estampas_estampas_codigo_key1 UNIQUE (estampas_codigo, estampas_descricao);


--
-- Name: estampas_estampas_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estampas
    ADD CONSTRAINT estampas_estampas_descricao_key UNIQUE (estampas_descricao);


--
-- Name: estampas_estampas_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estampas
    ADD CONSTRAINT estampas_estampas_id_key UNIQUE (estampas_id, estampas_codigo);


--
-- Name: estampas_estampas_id_key1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estampas
    ADD CONSTRAINT estampas_estampas_id_key1 UNIQUE (estampas_id, estampas_codigo, estampas_descricao);


--
-- Name: estampas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estampas
    ADD CONSTRAINT estampas_pkey PRIMARY KEY (estampas_id);


--
-- Name: estoque_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estoque
    ADD CONSTRAINT estoque_pkey PRIMARY KEY (estoque_id);


--
-- Name: estoque_unicidade; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposito
    ADD CONSTRAINT estoque_unicidade UNIQUE (deposito_id, deposito_codigo, deposito_descricao);


--
-- Name: estrturaid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estrutura_custo
    ADD CONSTRAINT estrturaid PRIMARY KEY (id);


--
-- Name: eventosid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos
    ADD CONSTRAINT eventosid PRIMARY KEY (id);


--
-- Name: evpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos_folha
    ADD CONSTRAINT evpk PRIMARY KEY (id);


--
-- Name: exppk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expira
    ADD CONSTRAINT exppk PRIMARY KEY (exp_id);


--
-- Name: favoritos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favoritos
    ADD CONSTRAINT favoritos_pkey PRIMARY KEY (favoritos_id);


--
-- Name: fcreidpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fnc_creditos
    ADD CONSTRAINT fcreidpk PRIMARY KEY (fcre_id);


--
-- Name: fk_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chq_lote
    ADD CONSTRAINT fk_id PRIMARY KEY (chq_id);


--
-- Name: fksim; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.item_simula
    ADD CONSTRAINT fksim PRIMARY KEY (item_simula_id);


--
-- Name: flxipkid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fluxo_item
    ADD CONSTRAINT flxipkid PRIMARY KEY (flxi_id);


--
-- Name: flxpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fluxo_fixo
    ADD CONSTRAINT flxpk PRIMARY KEY (flx_id);


--
-- Name: fncid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fnc_item
    ADD CONSTRAINT fncid PRIMARY KEY (fnci_id);


--
-- Name: fncim; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fnc_imagem
    ADD CONSTRAINT fncim PRIMARY KEY (fnc_imagem_id);


--
-- Name: fnxidid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fnc_comentarios
    ADD CONSTRAINT fnxidid PRIMARY KEY (fnc_comentarios_id);


--
-- Name: funidsim; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.simulacoes_funcionarios
    ADD CONSTRAINT funidsim PRIMARY KEY (sfu_id);


--
-- Name: genero_genero_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.genero
    ADD CONSTRAINT genero_genero_codigo_key UNIQUE (genero_codigo);


--
-- Name: genero_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.genero
    ADD CONSTRAINT genero_pkey PRIMARY KEY (genero_id);


--
-- Name: grafico_grafico_codigo_grafico_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grafico
    ADD CONSTRAINT grafico_grafico_codigo_grafico_key UNIQUE (grafico_codigo_grafico);


--
-- Name: grafico_grafico_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grafico
    ADD CONSTRAINT grafico_grafico_id_key UNIQUE (grafico_id, grafico_imagem);


--
-- Name: grafico_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grafico
    ADD CONSTRAINT grafico_pkey PRIMARY KEY (grafico_id);


--
-- Name: grid_layouts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grid_layouts
    ADD CONSTRAINT grid_layouts_pkey PRIMARY KEY (id);


--
-- Name: grupo_encolhimento_grupo_encolhimento_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grupo_encolhimento
    ADD CONSTRAINT grupo_encolhimento_grupo_encolhimento_codigo_key UNIQUE (grupo_encolhimento_codigo);


--
-- Name: grupo_encolhimento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grupo_encolhimento
    ADD CONSTRAINT grupo_encolhimento_pkey PRIMARY KEY (grupo_encolhimento_id);


--
-- Name: grupo_maquinas_grupo_maquinas_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grupo_maquinas
    ADD CONSTRAINT grupo_maquinas_grupo_maquinas_codigo_key UNIQUE (grupo_maquinas_codigo);


--
-- Name: grupo_maquinas_grupo_maquinas_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grupo_maquinas
    ADD CONSTRAINT grupo_maquinas_grupo_maquinas_descricao_key UNIQUE (grupo_maquinas_descricao);


--
-- Name: grupo_maquinas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grupo_maquinas
    ADD CONSTRAINT grupo_maquinas_pkey PRIMARY KEY (grupo_maquinas_id);


--
-- Name: hc_caixa; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caixas_historico
    ADD CONSTRAINT hc_caixa PRIMARY KEY (hc_caixa_id);


--
-- Name: historico_FK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historico_fci
    ADD CONSTRAINT "historico_FK" PRIMARY KEY (historico_fci_id);


--
-- Name: historico_historico_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historico
    ADD CONSTRAINT historico_historico_codigo_key UNIQUE (historico_codigo);


--
-- Name: historico_historico_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historico
    ADD CONSTRAINT historico_historico_descricao_key UNIQUE (historico_descricao);


--
-- Name: historico_pecas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas_historico
    ADD CONSTRAINT historico_pecas_pkey PRIMARY KEY (hp_id);


--
-- Name: historico_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historico
    ADD CONSTRAINT historico_pkey PRIMARY KEY (historico_id);


--
-- Name: icms01_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.icms01
    ADD CONSTRAINT icms01_pkey PRIMARY KEY (icms01_id);


--
-- Name: icms_icms_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.icms
    ADD CONSTRAINT icms_icms_id_key UNIQUE (icms_id, icms_tabela, icms_codigo);


--
-- Name: icms_icms_tabela_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.icms
    ADD CONSTRAINT icms_icms_tabela_key UNIQUE (icms_tabela);


--
-- Name: icms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.icms
    ADD CONSTRAINT icms_pkey PRIMARY KEY (icms_id);


--
-- Name: id_cclas_ibs_cbs; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfe_cclas_tributacao_ibs_cbs
    ADD CONSTRAINT id_cclas_ibs_cbs PRIMARY KEY (id_cclas_ibs_cbs);


--
-- Name: id_credito_presumido_ibs_cbs; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfe_credito_presumido_ibs_cbs
    ADD CONSTRAINT id_credito_presumido_ibs_cbs PRIMARY KEY (id_credito_presumido_ibs_cbs);


--
-- Name: id_cst_ibs_cbs; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfe_cst_tributacao_ibs_cbs
    ADD CONSTRAINT id_cst_ibs_cbs PRIMARY KEY (id_cst_ibs_cbs);


--
-- Name: id_menu_base_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu_base
    ADD CONSTRAINT id_menu_base_pkey PRIMARY KEY (id);


--
-- Name: id_ncm_nbs_ibs_cbs; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfe_ncm_nbs_ibs_cbs
    ADD CONSTRAINT id_ncm_nbs_ibs_cbs PRIMARY KEY (id_ncm_nbs_ibs_cbs);


--
-- Name: id_usuario_menu_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_menu
    ADD CONSTRAINT id_usuario_menu_pkey PRIMARY KEY (id);


--
-- Name: idac; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acoes
    ADD CONSTRAINT idac PRIMARY KEY (id);


--
-- Name: idbol; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bolinhas_dash
    ADD CONSTRAINT idbol PRIMARY KEY (id);


--
-- Name: idcalc; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_calc
    ADD CONSTRAINT idcalc PRIMARY KEY (tcalc_id);


--
-- Name: iddd; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80classificacao
    ADD CONSTRAINT iddd PRIMARY KEY (id);


--
-- Name: iddescontopl; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.descontos_operacoes
    ADD CONSTRAINT iddescontopl PRIMARY KEY (id);


--
-- Name: idfnc; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fnc_fixo
    ADD CONSTRAINT idfnc PRIMARY KEY (fnc_id);


--
-- Name: idfr; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.frequencia
    ADD CONSTRAINT idfr PRIMARY KEY (id);


--
-- Name: idgripoo; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grupo_ocorrencia
    ADD CONSTRAINT idgripoo PRIMARY KEY (id);


--
-- Name: idhp; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.horas_padrao
    ADD CONSTRAINT idhp PRIMARY KEY (id);


--
-- Name: iditempop; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pop_item
    ADD CONSTRAINT iditempop PRIMARY KEY (id);


--
-- Name: idlogpd; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_log
    ADD CONSTRAINT idlogpd PRIMARY KEY (id);


--
-- Name: idmdk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu_desktop
    ADD CONSTRAINT idmdk PRIMARY KEY (id);


--
-- Name: idmenupkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu
    ADD CONSTRAINT idmenupkey PRIMARY KEY (id);


--
-- Name: idocorrenciax; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fnc_ocorrencia
    ADD CONSTRAINT idocorrenciax PRIMARY KEY (id);


--
-- Name: idoslog; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.os_log
    ADD CONSTRAINT idoslog PRIMARY KEY (id);


--
-- Name: idpkd; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_servico_reprocesso
    ADD CONSTRAINT idpkd PRIMARY KEY (osr_id);


--
-- Name: idpkk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finalidade
    ADD CONSTRAINT idpkk PRIMARY KEY (id);


--
-- Name: idplano_corte; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plano_corte
    ADD CONSTRAINT idplano_corte PRIMARY KEY (id);


--
-- Name: idpof; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pop_fixo
    ADD CONSTRAINT idpof PRIMARY KEY (id);


--
-- Name: idrepaca; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relacao_produto_os
    ADD CONSTRAINT idrepaca PRIMARY KEY (id);


--
-- Name: idrev; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.revisa_papel
    ADD CONSTRAINT idrev PRIMARY KEY (rev_papel_id);


--
-- Name: idsces; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.simulacoes_cenario
    ADD CONSTRAINT idsces PRIMARY KEY (sces_id);


--
-- Name: idsetup; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros_setup
    ADD CONSTRAINT idsetup PRIMARY KEY (id);


--
-- Name: idtorcamento; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento
    ADD CONSTRAINT idtorcamento PRIMARY KEY (torc_id);


--
-- Name: idusuam; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_ambientes
    ADD CONSTRAINT idusuam PRIMARY KEY (id);


--
-- Name: lal_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lote_apontamento_log
    ADD CONSTRAINT lal_pk PRIMARY KEY (lal_id);


--
-- Name: lbcPk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lancamento_bancario_classificacao
    ADD CONSTRAINT "lbcPk" PRIMARY KEY (lbc_id);


--
-- Name: lblpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lancamento_bancario_log
    ADD CONSTRAINT lblpk PRIMARY KEY (lbl_id);


--
-- Name: lbt_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lancamento_bancario_tipo
    ADD CONSTRAINT lbt_pk PRIMARY KEY (lbt_id);


--
-- Name: liberacao_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.liberacao
    ADD CONSTRAINT liberacao_pkey PRIMARY KEY (liberacao_id);


--
-- Name: llogid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lote_log
    ADD CONSTRAINT llogid PRIMARY KEY (llog_id);


--
-- Name: lopk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lancamento_ocorrencia
    ADD CONSTRAINT lopk PRIMARY KEY (lo_id);


--
-- Name: loteid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lote_produto
    ADD CONSTRAINT loteid PRIMARY KEY (lote_id);


--
-- Name: ltapk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lote_apontamento
    ADD CONSTRAINT ltapk PRIMARY KEY (lta_id);


--
-- Name: ltepk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lote_espalmadeira
    ADD CONSTRAINT ltepk PRIMARY KEY (lte_id);


--
-- Name: maquinas_maquinas_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maquinas
    ADD CONSTRAINT maquinas_maquinas_codigo_key UNIQUE (maquinas_grupo, maquinas_codigo);


--
-- Name: maquinas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maquinas
    ADD CONSTRAINT maquinas_pkey PRIMARY KEY (maquinas_id);


--
-- Name: mcp_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maquinas_capacidade
    ADD CONSTRAINT mcp_pk PRIMARY KEY (mcp_id);


--
-- Name: mkf_mkf_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mkf
    ADD CONSTRAINT mkf_mkf_id_key UNIQUE (mkf_id, mkf_nometabela);


--
-- Name: mkf_mkf_nometabela_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mkf
    ADD CONSTRAINT mkf_mkf_nometabela_key UNIQUE (mkf_nometabela);


--
-- Name: mkf_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mkf
    ADD CONSTRAINT mkf_pkey PRIMARY KEY (mkf_id);


--
-- Name: mki_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mki
    ADD CONSTRAINT mki_pkey PRIMARY KEY (mki_id);


--
-- Name: motivo_uso_producao_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.motivo_uso_producao
    ADD CONSTRAINT motivo_uso_producao_pkey PRIMARY KEY (motivo_uso_producao_id);


--
-- Name: motivos_bloqueios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.motivos_bloqueios
    ADD CONSTRAINT motivos_bloqueios_pkey PRIMARY KEY (mot_id);


--
-- Name: movest_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque
    ADD CONSTRAINT movest_id_pkey PRIMARY KEY (movest_id);


--
-- Name: movimentacao_roteiro_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimentacao_roteiro
    ADD CONSTRAINT movimentacao_roteiro_pkey PRIMARY KEY (movimentacao_roteiro_id);


--
-- Name: msg_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.msg
    ADD CONSTRAINT msg_pkey PRIMARY KEY (msg_id);


--
-- Name: mvta_estoque_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mvta_estoque
    ADD CONSTRAINT mvta_estoque_pkey PRIMARY KEY (mvta_estoque_id);


--
-- Name: nf_fixa_id_nota_fiscal_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_fixa
    ADD CONSTRAINT nf_fixa_id_nota_fiscal_key UNIQUE (id_nota_fiscal, emitente_codigo);


--
-- Name: nf_fixa_nf_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_fixa
    ADD CONSTRAINT nf_fixa_nf_id_key UNIQUE (nf_id, nota_bancos_codigo, nota_bancos_nome);


--
-- Name: nf_fixa_nota_numero_doc_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_fixa
    ADD CONSTRAINT nf_fixa_nota_numero_doc_key UNIQUE (nota_numero_doc, cliente_codigo);


--
-- Name: nf_fixa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_fixa
    ADD CONSTRAINT nf_fixa_pkey PRIMARY KEY (nf_id);


--
-- Name: nf_produtos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_item
    ADD CONSTRAINT nf_produtos_pkey PRIMARY KEY (id);


--
-- Name: nfc_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_complememtar
    ADD CONSTRAINT nfc_id_pk PRIMARY KEY (nfc_id);


--
-- Name: nomaqpkid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nomearq
    ADD CONSTRAINT nomaqpkid PRIMARY KEY (id);


--
-- Name: ob_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento
    ADD CONSTRAINT ob_id_pkey PRIMARY KEY (ob_id);


--
-- Name: obl_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_lote
    ADD CONSTRAINT obl_id_pk PRIMARY KEY (obl_id);


--
-- Name: ocid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.origem_ocorrencia
    ADD CONSTRAINT ocid PRIMARY KEY (oc_id);


--
-- Name: ocorrencia_ocorrencia_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ocorrencia
    ADD CONSTRAINT ocorrencia_ocorrencia_codigo_key UNIQUE (ocorrencia_codigo);


--
-- Name: ocorrencia_ocorrencia_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ocorrencia
    ADD CONSTRAINT ocorrencia_ocorrencia_descricao_key UNIQUE (ocorrencia_descricao);


--
-- Name: ocorrencia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ocorrencia
    ADD CONSTRAINT ocorrencia_pkey PRIMARY KEY (ocorrencia_id);


--
-- Name: of_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_fio
    ADD CONSTRAINT of_id_pk PRIMARY KEY (of_id);


--
-- Name: of_lote_uk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_fio
    ADD CONSTRAINT of_lote_uk UNIQUE (of_lote);


--
-- Name: ofid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orcamento_fixo
    ADD CONSTRAINT ofid PRIMARY KEY (of_id);


--
-- Name: okid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.liberacoes
    ADD CONSTRAINT okid PRIMARY KEY (lib_id);


--
-- Name: okk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conservacao
    ADD CONSTRAINT okk PRIMARY KEY (conservacao_id);


--
-- Name: oksim; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50item_simula
    ADD CONSTRAINT oksim PRIMARY KEY (aa50item_simula_id);


--
-- Name: operacoes_operacoes_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operacoes
    ADD CONSTRAINT operacoes_operacoes_codigo_key UNIQUE (operacoes_codigo);


--
-- Name: operacoes_operacoes_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operacoes
    ADD CONSTRAINT operacoes_operacoes_descricao_key UNIQUE (operacoes_descricao);


--
-- Name: operacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operacoes
    ADD CONSTRAINT operacoes_pkey PRIMARY KEY (operacoes_id);


--
-- Name: orcamentovencimento; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orcamento_vencimentos
    ADD CONSTRAINT orcamentovencimento PRIMARY KEY (id);


--
-- Name: oridpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orcamento_recebido
    ADD CONSTRAINT oridpk PRIMARY KEY (or_id);


--
-- Name: os_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_servico
    ADD CONSTRAINT os_id_pkey PRIMARY KEY (os_id);


--
-- Name: oslid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_parametros
    ADD CONSTRAINT oslid PRIMARY KEY (id);


--
-- Name: oslkid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_servico_laudo
    ADD CONSTRAINT oslkid PRIMARY KEY (osl_id);


--
-- Name: osm_idpkke; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_servico_mo
    ADD CONSTRAINT osm_idpkke PRIMARY KEY (osm_id);


--
-- Name: ossaid2; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_servico_aponta
    ADD CONSTRAINT ossaid2 PRIMARY KEY (osaa_id);


--
-- Name: ossaid3; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_servico_aponta_aberto
    ADD CONSTRAINT ossaid3 PRIMARY KEY (osaa_id);


--
-- Name: osslco; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_servico_lancadas
    ADD CONSTRAINT osslco PRIMARY KEY (ol_id);


--
-- Name: paises_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paises
    ADD CONSTRAINT paises_pkey PRIMARY KEY (paises_id);


--
-- Name: parametro_beneficiamento_parb_ob_tecidos_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_beneficiamento
    ADD CONSTRAINT parametro_beneficiamento_parb_ob_tecidos_key UNIQUE (parb_ob_tecidos, parb_ob_malhas, parb_ob_fios);


--
-- Name: parametro_beneficiamento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_beneficiamento
    ADD CONSTRAINT parametro_beneficiamento_pkey PRIMARY KEY (parb_id);


--
-- Name: parametro_financiamento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_financiamento
    ADD CONSTRAINT parametro_financiamento_pkey PRIMARY KEY (parfin_id);


--
-- Name: parametro_grafico_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_grafico
    ADD CONSTRAINT parametro_grafico_pkey PRIMARY KEY (parametro_grafico_id);


--
-- Name: parametro_nfe_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_nfe
    ADD CONSTRAINT parametro_nfe_pkey PRIMARY KEY (parnfe_id);


--
-- Name: parametros_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros
    ADD CONSTRAINT parametros_pkey PRIMARY KEY (parametros_id);


--
-- Name: parametros_smtp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros_smtp
    ADD CONSTRAINT parametros_smtp_pkey PRIMARY KEY (parametros_smtp_id);


--
-- Name: parametros_xml_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros_xml
    ADD CONSTRAINT parametros_xml_pkey PRIMARY KEY (parametros_xml_id);


--
-- Name: partida_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partida
    ADD CONSTRAINT partida_pkey PRIMARY KEY (partida_id);


--
-- Name: pb_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partida_beneficiamento
    ADD CONSTRAINT pb_id_pk PRIMARY KEY (pb_id);


--
-- Name: pbi_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partida_beneficiamento_item
    ADD CONSTRAINT pbi_id_pk PRIMARY KEY (pbi_id);


--
-- Name: pd_acab_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_acab
    ADD CONSTRAINT pd_acab_pkey PRIMARY KEY (pd_acab_id);


--
-- Name: pd_fixo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_fixo
    ADD CONSTRAINT pd_fixo_pkey PRIMARY KEY (pd_id);


--
-- Name: pd_proc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_proc
    ADD CONSTRAINT pd_proc_pkey PRIMARY KEY (pd_proc_id);


--
-- Name: pdfid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.padrao
    ADD CONSTRAINT pdfid PRIMARY KEY (pdr_id);


--
-- Name: pdi_item_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdi_item
    ADD CONSTRAINT pdi_item_pkey PRIMARY KEY (pdi_id);


--
-- Name: pdinuit; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_inutilizadas
    ADD CONSTRAINT pdinuit PRIMARY KEY (id);


--
-- Name: pdiset; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.setup_log
    ADD CONSTRAINT pdiset PRIMARY KEY (id);


--
-- Name: pdlid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.padrao_log
    ADD CONSTRAINT pdlid PRIMARY KEY (pdl_id);


--
-- Name: pecas_acabamento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas_acabamento
    ADD CONSTRAINT pecas_acabamento_pkey PRIMARY KEY (pecas_acabamento_id);


--
-- Name: pecas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas
    ADD CONSTRAINT pecas_pkey PRIMARY KEY (pec_id);


--
-- Name: pecas_processo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas_processo
    ADD CONSTRAINT pecas_processo_pkey PRIMARY KEY (pecas_processo_id);


--
-- Name: pfot; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orcamento_recebidos
    ADD CONSTRAINT pfot PRIMARY KEY (or_id);


--
-- Name: pfrflx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relacao_fluxo
    ADD CONSTRAINT pfrflx PRIMARY KEY (rflx_id);


--
-- Name: pjsetit; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.setup_item
    ADD CONSTRAINT pjsetit PRIMARY KEY (id);


--
-- Name: pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfterceiro
    ADD CONSTRAINT pk PRIMARY KEY (dfterceiro_id);


--
-- Name: pkFcp; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fcp
    ADD CONSTRAINT "pkFcp" PRIMARY KEY (fcp_id);


--
-- Name: pkID; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exc_entidade
    ADD CONSTRAINT "pkID" PRIMARY KEY (exc_entidade_id);


--
-- Name: pkIDprod; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exc_produto
    ADD CONSTRAINT "pkIDprod" PRIMARY KEY (exc_produto_id);


--
-- Name: pk_aa80tel_id_aa80_telefones; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80_telefones
    ADD CONSTRAINT pk_aa80tel_id_aa80_telefones PRIMARY KEY (aa80tel_id);


--
-- Name: pk_atv; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.atv
    ADD CONSTRAINT pk_atv PRIMARY KEY (atv_id);


--
-- Name: pk_cbenef; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cbenef
    ADD CONSTRAINT pk_cbenef PRIMARY KEY (id);


--
-- Name: pk_cbenef_cst; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cbenef_cst
    ADD CONSTRAINT pk_cbenef_cst PRIMARY KEY (id);


--
-- Name: pk_ccd_id_centro_custo_detalhes; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centro_custo_detalhes
    ADD CONSTRAINT pk_ccd_id_centro_custo_detalhes PRIMARY KEY (ccd_id);


--
-- Name: pk_cce_id__nf_fixa_cce; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_fixa_cce
    ADD CONSTRAINT pk_cce_id__nf_fixa_cce PRIMARY KEY (cce_id);


--
-- Name: pk_cid_tipo_log_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cidades_tipo_logradouro
    ADD CONSTRAINT pk_cid_tipo_log_id PRIMARY KEY (cid_tipo_log_id);


--
-- Name: pk_dflogtm_id_dflog_tipos_mov; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dflog_tipos_mov
    ADD CONSTRAINT pk_dflogtm_id_dflog_tipos_mov PRIMARY KEY (dflogtm_id);


--
-- Name: pk_idtipo_telefones_tipos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.telefones_tipos
    ADD CONSTRAINT pk_idtipo_telefones_tipos PRIMARY KEY (idtipo);


--
-- Name: pk_labd_idatualizacao_log_atualizacao_banco_dados; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_atualizacao_banco_dados
    ADD CONSTRAINT pk_labd_idatualizacao_log_atualizacao_banco_dados PRIMARY KEY (labd_idatualizacao);


--
-- Name: pk_nfid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_devolucao
    ADD CONSTRAINT pk_nfid PRIMARY KEY (nfd_id);


--
-- Name: pk_obh_id_ordem_beneficiamento_historicos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_historicos
    ADD CONSTRAINT pk_obh_id_ordem_beneficiamento_historicos PRIMARY KEY (obh_id);


--
-- Name: pk_variacao; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variacao
    ADD CONSTRAINT pk_variacao PRIMARY KEY (variacao_id);


--
-- Name: pk_variacao_item; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variacao_item
    ADD CONSTRAINT pk_variacao_item PRIMARY KEY (variacao_item_id);


--
-- Name: pkatividades; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.atividades_padrao
    ADD CONSTRAINT pkatividades PRIMARY KEY (ap_id);


--
-- Name: pkatividadesiten; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.atividades_padrao_item
    ADD CONSTRAINT pkatividadesiten PRIMARY KEY (api_id);


--
-- Name: pkblf; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bloco_fixo
    ADD CONSTRAINT pkblf PRIMARY KEY (blf_id);


--
-- Name: pkcancela; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_cancelados
    ADD CONSTRAINT pkcancela PRIMARY KEY (pdc_id);


--
-- Name: pkch; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bordero_cheque
    ADD CONSTRAINT pkch PRIMARY KEY (bc_id);


--
-- Name: pkchid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bd_fixo
    ADD CONSTRAINT pkchid PRIMARY KEY (id);


--
-- Name: pkchidbf; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bd_item
    ADD CONSTRAINT pkchidbf PRIMARY KEY (id);


--
-- Name: pkgru; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80grupo
    ADD CONSTRAINT pkgru PRIMARY KEY (aa80g_id);


--
-- Name: pkid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.custos_folha
    ADD CONSTRAINT pkid PRIMARY KEY (cf_id);


--
-- Name: pkidddes; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.desenho_descricao
    ADD CONSTRAINT pkidddes PRIMARY KEY (ddes_id);


--
-- Name: pkidi; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.custos_folha_item
    ADD CONSTRAINT pkidi PRIMARY KEY (cfi_id);


--
-- Name: pkkidd; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campanhas
    ADD CONSTRAINT pkkidd PRIMARY KEY (id);


--
-- Name: pklbid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lancamento_bancario
    ADD CONSTRAINT pklbid PRIMARY KEY (lb_id);


--
-- Name: pkmoeda; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.moeda_cotacao
    ADD CONSTRAINT pkmoeda PRIMARY KEY (moeda_cotacao_id);


--
-- Name: pknfcan; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_canceladas
    ADD CONSTRAINT pknfcan PRIMARY KEY (nfcan_id);


--
-- Name: pkobb; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_bloqueios
    ADD CONSTRAINT pkobb PRIMARY KEY (obb_id);


--
-- Name: pkobs; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.observacoes
    ADD CONSTRAINT pkobs PRIMARY KEY (obs_id);


--
-- Name: pkocoid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ocorrencia_papel
    ADD CONSTRAINT pkocoid PRIMARY KEY (ocorrencia_papel_id);


--
-- Name: pkondeusa; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50ondeusa
    ADD CONSTRAINT pkondeusa PRIMARY KEY (aa50ondeusa_id);


--
-- Name: pkparv; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_viscosidade
    ADD CONSTRAINT pkparv PRIMARY KEY (parv_id);


--
-- Name: pkpm; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50pratica_mercado
    ADD CONSTRAINT pkpm PRIMARY KEY (aa50pm_id);


--
-- Name: pkrolos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rolos
    ADD CONSTRAINT pkrolos PRIMARY KEY (rolos_id);


--
-- Name: pkrolosd; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rolos_deletados
    ADD CONSTRAINT pkrolosd PRIMARY KEY (rolos_id);


--
-- Name: pksc; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_compras
    ADD CONSTRAINT pksc PRIMARY KEY (sc_id);


--
-- Name: pksdcid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sdc_aux
    ADD CONSTRAINT pksdcid PRIMARY KEY (id);


--
-- Name: pksetu; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.setup
    ADD CONSTRAINT pksetu PRIMARY KEY (id);


--
-- Name: pksobras; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sobras
    ADD CONSTRAINT pksobras PRIMARY KEY (sobras_id);


--
-- Name: pktipostema; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tema
    ADD CONSTRAINT pktipostema PRIMARY KEY (tema_id);


--
-- Name: pkuf; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uf
    ADD CONSTRAINT pkuf PRIMARY KEY (uf_descricao);


--
-- Name: pkvariante; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variantes
    ADD CONSTRAINT pkvariante PRIMARY KEY (id);


--
-- Name: pkvendasf; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vendas_fixo
    ADD CONSTRAINT pkvendasf PRIMARY KEY (id);


--
-- Name: ples; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.espessuras
    ADD CONSTRAINT ples PRIMARY KEY (esp_id);


--
-- Name: plid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plano_contas
    ADD CONSTRAINT plid PRIMARY KEY (plc_id);


--
-- Name: primarykey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workflow_usuario
    ADD CONSTRAINT primarykey PRIMARY KEY (workflow_id);


--
-- Name: prioridade_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prioridade
    ADD CONSTRAINT prioridade_pkey PRIMARY KEY (prioridade_id);


--
-- Name: processo_tigimento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.processo_tigimento
    ADD CONSTRAINT processo_tigimento_pkey PRIMARY KEY (processo_tigimento_id);


--
-- Name: processo_tigimento_processo_tigimento_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.processo_tigimento
    ADD CONSTRAINT processo_tigimento_processo_tigimento_codigo_key UNIQUE (processo_tigimento_codigo);


--
-- Name: processo_tigimento_processo_tigimento_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.processo_tigimento
    ADD CONSTRAINT processo_tigimento_processo_tigimento_descricao_key UNIQUE (processo_tigimento_descricao);


--
-- Name: quadros_cilindro_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.quadros_cilindro
    ADD CONSTRAINT quadros_cilindro_pkey PRIMARY KEY (quadros_cilindro_id);


--
-- Name: quadros_cilindro_quadros_cilindro_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.quadros_cilindro
    ADD CONSTRAINT quadros_cilindro_quadros_cilindro_codigo_key UNIQUE (quadros_cilindro_codigo);


--
-- Name: qual_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qualidade
    ADD CONSTRAINT qual_id_pkey PRIMARY KEY (qual_id);


--
-- Name: receita_item_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receita_item
    ADD CONSTRAINT receita_item_pkey PRIMARY KEY (ri_id);


--
-- Name: referencia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.referencia
    ADD CONSTRAINT referencia_pkey PRIMARY KEY (ref_id);


--
-- Name: referencia_ref_nome_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.referencia
    ADD CONSTRAINT referencia_ref_nome_key UNIQUE (ref_nome);


--
-- Name: relaidcomp; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relacao_composicao
    ADD CONSTRAINT relaidcomp PRIMARY KEY (id);


--
-- Name: reotid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.retorno_producao
    ADD CONSTRAINT reotid PRIMARY KEY (id);


--
-- Name: retornopk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.arquivo_retorno
    ADD CONSTRAINT retornopk PRIMARY KEY (id);


--
-- Name: rom_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.romaneio
    ADD CONSTRAINT rom_id_pk PRIMARY KEY (rom_id);


--
-- Name: romi_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.romaneio_item
    ADD CONSTRAINT romi_id_pk PRIMARY KEY (romi_id);


--
-- Name: rop_chave_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relacao_ob_pb
    ADD CONSTRAINT rop_chave_pk PRIMARY KEY (rop_ob_id, rop_pb_id);


--
-- Name: roteiro_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roteiro
    ADD CONSTRAINT roteiro_id_pkey PRIMARY KEY (roteiro_id);


--
-- Name: roteiro_producao_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roteiro_producao
    ADD CONSTRAINT roteiro_producao_pkey PRIMARY KEY (roteiro_producao_id);


--
-- Name: rpai_filho_chave; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rpai_filho
    ADD CONSTRAINT rpai_filho_chave PRIMARY KEY (rpai_filho_id);


--
-- Name: scapk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_compras_aplicacao
    ADD CONSTRAINT scapk PRIMARY KEY (sca_id);


--
-- Name: scpkitem; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_compras_nivel
    ADD CONSTRAINT scpkitem PRIMARY KEY (sc_compras_nivel_id);


--
-- Name: sdc_pimaryKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sdc
    ADD CONSTRAINT "sdc_pimaryKey" PRIMARY KEY (sdc_id);


--
-- Name: sdcitemcor; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sdc_item_cor
    ADD CONSTRAINT sdcitemcor PRIMARY KEY (id);


--
-- Name: sdesid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.simulacoes_despesas
    ADD CONSTRAINT sdesid PRIMARY KEY (sdes_id);


--
-- Name: segmento_mercado_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.segmento_mercado
    ADD CONSTRAINT segmento_mercado_pkey PRIMARY KEY (segmento_mercado_id);


--
-- Name: segmento_mercado_segmento_mercado_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.segmento_mercado
    ADD CONSTRAINT segmento_mercado_segmento_mercado_codigo_key UNIQUE (segmento_mercado_codigo);


--
-- Name: segmento_mercado_segmento_mercado_codigo_key1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.segmento_mercado
    ADD CONSTRAINT segmento_mercado_segmento_mercado_codigo_key1 UNIQUE (segmento_mercado_codigo, segmento_mercado_descricao);


--
-- Name: segmento_mercado_segmento_mercado_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.segmento_mercado
    ADD CONSTRAINT segmento_mercado_segmento_mercado_descricao_key UNIQUE (segmento_mercado_descricao);


--
-- Name: serasaid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80_serasa
    ADD CONSTRAINT serasaid PRIMARY KEY (id);


--
-- Name: setores_cor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.series_cor
    ADD CONSTRAINT setores_cor_pkey PRIMARY KEY (series_cor_id);


--
-- Name: setup_maquinas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.setup_maquinas
    ADD CONSTRAINT setup_maquinas_pkey PRIMARY KEY (setup_maquinas_id);


--
-- Name: sfipk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.simulacoes_fixa
    ADD CONSTRAINT sfipk PRIMARY KEY (sfi_id);


--
-- Name: simpidfk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.simulacoes_impostos
    ADD CONSTRAINT simpidfk PRIMARY KEY (simp_id);


--
-- Name: slpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sdc_log
    ADD CONSTRAINT slpk PRIMARY KEY (sl_id);


--
-- Name: solicitacao_desenvolvimento_cor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_desenvolvimento_cor
    ADD CONSTRAINT solicitacao_desenvolvimento_cor_pkey PRIMARY KEY (solicitacao_desenvolvimento_cor_id);


--
-- Name: sss; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carrinho
    ADD CONSTRAINT sss PRIMARY KEY (id);


--
-- Name: subloteid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lote_sublote_item
    ADD CONSTRAINT subloteid PRIMARY KEY (lsi_id);


--
-- Name: sublotid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lote_sublote
    ADD CONSTRAINT sublotid PRIMARY KEY (lts_id);


--
-- Name: tabela_preco_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tabela_preco
    ADD CONSTRAINT tabela_preco_id_pkey PRIMARY KEY (tabela_preco_id);


--
-- Name: tbciPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tabela_custo_hora_item
    ADD CONSTRAINT "tbciPK" PRIMARY KEY (tbci_id);


--
-- Name: tconidpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_contrato
    ADD CONSTRAINT tconidpk PRIMARY KEY (tcon_id);


--
-- Name: tgrid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_agrupamento
    ADD CONSTRAINT tgrid PRIMARY KEY (tgr_id);


--
-- Name: tgridi; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_grupo
    ADD CONSTRAINT tgridi PRIMARY KEY (tgr_id);


--
-- Name: tipo_produto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_produto
    ADD CONSTRAINT tipo_produto_pkey PRIMARY KEY (tipo_produto_id);


--
-- Name: tipo_produto_tipo_produto_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_produto
    ADD CONSTRAINT tipo_produto_tipo_produto_codigo_key UNIQUE (tipo_produto_codigo);


--
-- Name: tipo_produto_tipo_produto_codigo_key1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_produto
    ADD CONSTRAINT tipo_produto_tipo_produto_codigo_key1 UNIQUE (tipo_produto_codigo, tipo_produto_descricao);


--
-- Name: tipo_produto_tipo_produto_descricao_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_produto
    ADD CONSTRAINT tipo_produto_tipo_produto_descricao_key UNIQUE (tipo_produto_descricao);


--
-- Name: tipos_calculo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_calculo
    ADD CONSTRAINT tipos_calculo_pkey PRIMARY KEY (tipos_calculo_id);


--
-- Name: tipos_calculo_tipos_calculo_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_calculo
    ADD CONSTRAINT tipos_calculo_tipos_calculo_codigo_key UNIQUE (tipos_calculo_codigo, tipos_calculo_descricao);


--
-- Name: tipos_materia_prima_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_materia_prima
    ADD CONSTRAINT tipos_materia_prima_pkey PRIMARY KEY (tipos_materia_prima_id);


--
-- Name: titid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_item
    ADD CONSTRAINT titid PRIMARY KEY (tit_id);


--
-- Name: tloid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_log
    ADD CONSTRAINT tloid PRIMARY KEY (tlo_id);


--
-- Name: tmoid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_mo
    ADD CONSTRAINT tmoid PRIMARY KEY (tmo_id);


--
-- Name: tocidpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_outros_custos
    ADD CONSTRAINT tocidpk PRIMARY KEY (toc_id);


--
-- Name: toque_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toque
    ADD CONSTRAINT toque_pkey PRIMARY KEY (toque_id);


--
-- Name: tpagidser; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_pagamento
    ADD CONSTRAINT tpagidser PRIMARY KEY (tpag_id);


--
-- Name: tpfgonr; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_fornecedor
    ADD CONSTRAINT tpfgonr PRIMARY KEY (tpf_id);


--
-- Name: tpm; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_moveis
    ADD CONSTRAINT tpm PRIMARY KEY (id);


--
-- Name: tpmobeis; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.moveis
    ADD CONSTRAINT tpmobeis PRIMARY KEY (id);


--
-- Name: tresidpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_responsavel
    ADD CONSTRAINT tresidpk PRIMARY KEY (tres_id);


--
-- Name: tstidpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.torcamento_servicos_terceiros
    ADD CONSTRAINT tstidpk PRIMARY KEY (tst_id);


--
-- Name: turno_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.turno
    ADD CONSTRAINT turno_id_pkey PRIMARY KEY (turno_id);


--
-- Name: ubid; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_bolinhas
    ADD CONSTRAINT ubid PRIMARY KEY (ub_id);


--
-- Name: uk_usuario_tela; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grid_layouts
    ADD CONSTRAINT uk_usuario_tela UNIQUE (usuario, tela);


--
-- Name: uk_variacao_codigo; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variacao
    ADD CONSTRAINT uk_variacao_codigo UNIQUE (variacao_codigo);


--
-- Name: umsoproduto; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fluxo_fixo
    ADD CONSTRAINT umsoproduto UNIQUE (flx_produto);


--
-- Name: unicidadePK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estoque
    ADD CONSTRAINT "unicidadePK" UNIQUE (estoque_depid, estoque_produtoid, estoque_itemid);


--
-- Name: unicidadeondeusa; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50ondeusa
    ADD CONSTRAINT unicidadeondeusa UNIQUE (aa50ondeusa_aa50id, aa50ondeusa_destino);


--
-- Name: unidade_medida_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.unidade_medida
    ADD CONSTRAINT unidade_medida_pkey PRIMARY KEY (unidade_medida_id);


--
-- Name: unidade_medida_unidade_medida_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.unidade_medida
    ADD CONSTRAINT unidade_medida_unidade_medida_codigo_key UNIQUE (unidade_medida_codigo);


--
-- Name: unidade_tecido_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilidades_tecido
    ADD CONSTRAINT unidade_tecido_pkey PRIMARY KEY (utilidades_tecido_id);


--
-- Name: uq_ccd_descricao_centro_custo_detalhes; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centro_custo_detalhes
    ADD CONSTRAINT uq_ccd_descricao_centro_custo_detalhes UNIQUE (ccd_centro_custo_id, ccd_descricao);


--
-- Name: uq_cid_tipo_log_abreviatura; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cidades_tipo_logradouro
    ADD CONSTRAINT uq_cid_tipo_log_abreviatura UNIQUE (cid_tipo_log_abreviatura);


--
-- Name: uq_cid_tipo_log_descricao; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cidades_tipo_logradouro
    ADD CONSTRAINT uq_cid_tipo_log_descricao UNIQUE (cid_tipo_log_descricao);


--
-- Name: uq_composta_aa80_telefones; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80_telefones
    ADD CONSTRAINT uq_composta_aa80_telefones UNIQUE (aa80tel_aa80id, aa80tel_ddd, aa80tel_idtipo, aa80tel_numero);


--
-- Name: uq_descricao_telefones_tipos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.telefones_tipos
    ADD CONSTRAINT uq_descricao_telefones_tipos UNIQUE (descricao);


--
-- Name: uq_dflogtm_descricao_dflog_tipos_mov; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dflog_tipos_mov
    ADD CONSTRAINT uq_dflogtm_descricao_dflog_tipos_mov UNIQUE (dflogtm_descricao);


--
-- Name: uq_versao_log_atualizacao_banco_dados; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_atualizacao_banco_dados
    ADD CONSTRAINT uq_versao_log_atualizacao_banco_dados UNIQUE (versao);


--
-- Name: usuario_consulta_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_consulta
    ADD CONSTRAINT usuario_consulta_pkey PRIMARY KEY (usuario_consulta_id);


--
-- Name: usuario_empresa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_empresa
    ADD CONSTRAINT usuario_empresa_pkey PRIMARY KEY (usuario_empresa_id);


--
-- Name: usuario_funcoes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_funcoes
    ADD CONSTRAINT usuario_funcoes_pkey PRIMARY KEY (usuario_funcao_id);


--
-- Name: usuario_funcoes_usuario_funcao_nome_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_funcoes
    ADD CONSTRAINT usuario_funcoes_usuario_funcao_nome_key UNIQUE (usuario_funcao_nome);


--
-- Name: usuario_grupo_funcoes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_grupo_funcoes
    ADD CONSTRAINT usuario_grupo_funcoes_pkey PRIMARY KEY (usuario_grupo_funcoes_id);


--
-- Name: usuario_grupo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_grupo
    ADD CONSTRAINT usuario_grupo_pkey PRIMARY KEY (usuario_grupo_id);


--
-- Name: usuario_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_log
    ADD CONSTRAINT usuario_log_pkey PRIMARY KEY (log_id);


--
-- Name: usuario_mensagem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_mensagem
    ADD CONSTRAINT usuario_mensagem_pkey PRIMARY KEY (usuario_mensagem_id);


--
-- Name: usuario_mensagem_remetente_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_mensagem_remetente
    ADD CONSTRAINT usuario_mensagem_remetente_pkey PRIMARY KEY (usuario_mensagem_remetente_id);


--
-- Name: usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (usuario_id);


--
-- Name: usuario_usuario_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_usuario_codigo_key UNIQUE (usuario_codigo);


--
-- Name: usuario_usuario_usuario_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_usuario_usuario_key UNIQUE (usuario_usuario);


--
-- Name: utilidades_tecido_utilidades_tecido_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilidades_tecido
    ADD CONSTRAINT utilidades_tecido_utilidades_tecido_codigo_key UNIQUE (utilidades_tecido_codigo);


--
-- Name: vendasitem; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vendas_item
    ADD CONSTRAINT vendasitem PRIMARY KEY (id_item);


--
-- Name: visidd; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visoes
    ADD CONSTRAINT visidd PRIMARY KEY (vis_id);


--
-- Name: workflow_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workflow
    ADD CONSTRAINT workflow_pkey PRIMARY KEY (workflow_id);


--
-- Name: 1aa80id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "1aa80id" ON public.aa80 USING btree (aa80id);


--
-- Name: Ind_Seq_Doc; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Ind_Seq_Doc" ON public.df10 USING btree (df10sequ NULLS FIRST, df10dtpagamento NULLS FIRST);


--
-- Name: Ind_df10_Doc; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Ind_df10_Doc" ON public.df10 USING btree (df10sequ NULLS FIRST, df10documento NULLS FIRST);


--
-- Name: Ind_df20_Doc; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Ind_df20_Doc" ON public.df20 USING btree (df20sequ NULLS FIRST, df20documento NULLS FIRST);


--
-- Name: _idx_pecas; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX _idx_pecas ON public.pecas USING btree (pec_prod_acab_id, pec_cor_acab_id);


--
-- Name: aa50comoinenteidd; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa50comoinenteidd ON public.aa50componentes USING btree (aa50componente_codigo, aa50componente_tipo, aa50componente_seq);


--
-- Name: aa50descricao; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa50descricao ON public.aa50 USING btree (aa50descricao);


--
-- Name: aa50idindices; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa50idindices ON public.aa50 USING btree (aa50id);


--
-- Name: aa50itemcor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa50itemcor ON public.aa50item USING btree (aa50item_cor_id);


--
-- Name: aa50itemid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa50itemid ON public.aa50item USING btree (aa50item_aa50);


--
-- Name: aa50itemx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa50itemx ON public.aa50item USING btree (aa50item_codigo);


--
-- Name: aa50linha_produto; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa50linha_produto ON public.aa50 USING btree (aa50linha_produto);


--
-- Name: aa50linhadeproduto; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa50linhadeproduto ON public.aa50 USING btree (aa50linha_produto);


--
-- Name: aa50nivel; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa50nivel ON public.aa50 USING btree (aa50nivel);


--
-- Name: aa80cliente; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa80cliente ON public.aa80 USING btree (aa80cliente);


--
-- Name: aa80codigo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa80codigo ON public.aa80 USING btree (aa80codigo);


--
-- Name: aa80cppj; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa80cppj ON public.aa80 USING btree (aa80ni);


--
-- Name: aa80na; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa80na ON public.aa80 USING btree (aa80na);


--
-- Name: aa80nome; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa80nome ON public.aa80 USING btree (aa80nome);


--
-- Name: aa80repres; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa80repres ON public.aa80 USING btree (aa80repres1id);


--
-- Name: aa80res; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aa80res ON public.aa80 USING btree (aa80representante);


--
-- Name: ab20aa65fk_mk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ab20aa65fk_mk ON public.ab20 USING btree (ab20empresa);


--
-- Name: ab20ab20fk_mk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ab20ab20fk_mk ON public.ab20 USING btree (ab20ccsup);


--
-- Name: ab20mk_uk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ab20mk_uk ON public.ab20 USING btree (ab20codigo, ab20empresa);


--
-- Name: ab20uk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ab20uk ON public.ab20 USING btree (ab20codigo, ab20empresa);


--
-- Name: ab311ab31fk_mk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ab311ab31fk_mk ON public.ab311 USING btree (ab311cond);


--
-- Name: ab311mk_uk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ab311mk_uk ON public.ab311 USING btree (ab311dias, ab311cond, ab311ref);


--
-- Name: ab311uk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ab311uk ON public.ab311 USING btree (ab311dias, ab311cond, ab311ref);


--
-- Name: ab98aa65fk_mk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ab98aa65fk_mk ON public.ab98 USING btree (ab98empresa);


--
-- Name: ab98ab19fk_mk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ab98ab19fk_mk ON public.ab98 USING btree (ab98cbo);


--
-- Name: ab98ab98fk_mk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ab98ab98fk_mk ON public.ab98 USING btree (ab98superior);


--
-- Name: ab98mk_uk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ab98mk_uk ON public.ab98 USING btree (ab98empresa, ab98codigo);


--
-- Name: ab98uk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ab98uk ON public.ab98 USING btree (ab98empresa, ab98codigo);


--
-- Name: artigosprodutosxx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX artigosprodutosxx ON public.artigosprodutos USING btree (artigosprodutos_codigo);


--
-- Name: atvsdcid_oper; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX atvsdcid_oper ON public.atv USING btree (atv_sdc, atv_operacao_id);


--
-- Name: bdash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bdash ON public.bolinhas_dash USING btree (indice);


--
-- Name: bdfix; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bdfix ON public.bd_fixo USING btree (id);


--
-- Name: bdibd; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bdibd ON public.bd_item USING btree (id_bordero);


--
-- Name: bdidd2; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bdidd2 ON public.bd_item USING btree (df10id);


--
-- Name: blid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX blid ON public.bloco_fixo USING btree (blf_id);


--
-- Name: bliid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bliid ON public.bloco_item USING btree (bli_id_bloco);


--
-- Name: bliidd; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX bliidd ON public.bloco_item USING btree (bli_classificacao_blocok);


--
-- Name: codig_estamoas; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX codig_estamoas ON public.estampas USING btree (estampas_codigo);


--
-- Name: data_emissao; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX data_emissao ON public.pd_fixo USING btree (pd_data_emissao);


--
-- Name: data_faturamento; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX data_faturamento ON public.pd_fixo USING btree (pd_data_faturamento);


--
-- Name: data_fechamento; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX data_fechamento ON public.pd_fixo USING btree (pd_data_fechamento);


--
-- Name: descricao; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX descricao ON public.estampas USING btree (estampas_descricao);


--
-- Name: df10entidadidx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX df10entidadidx ON public.df10 USING btree (df10entidadeid);


--
-- Name: dfid32; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX dfid32 ON public.dflog USING btree (dflog_documento);


--
-- Name: dflogid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX dflogid ON public.dflog USING btree (dflog_dfid);


--
-- Name: estampa_idxid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX estampa_idxid ON public.estampas USING btree (estampas_id);


--
-- Name: fav1; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fav1 ON public.favoritos USING btree (favoritos_usuario);


--
-- Name: fav2; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fav2 ON public.favoritos USING btree (favoritos_id);


--
-- Name: fav3; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fav3 ON public.favoritos USING btree (favoritos_tarefa);


--
-- Name: fki_aa50fornecedor_produto_fk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_aa50fornecedor_produto_fk ON public.aa50fornecedor USING btree (aa50fornecedor_produto);


--
-- Name: fki_movest_aa50id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_movest_aa50id ON public.mov_estoque USING btree (movest_prod_id);


--
-- Name: fki_movest_nf_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_movest_nf_item_id ON public.mov_estoque USING btree (movest_nf_item_id);


--
-- Name: fki_movest_pd_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_movest_pd_item_id ON public.mov_estoque USING btree (movest_pd_item_id);


--
-- Name: fki_movest_pec_id_fk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_movest_pec_id_fk ON public.mov_estoque USING btree (movest_pec_id);


--
-- Name: fki_pdi_cod_prod_fkey; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_pdi_cod_prod_fkey ON public.pdi_item USING btree (pdi_cod_prod);


--
-- Name: fki_rom_nf_fk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_rom_nf_fk ON public.romaneio USING btree (rom_nf);


--
-- Name: fluxoindice; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fluxoindice ON public.ordem_beneficiamento_fluxo USING hash (obf_ob_id);


--
-- Name: flx1; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flx1 ON public.fluxo_fixo USING btree (flx_produto);


--
-- Name: flxid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flxid ON public.fluxo_item USING btree (flxi_flx_id);


--
-- Name: idcsdcdesenho; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idcsdcdesenho ON public.sdc USING hash (sdc_desenho);


--
-- Name: idcsdcdesenhoestampa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idcsdcdesenhoestampa ON public.sdc USING hash (sdc_estampa_descricao);


--
-- Name: idcsdcid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idcsdcid ON public.sdc USING hash (sdc_id);


--
-- Name: idxNumero_ID; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "idxNumero_ID" ON public.nf_fixa USING btree (nf_id);


--
-- Name: idxNumero_doc; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "idxNumero_doc" ON public.nf_fixa USING btree (nota_numero_doc);


--
-- Name: idx_aa50_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aa50_id ON public.aa50 USING btree (aa50id);


--
-- Name: idx_cbenef_um; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cbenef_um ON public.cbenef USING btree (cbenef);


--
-- Name: idx_data_emissao; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_data_emissao ON public.nf_fixa USING btree (nota_dt_emissao);


--
-- Name: idx_df10_df10documentoid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_df10_df10documentoid ON public.df10 USING btree (df10documentoid NULLS FIRST);


--
-- Name: idx_df10_emissao; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_df10_emissao ON public.df10 USING btree (df10dtemissao NULLS FIRST);


--
-- Name: idx_df10_vcto; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_df10_vcto ON public.df10 USING btree (df10dtvencimento NULLS FIRST);


--
-- Name: idx_df20_df20documentoid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_df20_df20documentoid ON public.df20 USING btree (df20documentoid NULLS FIRST);


--
-- Name: idx_df20_emissao; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_df20_emissao ON public.df20 USING btree (df20dtemissao NULLS FIRST);


--
-- Name: idx_df20_vcto; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_df20_vcto ON public.df20 USING btree (df20dtvencimento NULLS FIRST);


--
-- Name: idx_estampas_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_estampas_id ON public.estampas USING btree (estampas_id);


--
-- Name: idx_id_pedido; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_id_pedido ON public.pdi_item USING btree (pdi_id_pedido NULLS FIRST);


--
-- Name: idx_maquinas_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_maquinas_id ON public.maquinas USING btree (maquinas_id);


--
-- Name: idx_nf_item; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_nf_item ON public.nf_item USING btree (nfiv_nota_id, nfiv_produto_id, nfiv_cor_id);


--
-- Name: idx_nf_romaneio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_nf_romaneio ON public.nf_fixa USING btree (nota_romaneio);


--
-- Name: idx_os_pdi; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_os_pdi ON public.ordem_servico USING btree (os_pdi_id);


--
-- Name: idx_pd_codigo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pd_codigo ON public.pd_fixo USING btree (pd_codigo NULLS FIRST);


--
-- Name: idx_pd_filtro; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pd_filtro ON public.pd_fixo USING btree (pd_empresa_id, pd_tipo_venda, pd_servico_vendas, pd_programado, pd_data_emissao);


--
-- Name: idx_pdi_estampas; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pdi_estampas ON public.pdi_item USING btree (pdi_estampa_id NULLS FIRST);


--
-- Name: idx_pdi_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pdi_id ON public.pdi_item USING btree (pdi_id NULLS FIRST);


--
-- Name: idx_pdi_pedido; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pdi_pedido ON public.pdi_item USING btree (pdi_id_pedido);


--
-- Name: idx_pec_pdi_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pec_pdi_id ON public.pecas USING btree (pec_pdi_id NULLS FIRST);


--
-- Name: idx_pecas_os; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pecas_os ON public.pecas USING btree (pec_ordem_servico_id);


--
-- Name: idx_pecas_os_romaneio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pecas_os_romaneio ON public.pecas USING btree (pec_ordem_servico_id, pec_romaneio);


--
-- Name: idx_pecas_romaneio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pecas_romaneio ON public.pecas USING btree (pec_romaneio);


--
-- Name: idx_romaneio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_romaneio ON public.pd_fixo USING btree (pd_romaneio NULLS FIRST);


--
-- Name: idx_telefone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_telefone ON public.telefones_tipos USING btree (descricao);


--
-- Name: idx_variantes_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_variantes_id ON public.variantes USING btree (id);


--
-- Name: idxexcid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idxexcid ON public.exc_entidade USING hash (exc_entidade_sdc);


--
-- Name: idxexcid2; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idxexcid2 ON public.exc_entidade USING btree (exc_entidade_sdc);


--
-- Name: idxexcidprod; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idxexcidprod ON public.exc_produto USING btree (exc_produto_sdc);


--
-- Name: index_hashordem_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_hashordem_id ON public.ordem_servico USING hash (os_id);


--
-- Name: index_hashordem_servico_lote; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_hashordem_servico_lote ON public.ordem_servico USING hash (os_lote);


--
-- Name: indxdescri; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX indxdescri ON public.variantes USING btree (descricao);


--
-- Name: lo_ordem_ididx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX lo_ordem_ididx ON public.lancamento_ocorrencia USING btree (lo_ordem_id);


--
-- Name: movest_tipo_movimento; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX movest_tipo_movimento ON public.mov_estoque USING btree (movest_tipo_movimento NULLS FIRST);


--
-- Name: msidx11; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msidx11 ON public.msg USING btree (msg_user_destino_id);


--
-- Name: mssgidx3; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX mssgidx3 ON public.msg USING btree (msg_status);


--
-- Name: nfiidd; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX nfiidd ON public.nf_item USING btree (nfiv_cor_id);


--
-- Name: nfiv_nota_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX nfiv_nota_id ON public.nf_item USING btree (nfiv_nota_id NULLS FIRST);


--
-- Name: nota_romaneio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX nota_romaneio ON public.nf_fixa USING btree (nota_romaneio);


--
-- Name: nvif_prod_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX nvif_prod_id ON public.nf_item USING btree (nfiv_produto_id NULLS FIRST, id_item NULLS FIRST);


--
-- Name: ob_aa50id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ob_aa50id_idx ON public.ordem_beneficiamento USING btree (ob_aa50id);


--
-- Name: ob_estampas_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ob_estampas_id_idx ON public.ordem_beneficiamento USING btree (ob_estampas_id);


--
-- Name: ob_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ob_id_idx ON public.ordem_beneficiamento USING btree (ob_id, ob_aa50id);


--
-- Name: oscodigoIdx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "oscodigoIdx" ON public.ordem_servico USING btree (os_codigo);


--
-- Name: osdataemissao; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX osdataemissao ON public.ordem_servico USING btree (os_data_emissao);


--
-- Name: osdatafinal; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX osdatafinal ON public.ordem_servico USING btree (os_data_final DESC);


--
-- Name: osdatapro; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX osdatapro ON public.ordem_servico USING btree (os_data_programacao);


--
-- Name: partidaLotemp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "partidaLotemp" ON public.partida USING btree (partida_lotemp_id);


--
-- Name: partida_compnente_nivel; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX partida_compnente_nivel ON public.partida USING btree (partida_componente_nivel);


--
-- Name: partida_componente_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX partida_componente_id ON public.partida USING btree (partida_componente_id);


--
-- Name: partida_os_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX partida_os_id ON public.partida USING btree (partida_os_id);


--
-- Name: partida_receita_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX partida_receita_id ON public.partida USING btree (partida_receita_id);


--
-- Name: partidaosid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX partidaosid ON public.partida USING btree (partida_receita_id, partida_os_id);


--
-- Name: pd_cod_cliente; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pd_cod_cliente ON public.pd_fixo USING btree (pd_cod_cliente);


--
-- Name: pd_cod_represenatnte; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pd_cod_represenatnte ON public.pd_fixo USING btree (pd_cod_representante);


--
-- Name: pdempresaid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pdempresaid ON public.pd_fixo USING btree (pd_empresa_id);


--
-- Name: pdi_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pdi_id ON public.pd_fixo USING btree (pd_id);


--
-- Name: pdiid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pdiid ON public.ordem_servico USING btree (os_pdi_id);


--
-- Name: pec_obtidxz; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pec_obtidxz ON public.pecas USING btree (pec_obt DESC);


--
-- Name: pec_ordemservico; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pec_ordemservico ON public.pecas USING btree (pec_ordem_servico_id);


--
-- Name: pec_qualidade_Idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "pec_qualidade_Idx" ON public.pecas USING btree (pec_qualidade NULLS FIRST);


--
-- Name: pec_romaneiodataidx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pec_romaneiodataidx ON public.pecas USING btree (pec_romaneiodata DESC);


--
-- Name: pec_status_revisao_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pec_status_revisao_idx ON public.pecas USING btree (pec_statusrevisao NULLS FIRST);


--
-- Name: pecromaneio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pecromaneio ON public.pecas USING btree (pec_romaneio);


--
-- Name: receita_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX receita_id ON public.receita_item USING btree (ri_receita_id);


--
-- Name: rolos_os_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX rolos_os_id ON public.rolos USING btree (rolos_os_id);


--
-- Name: tipo_de_pedido; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tipo_de_pedido ON public.pd_fixo USING btree (pd_servico_vendas);


--
-- Name: usmd; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX usmd ON public.usuario_funcoes USING btree (usuario_funcao_nome);


--
-- Name: usuariox; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX usuariox ON public.usuario USING btree (usuario_id);


--
-- Name: usuariox4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX usuariox4 ON public.usuario USING btree (usuario_usuario);


--
-- Name: usuarioxz; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX usuarioxz ON public.usuario USING btree (usuario_nome);


--
-- Name: aa50_aa50artigo_produto_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50artigo_produto_fkey FOREIGN KEY (aa50artigo_produto) REFERENCES public.artigosprodutos(artigosprodutos_codigo);


--
-- Name: aa50_aa50artigo_produto_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50artigo_produto_fkey1 FOREIGN KEY (aa50artigo_produto, aa50artigo_produto_descricao) REFERENCES public.artigosprodutos(artigosprodutos_codigo, artigosprodutos_descricao) ON UPDATE CASCADE;


--
-- Name: aa50_aa50cfop_est_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50cfop_est_id_fkey FOREIGN KEY (aa50cfop_est_id, aa50cfop_est_natureza, aa50cfop_est_descr) REFERENCES public.cfop(cfop_id, cfop_natureza, cfop_descricao) ON UPDATE CASCADE;


--
-- Name: aa50_aa50cfop_fora_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50cfop_fora_id_fkey FOREIGN KEY (aa50cfop_fora_id, aa50cfop_fora_natureza, aa50cfop_fora_descr) REFERENCES public.cfop(cfop_id, cfop_natureza, cfop_descricao) ON UPDATE CASCADE;


--
-- Name: aa50_aa50classificacao_fiscal_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50classificacao_fiscal_fkey FOREIGN KEY (aa50classificacao_fiscal) REFERENCES public.classificacao(classificacao_codigo);


--
-- Name: aa50_aa50colecao_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50colecao_fkey FOREIGN KEY (aa50colecao) REFERENCES public.colecoes(colecoes_codigo);


--
-- Name: aa50_aa50genero_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50genero_fkey FOREIGN KEY (aa50genero) REFERENCES public.genero(genero_codigo);


--
-- Name: aa50_aa50icms_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50icms_id_fkey FOREIGN KEY (aa50icms_id, aa50icms_tabela, aa50icms_codigo) REFERENCES public.icms(icms_id, icms_tabela, icms_codigo) ON UPDATE CASCADE;


--
-- Name: aa50_aa50um_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50um_fkey FOREIGN KEY (aa50um) REFERENCES public.unidade_medida(unidade_medida_codigo);


--
-- Name: aa50_aa50utilidadeproduto_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50
    ADD CONSTRAINT aa50_aa50utilidadeproduto_fkey FOREIGN KEY (aa50utilidadeproduto) REFERENCES public.utilidades_tecido(utilidades_tecido_codigo);


--
-- Name: aa50componentes_aa50componente_codigo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50componentes
    ADD CONSTRAINT aa50componentes_aa50componente_codigo_fkey FOREIGN KEY (aa50componente_codigo) REFERENCES public.aa50(aa50id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: aa50componentes_aa50componente_componente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50componentes
    ADD CONSTRAINT aa50componentes_aa50componente_componente_fkey FOREIGN KEY (aa50componente_componente) REFERENCES public.aa50(aa50id) ON DELETE CASCADE;


--
-- Name: aa50estrutura_aa50estrutura_aa50item_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50estrutura
    ADD CONSTRAINT aa50estrutura_aa50estrutura_aa50item_fkey FOREIGN KEY (aa50estrutura_aa50item) REFERENCES public.aa50item(aa50item_id);


--
-- Name: aa50fornecedor_produto_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50fornecedor
    ADD CONSTRAINT aa50fornecedor_produto_fk FOREIGN KEY (aa50fornecedor_produto) REFERENCES public.aa50(aa50id) ON DELETE CASCADE;


--
-- Name: aa50item_aa50item_aa50_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50item
    ADD CONSTRAINT aa50item_aa50item_aa50_fkey FOREIGN KEY (aa50item_aa50) REFERENCES public.aa50(aa50id);


--
-- Name: aa50item_aa50item_codigo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50item
    ADD CONSTRAINT aa50item_aa50item_codigo_fkey FOREIGN KEY (aa50item_codigo, aa50item_descricao) REFERENCES public.estampas(estampas_codigo, estampas_descricao) ON UPDATE CASCADE;


--
-- Name: aa50preco_aa50_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50preco
    ADD CONSTRAINT aa50preco_aa50_fkey FOREIGN KEY (aa50preco_aa50id) REFERENCES public.aa50(aa50id);


--
-- Name: aa50preco_series_cor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50preco
    ADD CONSTRAINT aa50preco_series_cor_fkey FOREIGN KEY (aa50preco_series_cor_id) REFERENCES public.series_cor(series_cor_id);


--
-- Name: aa50preco_tabela_preco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50preco
    ADD CONSTRAINT aa50preco_tabela_preco_fkey FOREIGN KEY (aa50preco_tabela_preco_id) REFERENCES public.tabela_preco(tabela_preco_id);


--
-- Name: aa50variacao_fk_aa50; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50variacao
    ADD CONSTRAINT aa50variacao_fk_aa50 FOREIGN KEY (aa50variacao_aa50id) REFERENCES public.aa50(aa50id);


--
-- Name: aa50variacao_fk_variacao; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa50variacao
    ADD CONSTRAINT aa50variacao_fk_variacao FOREIGN KEY (aa50variacao_variacao_id) REFERENCES public.variacao(variacao_id);


--
-- Name: aa80_aa80banco_codigo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80
    ADD CONSTRAINT aa80_aa80banco_codigo_fkey FOREIGN KEY (aa80banco_codigo, aa80banco_descricao) REFERENCES public.bancos(bco_codigo, bco_nome) ON UPDATE CASCADE;


--
-- Name: aa80endcobra_aa80endcobra_entidade_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80endcobra
    ADD CONSTRAINT aa80endcobra_aa80endcobra_entidade_fkey FOREIGN KEY (aa80endcobra_entidade) REFERENCES public.aa80(aa80id);


--
-- Name: aa80endentr_aa80endentr_entidade_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80endentr
    ADD CONSTRAINT aa80endentr_aa80endentr_entidade_fkey FOREIGN KEY (aa80endentr_entidade) REFERENCES public.aa80(aa80id);


--
-- Name: aa80fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dfterceiro
    ADD CONSTRAINT aa80fk FOREIGN KEY (dfterceiro_cliente_id) REFERENCES public.aa80(aa80id);


--
-- Name: aa80inf_aa80inf_entida_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80inf
    ADD CONSTRAINT aa80inf_aa80inf_entida_fkey FOREIGN KEY (aa80inf_entida) REFERENCES public.aa80(aa80id);


--
-- Name: aa80mk_aa80mk_entidade_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80mk
    ADD CONSTRAINT aa80mk_aa80mk_entidade_fkey FOREIGN KEY (aa80mk_entidade) REFERENCES public.aa80(aa80id);


--
-- Name: ab20aa65fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab20
    ADD CONSTRAINT ab20aa65fk FOREIGN KEY (ab20empresa) REFERENCES public.empresa(empresa_id);


--
-- Name: ab20ab20fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab20
    ADD CONSTRAINT ab20ab20fk FOREIGN KEY (ab20ccsup) REFERENCES public.ab20(ab20id);


--
-- Name: ab311ab31fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ab311
    ADD CONSTRAINT ab311ab31fk FOREIGN KEY (ab311cond) REFERENCES public.ab31(ab31id);


--
-- Name: amostra_amostra_Produto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.amostra
    ADD CONSTRAINT "amostra_amostra_Produto_id_fkey" FOREIGN KEY (amostra_produto_id) REFERENCES public.aa50(aa50id);


--
-- Name: cai_of_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caixas
    ADD CONSTRAINT cai_of_id_fk FOREIGN KEY (cai_of_id) REFERENCES public.ordem_fio(of_id) ON DELETE CASCADE;


--
-- Name: cheque_historico_cheqhist_cheque_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cheque_historico
    ADD CONSTRAINT cheque_historico_cheqhist_cheque_fkey FOREIGN KEY (cheqhist_cheque) REFERENCES public.cheque(cheque_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: conta_corrente_cc_banco_cod_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conta_corrente
    ADD CONSTRAINT conta_corrente_cc_banco_cod_fkey FOREIGN KEY (cc_banco_cod, cc_banco_nome) REFERENCES public.bancos(bco_codigo, bco_nome) ON UPDATE CASCADE;


--
-- Name: deposito_endereco_deposito_endereco_deposito_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposito_endereco
    ADD CONSTRAINT deposito_endereco_deposito_endereco_deposito_fkey FOREIGN KEY (deposito_endereco_deposito) REFERENCES public.deposito(deposito_id);


--
-- Name: deposito_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mvta_estoque
    ADD CONSTRAINT deposito_fk FOREIGN KEY (mvta_estoque_depid1, mvta_estoque_depcodigo1, mvta_estoque_depnome1) REFERENCES public.deposito(deposito_id, deposito_codigo, deposito_descricao) ON UPDATE CASCADE;


--
-- Name: df10_df10historico_descricao_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df10
    ADD CONSTRAINT df10_df10historico_descricao_fkey FOREIGN KEY (df10historico_descricao) REFERENCES public.historico(historico_descricao);


--
-- Name: df10_df10historico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df10
    ADD CONSTRAINT df10_df10historico_fkey FOREIGN KEY (df10historico) REFERENCES public.historico(historico_codigo);


--
-- Name: df20_df20historico_descricao_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df20
    ADD CONSTRAINT df20_df20historico_descricao_fkey FOREIGN KEY (df20historico_descricao) REFERENCES public.historico(historico_descricao);


--
-- Name: df20_df20historico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df20
    ADD CONSTRAINT df20_df20historico_fkey FOREIGN KEY (df20historico) REFERENCES public.historico(historico_codigo);


--
-- Name: empresa_empresa_cidade_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT empresa_empresa_cidade_id_fkey FOREIGN KEY (empresa_cidade_id) REFERENCES public.cidades(cidades_id);


--
-- Name: favoritos_favoritos_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favoritos
    ADD CONSTRAINT favoritos_favoritos_usuario_fkey FOREIGN KEY (favoritos_usuario) REFERENCES public.usuario(usuario_id);


--
-- Name: fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.custos_folha_item
    ADD CONSTRAINT fk FOREIGN KEY (cfi_cf_id) REFERENCES public.custos_folha(cf_id);


--
-- Name: fk_aa80aa80tel_idtipo_aa80_telefones; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80_telefones
    ADD CONSTRAINT fk_aa80aa80tel_idtipo_aa80_telefones FOREIGN KEY (aa80tel_idtipo) REFERENCES public.telefones_tipos(idtipo);


--
-- Name: fk_aa80tel_entidadeid_aa80_telefones; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aa80_telefones
    ADD CONSTRAINT fk_aa80tel_entidadeid_aa80_telefones FOREIGN KEY (aa80tel_aa80id) REFERENCES public.aa80(aa80id) ON DELETE CASCADE;


--
-- Name: fk_ccd_centro_custo_id_centro_custo_detalhes; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centro_custo_detalhes
    ADD CONSTRAINT fk_ccd_centro_custo_id_centro_custo_detalhes FOREIGN KEY (ccd_centro_custo_id) REFERENCES public.centro_custo(centro_custo_id);


--
-- Name: fk_centro_custo_ccd_id_centro_custo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centro_custo
    ADD CONSTRAINT fk_centro_custo_ccd_id_centro_custo FOREIGN KEY (centro_custo_ccd_id) REFERENCES public.centro_custo_detalhes(ccd_id);


--
-- Name: fk_df10_ccd_id_df10; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df10
    ADD CONSTRAINT fk_df10_ccd_id_df10 FOREIGN KEY (df10_ccd_id) REFERENCES public.centro_custo_detalhes(ccd_id);


--
-- Name: fk_df20_ccd_id_df20; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.df20
    ADD CONSTRAINT fk_df20_ccd_id_df20 FOREIGN KEY (df20_ccd_id) REFERENCES public.centro_custo_detalhes(ccd_id);


--
-- Name: fk_dflog_dflogtm_id_dflog; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dflog
    ADD CONSTRAINT fk_dflog_dflogtm_id_dflog FOREIGN KEY (dflog_dflogtm_id) REFERENCES public.dflog_tipos_mov(dflogtm_id);


--
-- Name: fk_nf_id__nf_fixa_cce; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_fixa_cce
    ADD CONSTRAINT fk_nf_id__nf_fixa_cce FOREIGN KEY (cce_nf_id) REFERENCES public.nf_fixa(nf_id);


--
-- Name: fk_obh_aa50id_ordem_beneficiamento_historicos; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_historicos
    ADD CONSTRAINT fk_obh_aa50id_ordem_beneficiamento_historicos FOREIGN KEY (obh_aa50id) REFERENCES public.aa50(aa50id);


--
-- Name: fk_obh_ob_id_ordem_beneficiamento_historicos; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_historicos
    ADD CONSTRAINT fk_obh_ob_id_ordem_beneficiamento_historicos FOREIGN KEY (obh_ob_id) REFERENCES public.ordem_beneficiamento(ob_id);


--
-- Name: fk_obh_obh_estampas_id_ordem_beneficiamento_historicos; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_historicos
    ADD CONSTRAINT fk_obh_obh_estampas_id_ordem_beneficiamento_historicos FOREIGN KEY (obh_estampas_id) REFERENCES public.estampas(estampas_id);


--
-- Name: fk_obh_usuario_id_ordem_beneficiamento_historicos; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_historicos
    ADD CONSTRAINT fk_obh_usuario_id_ordem_beneficiamento_historicos FOREIGN KEY (obh_usuario_id) REFERENCES public.usuario(usuario_id);


--
-- Name: fk_variacao_item_variacao_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variacao_item
    ADD CONSTRAINT fk_variacao_item_variacao_id FOREIGN KEY (variacao_item_variacao_id) REFERENCES public.variacao(variacao_id) ON DELETE CASCADE;


--
-- Name: icms01_icms01_id_tabela_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.icms01
    ADD CONSTRAINT icms01_icms01_id_tabela_fkey FOREIGN KEY (icms01_id_tabela) REFERENCES public.icms(icms_id);


--
-- Name: liberacao_liberacao_item_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.liberacao
    ADD CONSTRAINT liberacao_liberacao_item_fkey FOREIGN KEY (liberacao_item) REFERENCES public.nf_item(id);


--
-- Name: liberacao_liberacao_ocorrencia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.liberacao
    ADD CONSTRAINT liberacao_liberacao_ocorrencia_fkey FOREIGN KEY (liberacao_ocorrencia) REFERENCES public.ocorrencia(ocorrencia_codigo);


--
-- Name: mki_mki_mkf_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mki
    ADD CONSTRAINT mki_mki_mkf_id_fkey FOREIGN KEY (mki_mkf_id, mki_mkf_nometabela) REFERENCES public.mkf(mkf_id, mkf_nometabela) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: movest_aa50_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque
    ADD CONSTRAINT movest_aa50_fkey FOREIGN KEY (movest_prod_id) REFERENCES public.aa50(aa50id);


--
-- Name: movest_aa50item_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque
    ADD CONSTRAINT movest_aa50item_fkey FOREIGN KEY (movest_item_id) REFERENCES public.aa50item(aa50item_id);


--
-- Name: movest_ab59_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque
    ADD CONSTRAINT movest_ab59_fkey FOREIGN KEY (movest_movimentacao) REFERENCES public.ab59(ab59id);


--
-- Name: movest_cai_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque
    ADD CONSTRAINT movest_cai_id_fk FOREIGN KEY (movest_cai_id) REFERENCES public.caixas(cai_id) ON DELETE CASCADE;


--
-- Name: movest_deposito_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque
    ADD CONSTRAINT movest_deposito_fkey FOREIGN KEY (movest_deposito_id) REFERENCES public.deposito(deposito_id);


--
-- Name: movest_nf_item_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque
    ADD CONSTRAINT movest_nf_item_id FOREIGN KEY (movest_nf_item_id) REFERENCES public.nf_item(id) ON DELETE CASCADE;


--
-- Name: movest_pd_item_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque
    ADD CONSTRAINT movest_pd_item_id FOREIGN KEY (movest_pd_item_id) REFERENCES public.pdi_item(pdi_id) ON DELETE CASCADE;


--
-- Name: movest_pec_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque
    ADD CONSTRAINT movest_pec_id_fk FOREIGN KEY (movest_pec_id) REFERENCES public.pecas(pec_id) ON DELETE CASCADE;


--
-- Name: movest_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mov_estoque
    ADD CONSTRAINT movest_usuario_fkey FOREIGN KEY (movest_usuario_id) REFERENCES public.usuario(usuario_id);


--
-- Name: movimentacao_roteiro_turno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimentacao_roteiro
    ADD CONSTRAINT movimentacao_roteiro_turno_fkey FOREIGN KEY (movimentacao_roteiro_turno_id) REFERENCES public.turno(turno_id);


--
-- Name: nf_fixa_nota_bancos_codigo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_fixa
    ADD CONSTRAINT nf_fixa_nota_bancos_codigo_fkey FOREIGN KEY (nota_bancos_codigo, nota_bancos_nome) REFERENCES public.bancos(bco_codigo, bco_nome) ON UPDATE CASCADE;


--
-- Name: nf_item_nfi_cor_sistema_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_item
    ADD CONSTRAINT nf_item_nfi_cor_sistema_fkey FOREIGN KEY (nfi_cor_sistema) REFERENCES public.estampas(estampas_codigo);


--
-- Name: nf_item_nfi_id_nota_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_item
    ADD CONSTRAINT nf_item_nfi_id_nota_fkey FOREIGN KEY (nfi_id_nota) REFERENCES public.nf_fixa(nf_id);


--
-- Name: nf_item_nfi_produto_codigo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_item
    ADD CONSTRAINT nf_item_nfi_produto_codigo_fkey FOREIGN KEY (nfi_produto_codigo) REFERENCES public.aa50(aa50id);


--
-- Name: nf_item_nfiv_acabamento_codigo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_item
    ADD CONSTRAINT nf_item_nfiv_acabamento_codigo_fkey FOREIGN KEY (nfiv_acabamento_codigo) REFERENCES public.acabamento(acabamento_codigo) ON UPDATE CASCADE;


--
-- Name: nf_item_nfiv_acabamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_item
    ADD CONSTRAINT nf_item_nfiv_acabamento_fkey FOREIGN KEY (nfiv_acabamento) REFERENCES public.acabamento(acabamento_descricao) ON UPDATE CASCADE;


--
-- Name: nf_item_nfiv_cor_descricao_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_item
    ADD CONSTRAINT nf_item_nfiv_cor_descricao_fkey FOREIGN KEY (nfiv_cor_descricao) REFERENCES public.estampas(estampas_descricao) ON UPDATE CASCADE;


--
-- Name: nfc_nf_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nf_complememtar
    ADD CONSTRAINT nfc_nf_id_fk FOREIGN KEY (nfc_nf_id) REFERENCES public.nf_fixa(nf_id) ON DELETE CASCADE;


--
-- Name: ob_aa50id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento
    ADD CONSTRAINT ob_aa50id_fk FOREIGN KEY (ob_aa50id) REFERENCES public.aa50(aa50id);


--
-- Name: ob_estampas_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento
    ADD CONSTRAINT ob_estampas_id_fk FOREIGN KEY (ob_estampas_id) REFERENCES public.estampas(estampas_id);


--
-- Name: obl_ob_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_lote
    ADD CONSTRAINT obl_ob_id_fk FOREIGN KEY (obl_ob_id) REFERENCES public.ordem_beneficiamento(ob_id) ON DELETE CASCADE;


--
-- Name: obl_os_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_beneficiamento_lote
    ADD CONSTRAINT obl_os_id_fk FOREIGN KEY (obl_os_id) REFERENCES public.ordem_servico(os_id) ON DELETE RESTRICT;


--
-- Name: of_aa50id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordem_fio
    ADD CONSTRAINT of_aa50id_fkey FOREIGN KEY (of_aa50id) REFERENCES public.aa50(aa50id);


--
-- Name: parametro_financiamento_parfin_banco_codigo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_financiamento
    ADD CONSTRAINT parametro_financiamento_parfin_banco_codigo_fkey FOREIGN KEY (parfin_banco_codigo, parfin_banco_descricao) REFERENCES public.bancos(bco_codigo, bco_nome) ON UPDATE CASCADE;


--
-- Name: parametro_nfe_parnfe_ab15codigo_entrada_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_nfe
    ADD CONSTRAINT parametro_nfe_parnfe_ab15codigo_entrada_fkey FOREIGN KEY (parnfe_ab15codigo_entrada) REFERENCES public.ab15(ab15codigo) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: parametro_nfe_parnfe_ab15codigo_saida_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro_nfe
    ADD CONSTRAINT parametro_nfe_parnfe_ab15codigo_saida_fkey FOREIGN KEY (parnfe_ab15codigo_saida) REFERENCES public.ab15(ab15codigo) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: parametros_xml_parametros_xml_fio_deposito_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros_xml
    ADD CONSTRAINT parametros_xml_parametros_xml_fio_deposito_fkey FOREIGN KEY (parametros_xml_fio_deposito) REFERENCES public.deposito(deposito_codigo);


--
-- Name: parametros_xml_parametros_xml_mc_deposito_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros_xml
    ADD CONSTRAINT parametros_xml_parametros_xml_mc_deposito_fkey FOREIGN KEY (parametros_xml_mc_deposito) REFERENCES public.deposito(deposito_codigo);


--
-- Name: pb_receita_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partida_beneficiamento
    ADD CONSTRAINT pb_receita_id_fk FOREIGN KEY (pb_receita_id) REFERENCES public.aa50(aa50id);


--
-- Name: pbi_aa50id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partida_beneficiamento_item
    ADD CONSTRAINT pbi_aa50id_fk FOREIGN KEY (pbi_aa50id) REFERENCES public.aa50(aa50id);


--
-- Name: pbi_pb_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partida_beneficiamento_item
    ADD CONSTRAINT pbi_pb_id FOREIGN KEY (pbi_pb_id) REFERENCES public.partida_beneficiamento(pb_id) ON DELETE CASCADE;


--
-- Name: pd_acab_pd_acab_acabamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_acab
    ADD CONSTRAINT pd_acab_pd_acab_acabamento_fkey FOREIGN KEY (pd_acab_acabamento) REFERENCES public.acabamento(acabamento_descricao);


--
-- Name: pd_fixo_pd_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_fixo
    ADD CONSTRAINT pd_fixo_pd_empresa_id_fkey FOREIGN KEY (pd_empresa_id) REFERENCES public.empresa(empresa_id);


--
-- Name: pd_proc_pd_acab_proc_processo_cod_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_proc
    ADD CONSTRAINT pd_proc_pd_acab_proc_processo_cod_fkey FOREIGN KEY (pd_proc_processo_cod) REFERENCES public.processo_tigimento(processo_tigimento_codigo);


--
-- Name: pd_proc_pd_proc_descricao_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pd_proc
    ADD CONSTRAINT pd_proc_pd_proc_descricao_fkey FOREIGN KEY (pd_proc_processo) REFERENCES public.processo_tigimento(processo_tigimento_descricao);


--
-- Name: pdi_cod_prod_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdi_item
    ADD CONSTRAINT pdi_cod_prod_fkey FOREIGN KEY (pdi_cod_prod) REFERENCES public.aa50(aa50id);


--
-- Name: pdi_item_pdi_cod_prod_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdi_item
    ADD CONSTRAINT pdi_item_pdi_cod_prod_fkey FOREIGN KEY (pdi_cod_prod) REFERENCES public.aa50(aa50id);


--
-- Name: pdi_item_pdi_entidade_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdi_item
    ADD CONSTRAINT pdi_item_pdi_entidade_fkey FOREIGN KEY (pdi_entidade) REFERENCES public.aa80(aa80nome) ON UPDATE CASCADE;


--
-- Name: pecas_pec_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas
    ADD CONSTRAINT pecas_pec_empresa_id_fkey FOREIGN KEY (pec_empresa_id) REFERENCES public.empresa(empresa_id);


--
-- Name: pecas_pec_produto_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas
    ADD CONSTRAINT pecas_pec_produto_fkey FOREIGN KEY (pec_produto) REFERENCES public.aa50(aa50id) ON UPDATE CASCADE;


--
-- Name: pecas_pec_revisao_ocorrencia_descricao_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas
    ADD CONSTRAINT pecas_pec_revisao_ocorrencia_descricao_fkey FOREIGN KEY (pec_revisao_ocorrencia_descricao) REFERENCES public.ocorrencia(ocorrencia_descricao) ON UPDATE CASCADE;


--
-- Name: pecas_pec_revisao_ocorrencia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas
    ADD CONSTRAINT pecas_pec_revisao_ocorrencia_fkey FOREIGN KEY (pec_revisao_ocorrencia) REFERENCES public.ocorrencia(ocorrencia_codigo);


--
-- Name: pecas_pec_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pecas
    ADD CONSTRAINT pecas_pec_usuario_fkey FOREIGN KEY (pec_usuario) REFERENCES public.usuario(usuario_usuario) ON UPDATE CASCADE;


--
-- Name: receita_item_ri_calculo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receita_item
    ADD CONSTRAINT receita_item_ri_calculo_fkey FOREIGN KEY (ri_calculo, ri_calculo_nome) REFERENCES public.tipos_calculo(tipos_calculo_codigo, tipos_calculo_descricao) ON UPDATE CASCADE;


--
-- Name: receita_item_ri_familia_codigo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receita_item
    ADD CONSTRAINT receita_item_ri_familia_codigo_fkey FOREIGN KEY (ri_familia_codigo) REFERENCES public.segmento_mercado(segmento_mercado_codigo);


--
-- Name: receita_item_ri_familia_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receita_item
    ADD CONSTRAINT receita_item_ri_familia_id_fkey FOREIGN KEY (ri_familia_id) REFERENCES public.segmento_mercado(segmento_mercado_id);


--
-- Name: receita_item_ri_familia_nome_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receita_item
    ADD CONSTRAINT receita_item_ri_familia_nome_fkey FOREIGN KEY (ri_familia_nome) REFERENCES public.segmento_mercado(segmento_mercado_descricao) ON UPDATE CASCADE;


--
-- Name: receita_item_ri_tipo_codigo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receita_item
    ADD CONSTRAINT receita_item_ri_tipo_codigo_fkey FOREIGN KEY (ri_tipo_codigo) REFERENCES public.tipo_produto(tipo_produto_codigo);


--
-- Name: receita_item_ri_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receita_item
    ADD CONSTRAINT receita_item_ri_tipo_id_fkey FOREIGN KEY (ri_tipo_id) REFERENCES public.tipo_produto(tipo_produto_id);


--
-- Name: receita_item_ri_tipo_nome_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receita_item
    ADD CONSTRAINT receita_item_ri_tipo_nome_fkey FOREIGN KEY (ri_tipo_nome) REFERENCES public.tipo_produto(tipo_produto_descricao) ON UPDATE CASCADE;


--
-- Name: rom_empresa_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.romaneio
    ADD CONSTRAINT rom_empresa_id_fk FOREIGN KEY (rom_empresa_id) REFERENCES public.aa80(aa80id);


--
-- Name: rom_nf_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.romaneio
    ADD CONSTRAINT rom_nf_fk FOREIGN KEY (rom_nf) REFERENCES public.nf_fixa(nf_id);


--
-- Name: romi_pec_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.romaneio_item
    ADD CONSTRAINT romi_pec_fk FOREIGN KEY (romi_pec_id) REFERENCES public.pecas(pec_id);


--
-- Name: romi_rom_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.romaneio_item
    ADD CONSTRAINT romi_rom_id_fk FOREIGN KEY (romi_rom_id) REFERENCES public.romaneio(rom_id) ON DELETE CASCADE;


--
-- Name: rop_ob_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relacao_ob_pb
    ADD CONSTRAINT rop_ob_id_fk FOREIGN KEY (rop_ob_id) REFERENCES public.ordem_beneficiamento(ob_id) ON DELETE CASCADE;


--
-- Name: rop_pb_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relacao_ob_pb
    ADD CONSTRAINT rop_pb_id_fk FOREIGN KEY (rop_pb_id) REFERENCES public.partida_beneficiamento(pb_id) ON DELETE CASCADE;


--
-- Name: roteiro_producao_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimentacao_roteiro
    ADD CONSTRAINT roteiro_producao_fkey FOREIGN KEY (movimentacao_roteiro_roteiro_id) REFERENCES public.roteiro_producao(roteiro_producao_id);


--
-- Name: roteiro_producao_roteiro_producao_centro_custo_homem_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roteiro_producao
    ADD CONSTRAINT roteiro_producao_roteiro_producao_centro_custo_homem_fkey FOREIGN KEY (roteiro_producao_centro_custo_homem) REFERENCES public.centro_custo(centro_custo_codigo) ON UPDATE CASCADE;


--
-- Name: roteiro_producao_roteiro_producao_centro_custo_maquina_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roteiro_producao
    ADD CONSTRAINT roteiro_producao_roteiro_producao_centro_custo_maquina_fkey FOREIGN KEY (roteiro_producao_centro_custo_maquina) REFERENCES public.centro_custo(centro_custo_codigo) ON UPDATE CASCADE;


--
-- Name: roteiro_producao_roteiro_producao_estagio_descricao_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roteiro_producao
    ADD CONSTRAINT roteiro_producao_roteiro_producao_estagio_descricao_fkey FOREIGN KEY (roteiro_producao_estagio_descricao) REFERENCES public.estagios(estagios_descricao) ON UPDATE CASCADE;


--
-- Name: roteiro_producao_roteiro_producao_grp_maq_descricao_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roteiro_producao
    ADD CONSTRAINT roteiro_producao_roteiro_producao_grp_maq_descricao_fkey FOREIGN KEY (roteiro_producao_grp_maq_descricao) REFERENCES public.grupo_maquinas(grupo_maquinas_descricao) ON UPDATE CASCADE;


--
-- Name: setup_maquinas_setup_maquinas_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.setup_maquinas
    ADD CONSTRAINT setup_maquinas_setup_maquinas_area_fkey FOREIGN KEY (setup_maquinas_area) REFERENCES public.areas_producao(areas_producao_codigo);


--
-- Name: setup_maquinas_setup_maquinas_estagio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.setup_maquinas
    ADD CONSTRAINT setup_maquinas_setup_maquinas_estagio_fkey FOREIGN KEY (setup_maquinas_estagio) REFERENCES public.estagios(estagios_codigo);


--
-- Name: solicitacao_desenvolvimento__solicitacao_desenvolvimento__fkey1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_desenvolvimento_cor
    ADD CONSTRAINT solicitacao_desenvolvimento__solicitacao_desenvolvimento__fkey1 FOREIGN KEY (solicitacao_desenvolvimento_cor_representante) REFERENCES public.aa80(aa80codigo);


--
-- Name: solicitacao_desenvolvimento__solicitacao_desenvolvimento__fkey2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_desenvolvimento_cor
    ADD CONSTRAINT solicitacao_desenvolvimento__solicitacao_desenvolvimento__fkey2 FOREIGN KEY (solicitacao_desenvolvimento_cor_produto) REFERENCES public.aa50(aa50id);


--
-- Name: solicitacao_desenvolvimento_c_solicitacao_desenvolvimento__fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitacao_desenvolvimento_cor
    ADD CONSTRAINT solicitacao_desenvolvimento_c_solicitacao_desenvolvimento__fkey FOREIGN KEY (solicitacao_desenvolvimento_cor_cliente) REFERENCES public.aa80(aa80codigo);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

