

With w_Products_Stage1 as (
	
	select 
	MonthYear,
	OI.product_id			AS		top_product_id,
		sum(OI.product_id)	AS		top_Productid_cnt
		
	from 
		(
		Select product_id,
		gmv_amount,
		to_date(left(date,9), 'YYYY-MM-DD') + (1 - extract(day from to_date(left(date,9), 'YYYY-MM-DD')))::integer AS MonthYear
		from public."order_items"
		) OI group by 1,2
)



, w_Top3Products_Final_Stage as (
	select PR_T.* from 
	(		
		select PR.*,
				 row_number() over (partition by MonthYear order by top_Productid_cnt desc) as seqnum
		  from w_Products_Stage1 PR
	) PR_T where seqnum <= 3 order by MonthYear,seqnum asc
)


--TCF Starts
,w_Customers_gmv_amount_Stage1 as (
	
	select 
	MonthYear,
	CI.customer_id			AS		top_customer_id,
		sum(CI.gmv_amount)	AS		top_gmv_amount
		
	from 
		(
		Select customer_id,
		gmv_amount,
		to_date(left(date,9), 'YYYY-MM-DD') + (1 - extract(day from to_date(left(date,9), 'YYYY-MM-DD')))::integer AS MonthYear
		from public."order_items"
		) CI group by 1,2
)



,
w_Top3Customers_gmv_amount_Final_Stage as (
	select CR_T.* from 
	(		
		select CR.*,
				 row_number() over (partition by MonthYear order by top_gmv_amount desc) as seqnum
		  from w_Customers_gmv_amount_Stage1 CR
	) CR_T where seqnum <= 3 order by MonthYear,seqnum asc
)


--NCF STarts
,
w_CustomerNeverPurchasedPants_Stage1 as (
	
	select Pants_cnt.customer_id,
			Pants_cnt.MonthYear,
			sum(Pants_cnt.calc_pants_flag)		AS		calc_pants_cnt
	from (
		
		Select OI.customer_id,
				OI.product_id,
				PD.subcategory,
				Case when PD.subcategory like '%pants%' THEN 1
				ELSE 0 END 		AS		calc_pants_flag,
		
		to_date(left(date,9), 'YYYY-MM-DD') + (1 - extract(day from to_date(left(date,9), 'YYYY-MM-DD')))::integer AS MonthYear
		from public."order_items" OI
		left Join Products PD on PD.product_id=OI.product_id
		) Pants_cnt group by 1,2 order by Pants_cnt.MonthYear , Pants_cnt.customer_id asc
		
)

, w_customerNeverPurchasedPants_Final_Stage as (

	select MonthYear,
	'1'::integer 			AS	seqnum,			
	array_to_string(array_agg(customer_id), '| ') as Customers_never_Purchase_Pants
	  from w_CustomerNeverPurchasedPants_Stage1 chk where calc_pants_cnt='0' group by 1
)

,w_Aggr_Sales as (
	select OT.* from
	(
	Select DISTINCT
	AGO.MonthYear,
	SEQ.seqnum,
	TPF.top_product_id,
	TPF.top_Productid_cnt,
	TCF.top_customer_id,
	TCF.top_gmv_amount,
	CNF.Customers_never_Purchase_Pants	
	
	from w_Top3Products_Final_Stage AGO 
	join w_Top3Products_Final_Stage SEQ on AGO.MonthYear=SEQ.MonthYear
	LEFT join w_Top3Products_Final_Stage TPF on AGO.MonthYear = TPF.MonthYear and SEQ.seqnum = TPF.seqnum
	LEFT join w_Top3Customers_gmv_amount_Final_Stage TCF on AGO.MonthYear=TCF.MonthYear and  SEQ.seqnum=TCF.seqnum
	LEFT join w_customerNeverPurchasedPants_Final_Stage CNF	on CNF.MonthYear=AGO.MonthYear and  SEQ.seqnum=CNF.seqnum

		) OT order by OT.MonthYear,OT.Seqnum

)


INSERT INTO public.aggr_sales_new(
	date_trunc, rank, top_product_id, product_id_count, top_customer_id, top_customer_gmv, never_bought_pants_customer)
select MonthYear,seqnum,top_product_id,top_Productid_cnt,top_customer_id,top_gmv_amount,Customers_never_Purchase_Pants from w_Aggr_Sales ;


