
-------------------------------------------------Supplier Master---------------------------------------------------

Create table Supplier_Master(
Supp_Code nvarchar(10) not null,
Supp_Name varchar(100) not null,
Active char(1) Default 'Y',
City varchar(10) not null,
state varchar(10) not null,
Country varchar(10) not null,
PhoneNumber char(10) not null
constraint PKSupp_Code primary key (Supp_Code)
constraint chk_phone CHECK (PhoneNumber not like '%[^0-9]%') 
);


create  sequence Supplier_Master_Code as int
start with 1
increment by 1
no cycle;



select * From Supplier_Master;


--------------------------------------Item Master----------------------------------------------------------------------


create table Item_Master(
Item_Code nvarchar(10) not null,
Item_Name varchar(100) not null,
Exp_Flag char(1) Default 'N',
Shelf_Life int,
Active char(1) Default 'Y'
constraint PKItem_Code primary key (Item_Code)
);

create  sequence Item_Master_Item_Code as int
start with 1
increment by 1
no cycle;


select * From Item_Master;
select next value for Item_Master_Item_Code;

--------------------------------------------------Purchase Order------------------------------------------------------------------------
select * from Purchase_Order


create table Purchase_Order(
Porder_Number int not null,
Order_Date  date  not null,
Confirmed char(1) Default 'N',
Supp_Code nvarchar(10) not null
constraint PKPO primary key (Porder_Number)
);



create  sequence Purchase_Order_Code as int
start with 1
increment by 1
no cycle;




create table Purchase_OrderDetail(
Porder_Number int not null,
Line_No int not null,
Item_Code nvarchar(10) not null,
Order_Qty  int  not null,
Unit_Price int not null,
Tax_Percent int
constraint FKPODet foreign key (Porder_Number) references Purchase_Order(Porder_Number)
);

 

                    -------------- computed column function used to calculate tax-------------------------------------

CREATE or alter  FUNCTION DBF_CalculateTax(@Porder_Number int,@Line_No int)
RETURNS money
AS 
BEGIN

	DECLARE @totalAmount money = (
			SELECT (( cast(Tax_Percent as float)/cast(100 as float) * (Order_Qty * Unit_Price )) + (Order_Qty * Unit_Price)) FROM Purchase_OrderDetail
			WHERE Porder_Number  =  @Porder_Number
			and   Line_No = @Line_No
	);
	SET @totalAmount = isnull(@totalAmount,0);
	RETURN @totalAmount;
End;

alter table Purchase_OrderDetail add	TotalAmount as (dbo.DBF_CalculateTax(Porder_Number,Line_No));

select dbo.DBF_CalculateTax(1,1)



			


-----------------------------------------------Receipt--------------------------------------------------------------------------------




create table Receipt(
Receipt_Number nvarchar(10) not null ,
Porder_Number int not null,
Item_Code nvarchar(10) not null,
Batch_No nvarchar(10) not null ,
Order_Qty  int  not null,
Qty_Rcvd int  not null,
Confirmed char(1) Default 'N',
constraint PKReceipt primary key clustered (Receipt_Number,Batch_No),
constraint FKRCP foreign key (Porder_Number) references Purchase_Order(Porder_Number)
);

select * From Receipt;

create  sequence Receipt_Code as int
start with 1
increment by 1
no cycle;

create sequence Receipt_BatchNo as int
start with 1
increment by 1
no cycle;



 

update Receipt set Confirmed = 'Y' where Receipt_Number = 'SFRCP1';   -- on confirming the receipt transaction system will create an entry in inventory for that particular batch and item

create trigger tr_tbl_Receipt_ForUpdate
on Receipt
for update 
as
Begin
	select * from deleted
	select * From inserted
end



Alter  trigger tr_tbl_Receipt_ForUpdate
on Receipt
for update 
as 
Begin
	Declare @Receipt_Number nvarchar(10)
	Declare @NewQty_Rcvd int
	Declare @NewItem_Code nvarchar(10)
	Declare @NewBatch_No nvarchar(10)

	select * into  #TempTable
	from inserted
	
	while(Exists(select Receipt_Number from #TempTable))
	begin
		
		select top 1 @Receipt_Number = Receipt_Number, @NewQty_Rcvd = Qty_Rcvd, @NewItem_Code = Item_Code, @NewBatch_No =Batch_No
		from #TempTable 
		-- where Receipt_Number = @Receipt_Number	
		-- select * from deleted where Receipt_Number = @Receipt_Number
	    -- select * From inserted  where Receipt_Number = @Receipt_Number
		insert into inventory values (@NewItem_Code,@NewQty_Rcvd,@NewBatch_No)
		
		delete from #TempTable where Receipt_Number = @Receipt_Number  --- deleting data from temptable
	end
end
---------------------------------------------Inventory---------------------------------------------------------------------

select * From inventory;

create table inventory(
InventoryID int NOT NULL IDENTITY PRIMARY KEY,
Item_Code nvarchar(10),
Qty int  ,
Batch_No nvarchar(10) 
); 


-------------------------------------------------sales--------------------------------------------------------------------



create table sales_order(
SO_Id int IDENTITY PRIMARY KEY,
InventoryID int ,
Line_No int not null,
Item_Code  nvarchar(10),
Batch_No nvarchar(10) not null,
Qty_Sales int  not null,
Unit_Price money not null,
Tax_Percent int,
confirmed char(1) Default 'N'
constraint FKSORID foreign key (InventoryID) references inventory(InventoryID)
);



create  sequence Sales_Order_Code as int
start with 1
increment by 1
no cycle;

select * from sales_order;





              --------------------- computed column function to calculate tax---------------------

CREATE or alter FUNCTION DBF_CalculateTax_SO(@SO_Id int,@Line_No int)
RETURNS MONEY
AS 
BEGIN

	DECLARE @totalAmount MONEY = (
			SELECT (( cast(Tax_Percent as float)/cast(100 as float) * (Qty_Sales * Unit_Price )) + (Qty_Sales * Unit_Price)) FROM sales_order
			WHERE SO_Id  = @SO_Id 
			and   Line_No = @Line_No
	);
	SET @totalAmount = isnull(@totalAmount,0);
	RETURN @totalAmount;
End;

alter table sales_order add	TotalAmount as (dbo.DBF_CalculateTax_SO(SO_Id,Line_No));


--- juct checking query
SELECT (( cast(Tax_Percent as float)/cast(100 as float) * (Qty_Sales * Unit_Price )) + (Qty_Sales * Unit_Price)) 
FROM sales_order
WHERE SO_Id  = 1 
and   Line_No = 1;
-------------------------------------------------------------------------------------------------------------------------

----- after confirming the sales order we would call this stored procedure for that particular  item and batch and 
-- deduct the sales quantity from inventory

sp_tbl_Receipt_ForUpdate 'SF1','SFBTCHNO1'



create or alter  procedure sp_tbl_Receipt_ForUpdate
@Item_Code nvarchar(10),
@Batch_No nvarchar(10)
as
Begin
		    declare @vSoQty int
			declare @vInvQty int
			set @vSoQty = (select Qty_Sales from sales_order where item_code = @Item_Code and batch_no = @Batch_No )
			set @vInvQty = (select Qty from inventory where item_code = @Item_Code and batch_no = @Batch_No ) 
			if @vInvQty >= @vSoQty  -- check if inventory quantity is greater than sales quantity
			
			begin
			 update inventory set Qty = @vInvQty - @vSoQty where item_code = @Item_Code and Batch_No = @Batch_No -- update inventory qty
		    end
end;

select * from inventory;