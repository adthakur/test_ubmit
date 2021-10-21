CREATE TABLE IF NOT EXISTS public.aggr_sales_new
(
    date_trunc date,
    rank bigint,
    top_product_id integer,
    product_id_count numeric,
    top_customer_id integer,
    top_customer_gmv numeric,
    never_bought_pants_customer text COLLATE pg_catalog."default"
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.aggr_sales_new
    OWNER to lb_hiring;
	
	
	
	